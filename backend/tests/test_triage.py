"""Ibà client: success, timeout, errors and bad answers, with the built-in danger-sign
fallback and floor. No network: Ibà is an httpx.MockTransport."""
import asyncio
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app import triage
from app.iba_client import IbaClient
from app.main import app, get_iba

client = TestClient(app)


def iba(handler, deadline_s: float = 3.0) -> IbaClient:
    return IbaClient("http://iba.test", "magana-key", deadline_s=deadline_s, transport=httpx.MockTransport(handler))


def answering(priority: str, message: str, seen: list | None = None):
    def handler(request: httpx.Request) -> httpx.Response:
        if seen is not None:
            seen.append(request)
        if request.url.path == "/v1/questions":
            qs = [{"id": "fever", "type": "yes_no", "text": "Ṣé o ní ibà?"},
                  {"id": "fits", "type": "yes_no", "text": "Ṣé gìrì ti mú ọ?"}]
            return httpx.Response(200, json={"questions": qs})
        return httpx.Response(200, json={"priority": priority, "message": message, "rule_version": "self-report-0.1.0"})
    return handler


@pytest.fixture
def use_iba():
    def install(fake: IbaClient | None):
        app.dependency_overrides[get_iba] = lambda: fake
    yield install
    app.dependency_overrides.clear()


def run(coro):
    return asyncio.run(coro)


# ---------- success

def test_iba_answer_is_used(use_iba):
    seen: list[httpx.Request] = []
    use_iba(iba(answering("urgent", "nurse_call_within_2_hours", seen)))
    body = client.post("/triage/assess", json={"fever": True, "fever_days": 3}).json()
    assert body == {"priority": "urgent", "message": "nurse_call_within_2_hours",
                    "rule_version": "self-report-0.1.0", "source": "iba"}
    [request] = seen
    assert request.url.path == "/v1/assess"
    assert request.headers["X-API-Key"] == "magana-key"
    assert json.loads(request.content) == {"mode": "self_report", "answers": {"fever": True, "fever_days": 3}}


def test_iba_questions_are_relayed_in_the_users_language(use_iba):
    seen: list[httpx.Request] = []
    use_iba(iba(answering("routine", "nurse_call_working_hours", seen)))
    body = client.get("/triage/questions?lang=yo").json()
    assert body["source"] == "iba"
    assert [q["id"] for q in body["questions"]] == ["fever", "fits"]
    assert body["questions"][1] == {"id": "fits", "type": "yes_no", "text": "Ṣé gìrì ti mú ọ?", "message": "q_fits"}
    assert dict(seen[0].url.params) == {"mode": "self_report", "lang": "yo"}


def test_a_danger_sign_is_an_emergency_even_if_iba_says_otherwise(use_iba):
    use_iba(iba(answering("routine", "nurse_call_working_hours")))
    body = client.post("/triage/assess", json={"bleeding": True}).json()
    assert (body["priority"], body["message"], body["source"]) == ("emergency", "go_to_clinic_now", "iba+danger_floor")


# ---------- timeout

def test_more_than_three_seconds_falls_back(use_iba):
    async def slow(request: httpx.Request) -> httpx.Response:
        await asyncio.sleep(5)
        return httpx.Response(200, json={})

    fake = iba(slow, deadline_s=0.2)  # the real deadline is 3 s; shortened to keep tests fast
    r = run(triage.assess({"fits": True}, fake))
    assert (r.priority, r.source) == (triage.Priority.EMERGENCY, "fallback")
    qs, source = run(triage.questions("ha", fake))
    assert source == "fallback" and qs == triage.FALLBACK_QUESTIONS


def test_the_deadline_is_three_seconds_for_the_whole_call():
    assert IbaClient("http://iba.test", "k").deadline_s == 3.0


def test_timeout_through_the_api(use_iba):
    async def slow(request: httpx.Request) -> httpx.Response:
        await asyncio.sleep(5)
        return httpx.Response(200, json={})

    use_iba(iba(slow, deadline_s=0.2))
    body = client.post("/triage/assess", json={"cannot_drink": True}).json()
    assert (body["priority"], body["source"]) == ("emergency", "fallback")


# ---------- errors

@pytest.mark.parametrize("response", [
    httpx.Response(500, json={"detail": "boom"}),
    httpx.Response(401, json={"detail": {"code": "invalid_api_key"}}),
    httpx.Response(503, json={"detail": {"code": "api_keys_not_configured"}}),
    httpx.Response(200, text="not json"),
    httpx.Response(200, json={"priority": "emergency"}),                                   # missing fields
    httpx.Response(200, json={"priority": "maybe", "message": "go_to_clinic_now", "rule_version": "x"}),
    httpx.Response(200, json={"priority": "routine", "message": "you_have_lassa", "rule_version": "x"}),
])
def test_iba_errors_and_bad_answers_fall_back(response):
    fake = iba(lambda request: response)
    r = run(triage.assess({"vomits_everything": True}, fake))
    assert (r.priority, r.message, r.source) == (triage.Priority.EMERGENCY, "go_to_clinic_now", "fallback")


def test_connection_refused_falls_back():
    def refuse(request):
        raise httpx.ConnectError("refused")

    r = run(triage.assess({"too_weak": True}, iba(refuse)))
    assert (r.priority, r.source) == (triage.Priority.EMERGENCY, "fallback")


# ---------- fallback rules

@pytest.mark.parametrize("sign", triage.DANGER_SIGNS)
def test_every_danger_sign_is_an_emergency_without_iba(sign):
    body = client.post("/triage/assess", json={sign: True}).json()
    assert (body["priority"], body["source"]) == ("emergency", "fallback")


def test_without_a_danger_sign_the_fallback_asks_for_the_faster_call_back():
    body = client.post("/triage/assess", json={"fever": True, "fever_days": 1}).json()
    assert (body["priority"], body["message"]) == ("urgent", "nurse_call_within_2_hours")


def test_not_configured_uses_the_fallback_questions():
    body = client.get("/triage/questions?lang=ha").json()
    assert body["source"] == "fallback"
    assert [q["id"] for q in body["questions"]] == list(triage.DANGER_SIGNS)


def test_from_env(monkeypatch):
    assert IbaClient.from_env() is None
    monkeypatch.setenv("IBA_API_URL", "http://iba:8000/")
    monkeypatch.setenv("IBA_API_KEY", "k")
    c = IbaClient.from_env()
    assert (c.base_url, c.api_key) == ("http://iba:8000", "k")


def test_danger_signs_match_iba():
    """The fallback must know Ibà's danger-sign questions by the same ids."""
    import pathlib
    import re

    iba_rules = pathlib.Path(__file__).parents[3] / "iba-natlas/app/backend/app/rules/self_report.py"
    if not iba_rules.exists():
        pytest.skip("iba-natlas is not checked out next to magana")
    block = iba_rules.read_text().split("DANGER_QUESTIONS")[1].split("}")[0]
    assert tuple(re.findall(r'"(\w+)":', block)) == triage.DANGER_SIGNS
