"""Handwriting on real and drawn samples (handwriting_fixtures.py), and the printed items that
used to be called handwritten: a thermal slip and a decorative card (27 Oct 2026)."""
import io

import pytest
from fastapi.testclient import TestClient

import capture_fixtures as cf
import handwriting_fixtures as hf
from app.main import app

client = TestClient(app)


def read(img, mode="school", level="2"):
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=92)
    return client.post("/read", files={"file": ("p.jpg", buf.getvalue())}, data={"mode": mode},
                       headers={"X-Magana-Messages": level, "X-Magana-Tier": "standard"}).json()


def digit_words(body):
    return {(i, j) for i, l in enumerate(body["lines"]) if l["script"] == "handwritten"
            for j, w in enumerate(l["words"]) if any(c.isdigit() for c in w["text"])}


@pytest.mark.parametrize("side", ["a", "b"])
def test_a_real_handwritten_letter_is_still_called_handwritten(side):
    body = read(hf.underhill(side))
    assert body["script"] == "handwritten" and "handwritten_page" in body["tips"]
    assert sum(l["script"] == "handwritten" for l in body["lines"]) >= 0.9 * len(body["lines"])


@pytest.mark.parametrize("img", [hf.underhill("a"), hf.handwritten_rx()], ids=["real cursive", "neat print-style"])
def test_a_handwritten_prescription_is_never_read(img):
    body = read(img, mode="health")
    assert "handwritten_prescription" in body["tips"]
    flagged = {(w["block_index"], w["word_index"]) for w in body["warnings"] if w["code"] == "handwritten_number"}
    # Every number on a handwritten line is withheld; and every line holding a number is one.
    assert digit_words(body) <= flagged
    for l in body["lines"]:
        if any(c.isdigit() for c in l["text"]):
            assert l["script"] == "handwritten", l["text"]


def test_the_neat_prescription_was_missed_by_ocr_doubt_alone():
    """Why health papers have the stricter (wobble) check: in school mode the same lines pass as
    print (the OCR is sure of them); they keep the normal number checks there."""
    body = read(hf.handwritten_rx(), mode="school")
    assert body["script"] == "printed"


@pytest.mark.parametrize("img", [cf.thermal_slip(), cf.small_card()], ids=["thermal slip", "card"])
def test_printed_items_are_not_called_handwritten(img):
    body = read(img)
    assert not {"mixed_page", "handwritten_page", "handwritten_prescription"} & set(body["tips"])


def test_a_printed_medicine_label_photo_is_not_sent_to_the_pharmacist():
    import sys
    sys.path.insert(0, "scripts")
    import bank_benchmark as bb
    from letter_ocr_test import draw
    from pathlib import Path
    label = (Path(__file__).parents[2] / "benchmark" / "explain" / "pages" / "04_medicine_label.txt").read_text()
    body = read(bb.photo_like(draw(label)), mode="health")
    assert "handwritten_prescription" not in body["tips"]


def test_a_barcode_line_is_dropped_and_said_once():
    """On the tester's boarding pass the OCR read the barcode as lines of junk; Tesseract skips
    this clean one, so its line is made by hand here."""
    import numpy as np

    from app.reader import Line, Page, TesseractEngine, drop_barcodes, is_barcode
    img = hf.with_barcode()
    page = TesseractEngine().read(img)
    gray = np.asarray(img.convert("L"), dtype=float)
    # Capitals have tall strokes, but leave space above or below most columns: never bars.
    assert not any(is_barcode(gray, l) for l in page.lines)
    bars = Line("lI|I|lll|I", 0.2, 380, height=180, left=80, width=1320)
    page.lines.append(bars)
    assert is_barcode(gray, bars)
    assert drop_barcodes(img, page) == 1 and bars not in page.lines and len(page.lines) == 3


def test_new_tips_are_left_out_for_older_apps():
    from app import messages
    assert messages.tips_for(["faint_print", "barcode_skipped"], 2) == ["faint_print", "barcode_skipped"]
    assert messages.tips_for(["faint_print", "barcode_skipped"], 1) == ["faint_print"]
    from app.main import messages_level
    assert (messages_level(None), messages_level("2"), messages_level("x")) == (1, 2, 1)
