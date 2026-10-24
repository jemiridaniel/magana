"""Call-back requests: honest when no nurse desk is connected; adults only; no PII."""
import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)
ADULT = {"X-Magana-Tier": "standard"}
BODY = {"reason": "medicine", "language": "ha", "priority": "urgent"}


def test_without_a_nurse_desk_it_says_so():
    r = client.post("/callback", json=BODY, headers=ADULT)
    assert r.status_code == 503 and r.json()["detail"] == {"code": "callback_unavailable"}


def test_with_a_nurse_desk_the_request_is_forwarded(monkeypatch):
    sent = []
    monkeypatch.setenv("MAGANA_CALLBACK_URL", "http://desk.test/requests")

    class Client(httpx.AsyncClient):
        def __init__(self, **kw):
            super().__init__(transport=httpx.MockTransport(lambda r: (sent.append(r), httpx.Response(201))[1]), **kw)

    monkeypatch.setattr("app.main.httpx.AsyncClient", Client)
    r = client.post("/callback", json=BODY, headers=ADULT)
    assert r.json() == {"code": "callback_booked"}
    assert [str(x.url) for x in sent] == ["http://desk.test/requests"]


def test_a_failing_desk_is_unavailable(monkeypatch):
    monkeypatch.setenv("MAGANA_CALLBACK_URL", "http://desk.test/requests")

    class Client(httpx.AsyncClient):
        def __init__(self, **kw):
            super().__init__(transport=httpx.MockTransport(lambda r: httpx.Response(500)), **kw)

    monkeypatch.setattr("app.main.httpx.AsyncClient", Client)
    assert client.post("/callback", json=BODY, headers=ADULT).json()["detail"] == {"code": "callback_unavailable"}


@pytest.mark.parametrize("headers", [
    {"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"},
    {"X-Magana-Tier": "classroom", "X-Magana-Teacher-Session": "yes"},
])
def test_adults_only(headers):
    assert client.post("/callback", json=BODY, headers=headers).status_code == 403


def test_no_free_text_or_extra_fields():
    r = client.post("/callback", json={**BODY, "phone": "08012345678"}, headers=ADULT)
    assert r.status_code == 422
