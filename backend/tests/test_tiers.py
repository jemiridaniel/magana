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


WAITING = {"X-Magana-Tier": "guided"}  # 13–17, guardian hasn't agreed yet


def test_guided_waiting_for_consent_may_read_schoolwork_only():
    # The A2 board: "Until then you can still read pages." Nothing else (DRAFT, Nurse Balogun).
    assert read(WAITING).status_code == 200
    for mode in ("health", "money", "letter"):
        r = read(WAITING, mode)
        assert r.status_code == 403 and r.json()["detail"] == {"code": "consent_required"}
    r = client.post("/explain", json={"source_text": "Plants make food.", "lang": "en"}, headers=WAITING)
    assert r.status_code == 403 and r.json()["detail"] == {"code": "consent_required"}
    assert client.get("/triage/questions", headers=WAITING).status_code == 403


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
    assert policy.check_request(policy.Tier.GUIDED, True, False) is policy.Tier.GUIDED
    assert policy.check_request(policy.Tier.GUIDED, False, False) is policy.Tier.GUIDED_WAITING
    with pytest.raises(policy.CodedError):
        policy.check_request(policy.Tier.CLASSROOM, False, False)


def test_letter_mode_is_adults_only_and_gets_the_second_pass(monkeypatch):
    import app.main as main
    from tests.test_core import _page_png  # noqa: F401  (renderer shared with test_core)

    calls = []

    def fake_read_page(image, engine, second_pass=False):
        calls.append(second_pass)
        return {"tips": [], "lines": [], "tables": [], "faint_regions": []}

    monkeypatch.setattr(main, "read_page", fake_read_page)
    png = _page_png(["Dear customer"])
    ok = client.post("/read", files={"file": ("p.png", png)}, data={"mode": "letter"})
    assert ok.status_code == 200 and calls == [True]
    teen = client.post("/read", files={"file": ("p.png", png)}, data={"mode": "letter"},
                       headers={"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"})
    assert teen.status_code == 403 and teen.json()["detail"] == {"code": "not_allowed_for_tier"}
