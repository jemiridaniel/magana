"""The tester's church card (27 Oct 2026): a word the OCR read with confidence is spoken as read,
never turned into "unclear number"; a tilted photo is straightened; no "looks handwritten"."""
import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

import capture_fixtures as cf
from app import safety
from app.main import app
from app.reader import read_page, skew_angle

client = TestClient(app)


def post(img, mode):
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85)
    return client.post("/read", files={"file": ("card.jpg", buf.getvalue())}, data={"mode": mode},
                       headers={"X-Magana-Messages": "2", "X-Magana-Tier": "standard"}).json()


@pytest.mark.parametrize("mode", ["school", "letter", "health"])
def test_a_confident_word_without_a_digit_is_never_an_unclear_number(mode):
    body = post(cf.script_card(), mode)
    text = " ".join(l["text"] for l in body["lines"])
    assert "utmost delight" in text
    for w in body["warnings"]:
        if w["code"] in safety.NUMBER_CODES and w.get("word_index") is not None:
            word = body["lines"][w["block_index"]]["words"][w["word_index"]]
            assert any(c.isdigit() for c in word["text"]) or word["confidence"] < safety.CRITICAL_WORD_THRESHOLD, word
    assert "mixed_page" not in body["tips"] and "handwritten_page" not in body["tips"]


def test_any_number_on_the_card_is_said_or_flagged_never_guessed():
    body = post(cf.script_card(), "school")
    flagged = {(w["block_index"], w["word_index"]) for w in body["warnings"] if w["code"] in safety.NUMBER_CODES}
    for i, l in enumerate(body["lines"]):
        for j, w in enumerate(l["words"]):
            if any(c.isdigit() for c in w["text"]) and (i, j) not in flagged:
                assert safety.number_accepted({**w, "reread_confidence": w.get("reread_confidence")})


@pytest.mark.parametrize("angle", [8, 12, -10])
def test_a_tilted_photo_is_straightened(angle):
    import sys
    sys.path.insert(0, "scripts")
    from letter_ocr_test import draw
    from pathlib import Path
    text = (Path(__file__).parents[2] / "benchmark" / "explain" / "pages" / "04_medicine_label.txt").read_text()
    img = draw(text).rotate(angle, expand=True, fillcolor="white", resample=Image.BICUBIC)
    assert abs(skew_angle(img) + angle) <= 0.5
    lines = [l["text"] for l in read_page(img)["lines"]]
    assert any("Paracetamol" in t for t in lines)
