"""A thin book page (tester, build 10, 27 Oct 2026: "unclear" after every sentence): the other
side's print shows through, faint and mirrored, and a hand shadow covers the lower page. The
show-through is never spoken and never makes a line "unclear"; the shadow is evened out."""
import glob
import io
import sys
from pathlib import Path

import pytest
from PIL import Image

import capture_fixtures as cf
from app.main import checked
from app.reader import read_page, shadowed, TesseractEngine

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from letter_ocr_test import draw  # noqa: E402
import bank_benchmark as bb  # noqa: E402

BACK_WORDS = {w.lower() for line in cf.BACK_LINES for w in line.split()} - {
    w.lower() for line in cf.BOOK_LINES for w in line.split()}


@pytest.mark.parametrize("shadow", [False, True], ids=["plain", "hand shadow"])
def test_the_book_page_is_read_and_its_back_is_never_spoken(shadow):
    r = checked(read_page(cf.book_page(shadow=shadow)))
    text = " ".join(l["text"] for l in r["lines"])
    for line in cf.BOOK_LINES:
        assert line.split()[-1] in text, line  # every line of the page, to its end
    assert len(r["lines"]) == len(cf.BOOK_LINES)  # nothing from the other side
    assert not (set(text.lower().split()) & BACK_WORDS)
    assert r["warnings"] == [], "show-through must not make a line unclear"
    assert r["faint_regions"] == []  # no "faint print", no "missed line" for the page behind


def test_a_hand_shadow_is_seen_and_light_falling_off_across_a_photo_is_not():
    engine = TesseractEngine()
    for img, expected in [(cf.book_page(shadow=True), True), (cf.book_page(), False)]:
        assert shadowed(img, engine.read(img)) is expected
    for path in sorted(glob.glob(str(Path(__file__).resolve().parents[2] / "benchmark/explain/pages/*.txt")))[:4]:
        photo = bb.photo_like(draw(Path(path).read_text())).convert("RGB")  # shaded to one side
        photo = photo.resize((1080, round(photo.height * 1080 / photo.width)))
        buf = io.BytesIO()
        photo.save(buf, "JPEG", quality=85)
        photo = Image.open(io.BytesIO(buf.getvalue()))
        assert shadowed(photo, engine.read(photo)) is False, path
