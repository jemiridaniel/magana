"""A whole line the OCR drops is never lost in silence (27 Oct 2026: "in all things" on the
script-font card was left out with no warning). Text-like ink that no read line covers is said at
its place: "I may have missed a line here". False alarms stay rare on ordinary pages."""
import io
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

import capture_fixtures as cf
import handwriting_fixtures as hf
from app.main import app
from app.reader import read_page

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from letter_ocr_test import draw  # noqa: E402
import bank_benchmark as bb  # noqa: E402

client = TestClient(app)
PAGES = sorted((Path(__file__).resolve().parents[2] / "benchmark" / "explain" / "pages").glob("*.txt"))


def post(img, level: str | None):
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85)
    headers = {"X-Magana-Tier": "standard"}
    if level:
        headers["X-Magana-Messages"] = level
    return client.post("/read", files={"file": ("card.jpg", buf.getvalue())}, data={"mode": "school"},
                       headers=headers).json()


def missed(result: dict) -> list[dict]:
    return [r for r in result["faint_regions"] if r["code"] == "missed_line"]


def test_every_line_of_the_script_card_is_read_or_said_to_be_missed():
    r = read_page(cf.script_card())
    text = " ".join(l["text"] for l in r["lines"]).lower()
    regions = missed(r)
    lost = [line for line in cf.SCRIPT_CARD_LINES
            if not any(w in text.split() for w in line.lower().split() if len(w) > 2)]
    # Each line not read has a "missed line" at its place, between the lines around it.
    assert len(regions) >= len(lost)
    for region in regions:
        above = [l for l in r["lines"] if l["top"] + l["height"] <= region["top"]]
        below = [l for l in r["lines"] if l["top"] >= region["bottom"]]
        assert above and below, region
        assert region["bottom"] - region["top"] < 3 * min(l["height"] for l in r["lines"])


def test_newer_apps_hear_a_missed_line_older_apps_hear_faint_print():
    new, old = post(cf.script_card(), "3"), post(cf.script_card(), None)
    if not missed(new):
        pytest.skip("this Tesseract read every line of the card")
    assert [r["code"] for r in old["faint_regions"]] == ["faint_region"] * len(old["faint_regions"])
    assert len(old["faint_regions"]) == len(new["faint_regions"])


@pytest.mark.parametrize("path", PAGES[:6], ids=lambda p: p.stem)
def test_no_false_alarm_on_ordinary_pages(path):
    page = draw(path.read_text())
    for img in (page, bb.photo_like(page)):
        img = img.convert("RGB")
        img = img.resize((1080, round(img.height * 1080 / img.width)))
        assert missed(read_page(img)) == []


@pytest.mark.parametrize("make", [cf.small_card, cf.thermal_slip, hf.handwritten_rx, hf.with_barcode])
def test_no_false_alarm_on_cards_slips_and_barcodes(make):
    assert missed(read_page(make())) == []
