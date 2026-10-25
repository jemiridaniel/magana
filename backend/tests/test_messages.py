"""The API speaks in message codes; the app owns every sentence."""
import io
import json
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image

from app import messages, safety, triage
from app.main import app

client = TestClient(app)
ARB = Path(__file__).parents[2] / "app" / "lib" / "l10n" / "app_en.arb"


def _png(color="white", size=(400, 300)):
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, "PNG")
    return buf.getvalue()


def _strings(obj):
    if isinstance(obj, dict):
        for v in obj.values():
            yield from _strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _strings(v)
    elif isinstance(obj, str):
        yield obj


def test_every_code_has_an_app_string():
    keys = set(json.loads(ARB.read_text()))
    missing = sorted(c for c in messages.CODES if f"msg_{c}" not in keys)
    assert not missing, f"add msg_<code> to app/lib/l10n/app_*.arb: {missing}"


def test_read_returns_codes_not_sentences():
    body = client.post("/read", files={"file": ("p.png", _png((20, 20, 20)))}).json()
    assert body["tips"] == ["too_dark", "blurry"]
    assert all(t in messages.CODES for t in body["tips"])


def test_errors_are_codes():
    r = client.post("/read", files={"file": ("p.png", _png())}, data={"mode": "poetry"})
    assert r.status_code == 400 and r.json()["detail"] == {"code": "unknown_mode"}
    r = client.post("/read", files={"file": ("p.png", _png())}, data={"mode": "money"}, headers={"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"})
    assert r.status_code == 403 and r.json()["detail"] == {"code": "not_allowed_for_tier"}
    r = client.post("/read", files={"file": ("p.png", b"not an image")})
    assert r.status_code == 400 and r.json()["detail"] == {"code": "unreadable_image"}


def test_warning_codes_are_registered():
    line = {"text": "Take @ tablets", "confidence": 0.5,
            "words": [{"text": "Take", "confidence": 0.9}, {"text": "@", "confidence": 0.2}, {"text": "tablets", "confidence": 0.9}]}
    codes = {w.code for w in safety.confidence_warnings([line]) + safety.number_warnings([line])}
    codes |= {w.code for w in safety.number_mismatches({"lines": [{"text": "8", "top": 0}]}, {"lines": []})[0]}
    assert codes and codes <= messages.CODES


def test_triage_and_explain_are_codes():
    assert all(q["message"] in messages.CODES and "text" not in q for q in triage.FALLBACK_QUESTIONS)
    r = client.post("/triage/assess", json={"fits": True}).json()
    assert (r["priority"], r["message"]) == ("emergency", "go_to_clinic_now")
    r = client.post("/explain/check", json={"source_text": "Take 2", "explanation": "Take 3"}).json()
    assert r["message"] == "numbers_unconfirmed"


def test_no_english_sentences_in_responses():
    bodies = [
        client.post("/read", files={"file": ("p.png", _png((20, 20, 20)))}).json(),
        client.get("/triage/questions").json(),
        client.post("/triage/assess", json={}).json(),
    ]
    for body in bodies:
        for s in _strings(body):
            assert s.count(" ") < 3, f"looks like a sentence: {s!r}"


def test_fallback_triage_wording_exists_in_all_four_languages():
    """Magana answers on its own when Ibà is down, so its triage strings must be in every language."""
    from app import triage

    codes = [f"q_{q}" for q in triage.DANGER_SIGNS] + ["q_fever", "q_fever_days",
             "go_to_clinic_now", "nurse_call_within_2_hours", "nurse_call_working_hours"]
    english = json.loads(ARB.read_text())
    for lang in ("ha", "yo", "ig"):
        arb = json.loads(ARB.with_name(f"app_{lang}.arb").read_text())
        assert arb.get("@@x-review", "").startswith("DRAFT")
        for code in codes:
            text = arb.get(f"msg_{code}", "")
            assert text.strip() and text != english[f"msg_{code}"], f"{lang}: msg_{code}"
    for code in codes:
        assert "CLINICAL DRAFT" in english[f"@msg_{code}"]["description"]


def test_every_code_the_portal_and_class_link_apis_can_return_is_registered():
    import re
    from pathlib import Path
    app_dir = Path(__file__).parents[1] / "app"
    for name, known in (("portal_api.py", messages.PORTAL_CODES | messages.CODES),
                        ("learner_api.py", messages.CODES)):
        src = (app_dir / name).read_text()
        used = set(re.findall(r'fail\(\d+,\s*"(\w+)"', src)) | set(re.findall(r'\{"code":\s*"(\w+)"', src))
        used |= set(re.findall(r'_wrong\(key,\s*"(\w+)"\)', src))
        assert used and not used - known, f"{name}: register {sorted(used - known)}"
