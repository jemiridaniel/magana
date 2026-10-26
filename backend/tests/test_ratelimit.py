"""Per-IP and per-device rate limits."""
import pytest
from fastapi.testclient import TestClient

from app import ratelimit
from app.main import app

client = TestClient(app)
DEV = "3f1c6a2e-9b7d-4e1a-8c55-0d2b7e9f4a11"


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


@pytest.fixture
def clock(monkeypatch):
    c = Clock()
    monkeypatch.setattr(ratelimit, "limiter", ratelimit.RateLimiter(clock=c))
    monkeypatch.setenv("RATE_IP_PER_MIN", "10")
    monkeypatch.setenv("RATE_DEVICE_PER_MIN", "5")
    monkeypatch.setenv("RATE_HEAVY_IP_PER_MIN", "4")
    monkeypatch.setenv("RATE_HEAVY_DEVICE_PER_MIN", "2")
    return c


def check(*body):
    return client.post("/explain/check", json={"source_text": "a", "explanation": "a"},
                       headers={"X-Magana-Device": body[0]} if body else {})


def test_a_device_is_limited_and_told_when_to_retry(clock):
    codes = [check(DEV).status_code for _ in range(6)]
    assert codes == [200] * 5 + [429]
    r = check(DEV)
    assert r.json() == {"detail": {"code": "too_many_requests"}}
    assert int(r.headers["Retry-After"]) >= 1


def test_the_bucket_refills_over_time(clock):
    for _ in range(5):
        check(DEV)
    assert check(DEV).status_code == 429
    clock.now += 12  # 5 per minute: one token every 12 s
    assert check(DEV).status_code == 200


def test_many_devices_from_one_ip_share_the_ip_limit(clock):
    codes = [check(f"device-{i:08d}").status_code for i in range(11)]
    assert codes == [200] * 10 + [429]


def test_without_a_device_id_the_ip_limit_still_applies(clock):
    codes = [check().status_code for _ in range(11)]
    assert codes[-1] == 429 and codes.count(200) == 10


def test_a_malformed_device_id_counts_only_against_the_ip(clock):
    codes = [check("x").status_code for _ in range(7)]
    assert all(c == 200 for c in codes)  # 5-per-device limit not applied to junk IDs


def test_reading_explaining_and_asr_have_tighter_limits(clock):
    def explain():
        return client.post("/explain", json={"source_text": "Take 2"},
                           headers={"X-Magana-Device": DEV, "X-Magana-Tier": "standard"})
    assert [explain().status_code == 429 for _ in range(3)] == [False, False, True]
    # Ordinary calls from the same device still have their own budget.
    assert check(DEV).status_code == 200


def test_health_is_never_limited(clock):
    assert all(client.get("/health").status_code == 200 for _ in range(50))


def test_a_refusal_costs_nothing_elsewhere(clock):
    for _ in range(5):
        check(DEV)
    for _ in range(3):
        assert check(DEV).status_code == 429
    # The IP bucket was refunded for the refused calls: 5 of 10 used.
    assert [check(f"other-{i:08d}").status_code for i in range(6)] == [200] * 5 + [429]


def test_a_browser_can_read_the_429_and_the_401(clock, monkeypatch):
    # Without CORS headers the browser hides the response, and the web app would
    # say "couldn't reach Magana" instead of "Magana is busy".
    origin = {"Origin": "http://localhost:5173", "X-Magana-Device": DEV}
    for _ in range(5):
        client.post("/explain/check", json={"source_text": "a", "explanation": "a"}, headers=origin)
    r = client.post("/explain/check", json={"source_text": "a", "explanation": "a"}, headers=origin)
    assert r.status_code == 429
    assert r.headers["access-control-allow-origin"] == "http://localhost:5173"
    monkeypatch.setenv("MAGANA_API_KEY", "secret")
    r = client.get("/asr/available", headers={"Origin": "http://localhost:5173"})
    assert r.status_code == 401
    assert r.headers["access-control-allow-origin"] == "http://localhost:5173"


def test_the_signed_in_portal_is_limited_per_session_not_per_shared_ip(monkeypatch):
    monkeypatch.setenv("RATE_IP_PER_MIN", "3")
    monkeypatch.setenv("RATE_PORTAL_SESSION_PER_MIN", "5")
    lim = ratelimit.RateLimiter(clock=lambda: 0.0)
    # Two teachers behind one school router: each session has its own allowance.
    assert all(lim.check("/portal/classes", "10.0.0.1", None, "teacher-a") == 0 for _ in range(5))
    assert lim.check("/portal/classes", "10.0.0.1", None, "teacher-a") > 0
    assert lim.check("/portal/classes", "10.0.0.1", None, "teacher-b") == 0
    # Sign-in keeps the IP limit, cookie or not.
    assert all(lim.check("/portal/auth/request-code", "10.0.0.2", None, "x") == 0 for _ in range(3))
    assert lim.check("/portal/auth/request-code", "10.0.0.2", None, "x") > 0


# ---------- daily caps on reading, ASR and Explain

def test_a_device_is_capped_per_day_and_told_to_come_back_tomorrow(monkeypatch):
    wall = Clock()
    wall.now = 1_793_000_000.0  # some time on a Lagos day
    lim = ratelimit.RateLimiter(wall=wall)
    monkeypatch.setenv("RATE_HEAVY_DEVICE_PER_DAY", "3")
    monkeypatch.setenv("RATE_HEAVY_IP_PER_DAY", "100")
    assert [lim.check_daily("/read", "1.2.3.4", DEV) for _ in range(3)] == [0.0, 0.0, 0.0]
    wait = lim.check_daily("/read", "1.2.3.4", DEV)
    local = wall.now + 3600
    assert wait == 86400 - local % 86400  # until midnight in Lagos
    assert lim.check_daily("/read", "1.2.3.4", "another-device-123") == 0.0  # other phones aren't
    assert lim.check_daily("/library", "1.2.3.4", DEV) == 0.0  # light calls aren't capped
    wall.now += wait + 1  # the next day
    assert lim.check_daily("/read", "1.2.3.4", DEV) == 0.0


def test_an_ip_is_capped_per_day_whatever_device_ids_it_sends(monkeypatch):
    lim = ratelimit.RateLimiter(wall=lambda: 1_793_000_000.0)
    monkeypatch.setenv("RATE_HEAVY_IP_PER_DAY", "5")
    results = [lim.check_daily("/explain", "5.6.7.8", f"made-up-device-{i:04d}") for i in range(6)]
    assert results[:5] == [0.0] * 5 and results[5] > 0


def test_the_daily_cap_answers_daily_limit(monkeypatch):
    monkeypatch.setattr(ratelimit, "limiter", ratelimit.RateLimiter())
    monkeypatch.setenv("RATE_HEAVY_DEVICE_PER_DAY", "1")
    headers = {"X-Magana-Device": DEV}
    client.post("/read", headers=headers)  # counted (whatever the answer)
    r = client.post("/read", headers=headers)
    assert r.status_code == 429 and r.json() == {"detail": {"code": "daily_limit"}}
    assert 0 < int(r.headers["retry-after"]) <= 86400
