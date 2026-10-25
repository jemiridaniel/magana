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
