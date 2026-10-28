"""The API key between the app and the backend (MAGANA_API_KEY / X-Magana-Key)."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_without_a_key_set_nothing_is_needed(monkeypatch):
    monkeypatch.delenv("MAGANA_API_KEY", raising=False)
    assert client.post("/explain/check", json={"source_text": "a", "explanation": "a"}).status_code == 200


def test_with_a_key_set_every_call_needs_it(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "s3cret-key")
    body = {"source_text": "Take 2", "explanation": "Take 2"}
    missing = client.post("/explain/check", json=body)
    wrong = client.post("/explain/check", json=body, headers={"X-Magana-Key": "nope"})
    right = client.post("/explain/check", json=body, headers={"X-Magana-Key": "s3cret-key"})
    assert (missing.status_code, wrong.status_code, right.status_code) == (401, 401, 200)
    assert missing.json() == {"detail": {"code": "bad_api_key"}}


def test_health_stays_open_for_uptime_checks(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "s3cret-key")
    assert client.get("/health").status_code == 200


def test_livez_is_open_and_never_touches_the_database(monkeypatch):
    """Caddy, Docker and the monitor call /livez often; Neon's free compute must be left to sleep."""
    from app import accounts

    monkeypatch.setenv("MAGANA_API_KEY", "s3cret-key")
    monkeypatch.setattr(accounts, "db", lambda: (_ for _ in ()).throw(AssertionError("db used")))
    r = client.get("/livez")
    assert r.status_code == 200 and r.json()["status"] == "ok" and "build" in r.json()


def test_cors_preflight_is_not_blocked(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "s3cret-key")
    r = client.options("/read", headers={"Origin": "http://localhost:5173",
                                         "Access-Control-Request-Method": "POST"})
    assert r.status_code == 200


def test_the_web_key_works_beside_the_app_key(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "app-key")
    monkeypatch.setenv("MAGANA_WEB_API_KEY", "web-key")
    body = {"source_text": "Take 2", "explanation": "Take 2"}
    for k, code in (("app-key", 200), ("web-key", 200), ("other", 401), ("", 401)):
        assert client.post("/explain/check", json=body, headers={"X-Magana-Key": k}).status_code == code


def test_cors_allows_the_portal_cookie_for_listed_origins_only(monkeypatch):
    r = client.options("/quizzes", headers={"Origin": "http://localhost:3101", "Access-Control-Request-Method": "GET"})
    assert r.headers["access-control-allow-credentials"] == "true"
    assert r.headers["access-control-allow-origin"] == "http://localhost:3101"
    r = client.options("/quizzes", headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "GET"})
    assert "access-control-allow-origin" not in r.headers


# ---------- rotating the key without breaking installed apps

from datetime import date  # noqa: E402

from app.main import accepted_keys  # noqa: E402


def call(key):
    return client.post("/explain/check", json={"source_text": "a", "explanation": "a"},
                       headers={"X-Magana-Key": key}).status_code


def test_old_and_new_keys_both_work_for_up_to_14_days(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "new-app-key")
    monkeypatch.setenv("MAGANA_API_KEY_PREVIOUS", "old-app-key")
    monkeypatch.setenv("MAGANA_API_KEY_PREVIOUS_UNTIL", "2026-11-09")
    assert accepted_keys(date(2026, 10, 26)) == ["new-app-key", "old-app-key"]
    assert accepted_keys(date(2026, 11, 9)) == ["new-app-key", "old-app-key"]  # the last day
    assert accepted_keys(date(2026, 11, 10)) == ["new-app-key"]  # then refused
    # A date more than 14 days away is a mistake: the old key isn't taken at all.
    assert accepted_keys(date(2026, 10, 20)) == ["new-app-key"]
    monkeypatch.setenv("MAGANA_API_KEY_PREVIOUS_UNTIL", "someday")
    assert accepted_keys(date(2026, 10, 26)) == ["new-app-key"]


def test_the_previous_key_works_through_the_server_until_its_date(monkeypatch):
    today = (__import__("datetime").datetime.now(__import__("datetime").timezone.utc)).date()
    monkeypatch.setenv("MAGANA_API_KEY", "new-app-key")
    monkeypatch.setenv("MAGANA_API_KEY_PREVIOUS", "old-app-key")
    monkeypatch.setenv("MAGANA_API_KEY_PREVIOUS_UNTIL", (today + __import__("datetime").timedelta(days=10)).isoformat())
    assert (call("new-app-key"), call("old-app-key"), call("other")) == (200, 200, 401)
    monkeypatch.setenv("MAGANA_API_KEY_PREVIOUS_UNTIL", (today - __import__("datetime").timedelta(days=2)).isoformat())
    assert (call("new-app-key"), call("old-app-key")) == (200, 401)


def test_the_web_key_rotates_the_same_way(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "app-key")
    monkeypatch.setenv("MAGANA_WEB_API_KEY", "new-web-key")
    monkeypatch.setenv("MAGANA_WEB_API_KEY_PREVIOUS", "old-web-key")
    monkeypatch.setenv("MAGANA_WEB_API_KEY_PREVIOUS_UNTIL", "2026-11-01")
    assert accepted_keys(date(2026, 10, 26)) == ["app-key", "new-web-key", "old-web-key"]
