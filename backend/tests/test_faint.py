"""Faint print: contrast-boost and retry, and say so when ink still gives no text."""
import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw, ImageFilter

from app.main import app
from app.reader import TesseractEngine, ink_bands, ink_map, read_page
from pagefont import font

client = TestClient(app)
PAPER = (250, 248, 240)


_font = font


def label_page(grey: int | None, blur: float = 0.0) -> Image.Image:
    """A medicine label: a black heading, then the dose line printed faintly."""
    img = Image.new("RGB", (1400, 420), PAPER)
    ImageDraw.Draw(img).text((60, 60), "Paracetamol 500 mg tablets", fill="black", font=_font(48))
    if grey is not None:
        band = Image.new("RGB", (1400, 120), PAPER)
        ImageDraw.Draw(band).text((60, 20), "Do not take more than 8 in 24 hours", fill=(grey,) * 3, font=_font(34))
        img.paste(band.filter(ImageFilter.GaussianBlur(blur)) if blur else band, (0, 200))
    return img


def png(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


@pytest.mark.parametrize("grey, blur", [(150, 1.0), (200, 0.6), (235, 0.5)])
def test_faint_dose_line_is_recovered(grey, blur):
    # Plain OCR drops this line: the black heading sets a threshold the grey text falls under.
    result = read_page(label_page(grey, blur), TesseractEngine())
    texts = [l["text"] for l in result["lines"]]
    assert any("24 hours" in t for t in texts), texts
    assert result["faint_regions"] == []


def test_ink_without_readable_text_is_reported_as_a_faint_region():
    result = read_page(label_page(200, blur=5.0), TesseractEngine())
    assert not any("24" in l["text"] for l in result["lines"])
    [region] = result["faint_regions"]
    assert 190 <= region["top"] <= 260 and region["bottom"] > region["top"]


def test_clean_page_has_no_faint_regions():
    assert read_page(label_page(None), TesseractEngine())["faint_regions"] == []


def test_shading_and_a_dark_table_edge_are_not_ink():
    """A photo: tinted paper with a lighting gradient, lying on a dark table."""
    img = Image.new("RGB", (1200, 900), (40, 35, 30))
    page = Image.new("L", (1000, 700))
    page.putdata([int(235 - 25 * x / 1000) for y in range(700) for x in range(1000)])
    img.paste(Image.merge("RGB", (page, page, page)), (100, 100))
    ImageDraw.Draw(img).text((160, 200), "Take 2 tablets every 4 to 6 hours", fill="black", font=_font(40))
    result = read_page(img, TesseractEngine())
    assert any("tablets" in l["text"] for l in result["lines"])
    assert result["faint_regions"] == []


def test_ink_bands_find_each_printed_line():
    bands = ink_bands(ink_map(label_page(235, 0.5)))
    assert len(bands) == 2
    assert bands[0][0] < 120 < bands[1][0]


def test_read_endpoint_returns_faint_regions():
    body = client.post("/read", files={"file": ("p.png", png(label_page(200, blur=5.0)))}).json()
    assert len(body["faint_regions"]) == 1


@pytest.mark.parametrize("blur", [3.0, 4.0])
def test_a_blurred_dose_misread_as_another_number_is_flagged(blur):
    # Between readable and unreadable, Tesseract reads the printed 8 as 6 (DejaVu Sans, both
    # Tesseract 5.5.0 in the production image and 5.5.3 on a Mac). The re-read must flag it.
    body = client.post("/read", data={"mode": "health"},
                       files={"file": ("p.png", png(label_page(200, blur=blur)))}).json()
    [dose] = [i for i, l in enumerate(body["lines"]) if "24" in l["text"]]
    words = body["lines"][dose]["text"].split()
    flagged = {w["word_index"] for w in body["warnings"] if w["block_index"] == dose}
    for i, w in enumerate(words):
        if w.isdigit() and w not in ("8", "24"):
            assert i in flagged, (words, body["warnings"])
