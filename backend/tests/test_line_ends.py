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


# ---------- Part of a row not read (a statement's small amount dropped, docs/FINDINGS.md)

def _row_page(drop: str | None, underline: bool = False):
    """A statement row drawn at known places; the 'OCR' reads every word except `drop`."""
    from PIL import Image, ImageDraw

    from app.reader import Line, Page, Word

    f = font(40)
    img = Image.new("RGB", (1600, 200), "white")
    d = ImageDraw.Draw(img)
    words = []
    for text, x in [("02", 40), ("Sep", 110), ("2026", 210), ("7.50", 700), ("45,250.50", 1200)]:
        d.text((x, 60), text, fill="black", font=f)
        l, t, r, b = d.textbbox((x, 60), text, font=f)
        if text != drop:
            words.append(Word(text, 0.97, l, t, r - l, b - t))
    if underline:
        d.line((40, 120, 1500, 120), fill="black", width=3)
    top = min(w.top for w in words)
    height = max(w.top + w.height for w in words) - top
    line = Line(" ".join(w.text for w in words), 0.97, top, height=height, words=words,
                left=words[0].left, width=words[-1].left + words[-1].width - words[0].left)
    return img, Page(lines=[line])


def test_a_dropped_amount_in_the_middle_of_a_row_is_flagged():
    from app.reader import mark_unread_parts

    img, page = _row_page(drop="7.50")
    mark_unread_parts(img, page)
    assert page.lines[0].part_unclear is True


def test_a_fully_read_row_and_a_ruled_line_are_not_flagged():
    from app.reader import mark_unread_parts

    for underline in (False, True):
        img, page = _row_page(drop=None, underline=underline)
        mark_unread_parts(img, page)
        assert page.lines[0].part_unclear is False


def test_tiny_print_in_a_photo_gets_a_tip():
    from app.reader import Line, Page, Word, small_print

    def page(h):
        return Page(lines=[Line("ab cd", 0.9, i * 40, height=h + 4,
                                words=[Word("ab", 0.9, 0, i * 40, 30, h), Word("cd", 0.9, 40, i * 40, 30, h)])
                           for i in range(5)])
    assert small_print(page(7)) == ["small_print"]
    assert small_print(page(14)) == []
    assert small_print(Page(lines=[Line("Paracetamol 500 mg", 0.9, 0, height=30,
                                        words=[Word("Paracetamol", 0.9, 0, 0, 200, 30)])])) == ["read_little"]


def test_a_short_label_gets_no_small_print_tip():
    from PIL import Image, ImageDraw

    img = Image.new("RGB", (900, 300), "white")
    ImageDraw.Draw(img).text((60, 100), "Paracetamol 500 mg", fill="black", font=font(56))
    assert "small_print" not in read_page(img, TesseractEngine())["tips"]
