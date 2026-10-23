from PIL import Image, ImageDraw, ImageFont
from fastapi.testclient import TestClient
import io
import pytest

from app import policy, safety, triage
from app.main import app

client = TestClient(app)


# ---------- safety: verbatim numbers
def test_explanation_with_page_numbers_passes():
    src = "Paracetamol 500 mg tablets. Take 2 tablets every 4 to 6 hours. Do not take more than 8 tablets in 24 hours."
    exp = "Take 2 tablets of 500 mg every 4 to 6 hours, and no more than 8 in 24 hours."
    assert safety.guard_explanation(src, exp).ok


def test_explanation_with_invented_dose_is_rejected():
    src = "Take 2 tablets every 4 to 6 hours."
    r = safety.guard_explanation(src, "Take 3 tablets every 4 hours.")
    assert not r.ok and "3" in r.unsupported


def test_naira_amount_formats_match():
    src = "POS purchase ₦6,450.00 balance ₦38,750.00"
    assert safety.guard_explanation(src, "You spent N6450.00 and have ₦38,750.00 left.").ok
    assert not safety.guard_explanation(src, "You spent ₦6,540.00.").ok


def test_confidence_warning():
    w = safety.confidence_warnings([{"confidence": 0.95}, {"confidence": 0.4, "label": "row 4"}])
    assert len(w) == 1 and "row 4" in w[0].spoken


# ---------- policy: age tiers
def test_age_tiers():
    assert policy.tier_for_age(25) == policy.Tier.STANDARD
    assert policy.tier_for_age(15, guardian_consent=True) == policy.Tier.GUIDED
    with pytest.raises(PermissionError):
        policy.tier_for_age(15)
    with pytest.raises(PermissionError):
        policy.tier_for_age(10)


def test_minors_cannot_use_health_money_or_whatsapp():
    for f in (policy.Feature.EVERYDAY_HEALTH, policy.Feature.EVERYDAY_MONEY, policy.Feature.WHATSAPP, policy.Feature.OPEN_CHAT):
        assert not policy.allowed(policy.Tier.GUIDED, f)
    assert policy.allowed(policy.Tier.STANDARD, policy.Feature.EVERYDAY_HEALTH)


# ---------- triage
def test_danger_sign_means_emergency():
    assert triage.assess({"danger_breathing": True}).priority == triage.Priority.EMERGENCY


def test_fever_two_days_is_urgent():
    assert triage.assess({"fever": True, "fever_days": 2}).priority == triage.Priority.URGENT


def test_otherwise_routine():
    assert triage.assess({"fever": False}).priority == triage.Priority.ROUTINE


# ---------- API + real OCR on a generated page
def _page_png(text_lines):
    img = Image.new("RGB", (1200, 120 + 70 * len(text_lines)), "white")
    d = ImageDraw.Draw(img)
    # DejaVu ships on Linux/Docker; macOS has Arial/Helvetica. The bitmap default is too small for OCR.
    for name in ("DejaVuSans.ttf", "Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            font = ImageFont.truetype(name, 40)
            break
        except OSError:
            continue
    else:
        font = ImageFont.load_default(size=40)
    for i, t in enumerate(text_lines):
        d.text((40, 40 + 70 * i), t, fill="black", font=font)
    buf = io.BytesIO(); img.save(buf, "PNG"); return buf.getvalue()


def test_read_endpoint_reads_text():
    png = _page_png(["Food tests", "Starch Iodine solution Blue-black"])
    r = client.post("/read", files={"file": ("p.png", png, "image/png")}, data={"mode": "school"})
    assert r.status_code == 200
    text = " ".join(l["text"] for l in r.json()["lines"])
    # Tesseract often reads "Iodine" as "lodine" (capital I vs lower-case l): exactly the kind
    # of error the production engine and the confidence warnings exist to catch.
    assert "Starch" in text and "odine" in text and "solution" in text


def test_minor_blocked_from_health_mode():
    png = _page_png(["Paracetamol 500 mg"])
    r = client.post("/read", files={"file": ("p.png", png, "image/png")}, data={"mode": "health", "tier": "guided"})
    assert r.status_code == 403


def test_triage_api():
    r = client.post("/triage/assess", json={"danger_vomit_weak": True})
    assert r.json()["priority"] == "emergency"
