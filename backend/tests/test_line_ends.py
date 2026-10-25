"""'End of line unclear': ink that carries on past the recognised text."""
import io
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw, ImageFilter

from app import safety
from app.main import app
from app.reader import TesseractEngine, read_page
from pagefont import font

client = TestClient(app)
FIXTURE = Path(__file__).parent / "fixtures" / "misreads" / "line_end_damaged.jpg"


def page(lines, size=40, smudge_end_of=None):
    img = Image.new("RGB", (1400, 100 + 100 * len(lines)), "white")
    d = ImageDraw.Draw(img)
    for i, t in enumerate(lines):
        d.text((60, 60 + 100 * i), t, fill="black", font=font(size))
    if smudge_end_of is not None:
        # From "than" to past the end of the line.
        y = 50 + 100 * smudge_end_of
        img.paste(img.crop((430, y, 900, y + 65)).filter(ImageFilter.GaussianBlur(4)), (430, y))
    return img


def png(img):
    buf = io.BytesIO(); img.save(buf, "PNG"); return buf.getvalue()


LABEL = ["Paracetamol 500 mg tablets", "Do not take more than 8 in 24 hours"]


def test_real_damaged_line_end_is_flagged():
    # Only "Lo nol lake mo" of "Do not take more than 8 in 24 hours" was read from this photo.
    lines = read_page(Image.open(FIXTURE), TesseractEngine())["lines"]
    dose = lines[-1]
    assert dose["end_unclear"], dose["text"]
    assert not lines[0]["end_unclear"]


def test_smudged_line_end_is_flagged():
    lines = read_page(page(LABEL, smudge_end_of=1), TesseractEngine())["lines"]
    assert [l["end_unclear"] for l in lines] == [False, True]


@pytest.mark.parametrize("size", [40, 28])
def test_clean_lines_are_not_flagged(size):
    lines = read_page(page(LABEL + ["Expiry 08/2027  Batch PCM2291"], size), TesseractEngine())["lines"]
    assert not any(l["end_unclear"] for l in lines)


def test_a_second_column_is_not_an_unread_line_end():
    img = Image.new("RGB", (1500, 300), "white")
    d = ImageDraw.Draw(img)
    for x, y, t in [(50, 60, "Haemoglobin 11.2"), (800, 60, "Platelets 250"), (50, 160, "WBC 6.4"), (800, 160, "Range 4.0 - 11.0")]:
        d.text((x, y), t, fill="black", font=font(36))
    assert not any(l["end_unclear"] for l in read_page(img, TesseractEngine())["lines"])


def test_read_endpoint_warns_line_end_unclear():
    body = client.post("/read", files={"file": ("p.png", FIXTURE.read_bytes())}).json()
    last = len(body["lines"]) - 1
    assert {"block_index": last, "code": "line_end_unclear", "word_index": None} in body["warnings"]


def test_line_end_warnings():
    assert [(w.block_index, w.code) for w in safety.line_end_warnings([{"end_unclear": False}, {"end_unclear": True}])] == [
        (1, "line_end_unclear")]
