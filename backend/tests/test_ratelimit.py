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
