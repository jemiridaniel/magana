"""Screenshots and light-on-dark pictures (tester, 27 Oct 2026: a dark-mode bank transfer receipt
from the gallery was "too dark, can't read it"). Synthetic receipts with made-up names and
numbers; the money rules are unchanged: an amount is read exactly or not at all."""
import io

import pytest
from fastapi.testclient import TestClient

import capture_fixtures as cf
from app.main import app
from app.reader import is_screenshot, light_on_dark, read_page

client = TestClient(app)
CAMERA_TIPS = {"too_dark", "blurry", "cut_off_top", "cut_off_bottom", "cut_off_left", "cut_off_right",
               "edge_cut_left", "edge_cut_right"}
VARIANTS = [dict(dark=True), dict(dark=True, fmt="JPEG"), dict(dark=False), dict(dark=True, stacked=False),
            dict(dark=False, stacked=False)]


def post(img, mode="money"):
    buf = io.BytesIO()
    img.save(buf, img.format or "JPEG")
    return client.post("/read", files={"file": ("s", buf.getvalue())}, data={"mode": mode},
                       headers={"X-Magana-Tier": "standard", "X-Magana-Messages": "3"}).json()


@pytest.mark.parametrize("kind", VARIANTS, ids=lambda k: ", ".join(f"{a}={b}" for a, b in k.items()))
def test_a_receipt_screenshot_is_read_dark_mode_or_light_with_no_camera_tips(kind):
    img = cf.receipt(**kind)
    assert is_screenshot(img)
    assert light_on_dark(img) is kind["dark"]
    body = post(img)
    assert not CAMERA_TIPS & set(body["tips"])
    text = "\n".join(l["text"] for l in body["lines"])
    # Each label with its value, top to bottom; long numbers exactly as printed.
    for line in ["Recipient: Ada Okonkwo", "Account number: 0123456789", "Bank: Sample Bank",
                 "Reference: TRF2026102711470001", "Date: 27 Oct 2026, 11:47", "Status: Successful"]:
        assert line in text, text
    labels = [l["text"].split(":")[0] for l in body["lines"] if ":" in l["text"]]
    assert labels == [n for n, _ in cf.RECEIPT if n in labels]  # top to bottom
    # The amount: read exactly (8,000.00), or held back whole with the money warning: never a
    # part of it, never another number.
    amount = [l["text"] for l in body["lines"] if l["text"].startswith("Amount")]
    if amount:
        assert amount == ["Amount: #8,000.00"] or amount[0].endswith("8,000.00"), amount
    else:
        assert "money_amounts_unreliable" in body["tips"]


def test_the_dark_mode_receipt_is_read_whole_amount_included():
    body = post(cf.receipt())
    assert body["tips"] == []
    assert [l["text"] for l in body["lines"]][1].endswith("8,000.00")


def test_a_genuinely_dark_camera_photo_still_hears_too_dark():
    img = cf.dark_photo()
    assert not is_screenshot(img) and not light_on_dark(img)
    assert "too_dark" in post(img, "school")["tips"]


def test_a_camera_photo_of_a_page_is_not_a_screenshot():
    assert not is_screenshot(cf.small_card())
    assert not is_screenshot(cf.thermal_slip())
    assert not is_screenshot(cf.book_page())


def test_a_dark_mode_photo_from_the_camera_is_inverted_too():
    # Light text on a dark background, 4:3 like a camera photo, with noise: not a screenshot.
    from PIL import ImageOps
    img = ImageOps.invert(cf.small_card().convert("RGB"))
    assert light_on_dark(img) and not is_screenshot(img)
    r = read_page(img)
    assert r["inverted"] and "too_dark" not in r["tips"]
    assert "Harvest Thanksgiving" in " ".join(l["text"] for l in r["lines"])


def test_a_dark_photo_with_one_bright_reflection_is_not_inverted():
    from PIL import ImageDraw
    img = cf.dark_photo().convert("RGB")
    ImageDraw.Draw(img).ellipse((500, 300, 560, 360), fill=(255, 255, 250))  # a lamp's reflection
    assert not light_on_dark(img)


def test_a_screenshot_resized_by_whatsapp_is_still_one_and_a_scanned_page_is_not():
    img = cf.receipt(fmt="JPEG").resize((738, 1600))  # WhatsApp's standard-quality resize
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=70)
    from PIL import Image
    assert is_screenshot(Image.open(io.BytesIO(buf.getvalue())))
    page = Image.new("RGB", (2480, 1140), "white")  # a rendered page: flat, but no screen's width
    assert not is_screenshot(page)
