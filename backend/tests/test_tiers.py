"""Age tiers are enforced on every request (CLAUDE.md rule 4)."""
import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import policy
from app.main import app

client = TestClient(app)

ADULT = {"X-Magana-Tier": "standard"}
TEEN = {"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"}
CHILD = {"X-Magana-Tier": "classroom", "X-Magana-Teacher-Session": "yes"}


def png():
    buf = io.BytesIO()
    Image.new("RGB", (300, 200), "white").save(buf, "PNG")
    return buf.getvalue()


def read(headers, mode="school"):
    return client.post("/read", files={"file": ("p.png", png())}, data={"mode": mode}, headers=headers)


@pytest.mark.parametrize("headers", [ADULT, TEEN, CHILD])
def test_everyone_can_read_schoolwork(headers):
    assert read(headers).status_code == 200


@pytest.mark.parametrize("mode", ["health", "money"])
@pytest.mark.parametrize("headers", [TEEN, CHILD])
def test_under_18_cannot_read_health_or_money_papers(headers, mode):
    r = read(headers, mode)
    assert r.status_code == 403 and r.json()["detail"] == {"code": "not_allowed_for_tier"}


@pytest.mark.parametrize("mode", ["health", "money"])
def test_adults_can(mode):
    assert read(ADULT, mode).status_code == 200


def test_guided_without_guardian_consent_is_refused():
    r = read({"X-Magana-Tier": "guided"})
    assert r.status_code == 403 and r.json()["detail"] == {"code": "consent_required"}


def test_classroom_without_a_teacher_session_is_refused():
    r = read({"X-Magana-Tier": "classroom"})
    assert r.status_code == 403 and r.json()["detail"] == {"code": "teacher_session_required"}


def test_unknown_tier_is_refused():
    r = read({"X-Magana-Tier": "toddler"})
    assert r.status_code == 400 and r.json()["detail"] == {"code": "unknown_tier"}


@pytest.mark.parametrize("headers", [TEEN, CHILD])
def test_triage_is_for_adults_only(headers):
    assert client.get("/triage/questions", headers=headers).status_code == 403
    assert client.post("/triage/assess", json={"fits": True}, headers=headers).status_code == 403
    assert client.post("/triage/assess", json={"fits": True}, headers=ADULT).json()["priority"] == "emergency"


def test_check_request_rules():
    assert policy.check_request(policy.Tier.STANDARD, False, False) is policy.Tier.STANDARD
    with pytest.raises(policy.CodedError):
        policy.check_request(policy.Tier.GUIDED, False, False)
