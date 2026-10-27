"""Handwriting for tests (docs/FINDINGS.md, 27 Oct 2026; credited in docs/DATA_SOURCES.md):
- fixtures/handwriting/underhill_a.jpg, underhill_b.jpg: a handwritten letter by Wilbur Underhill
  Jr. (1930s cursive on ruled paper), public domain, from Wikimedia Commons; scaled to 1200 px.
- handwritten_rx(): print-style handwriting, drawn letter by letter in Caveat (SIL Open Font
  Licence, fixtures/fonts/Caveat.ttf) with each letter's size, slant and baseline jittered, as
  a hand writes. Neat enough that the OCR reads it with confidence.
- with_barcode(): a printed slip with a barcode below its text."""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import pagefont

HERE = Path(__file__).parent / "fixtures"
CAVEAT = str(HERE / "fonts" / "Caveat.ttf")
RX_LINES = ["Paracetamol 500mg take 2 tabs", "Amoxil 250mg 3 times daily", "Review on 14 Nov 2026"]


def underhill(side: str = "a") -> Image.Image:
    return Image.open(HERE / "handwriting" / f"underhill_{side}.jpg").convert("RGB")


def _jittered(text: str, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    img = Image.new("L", (1800, 140), 255)
    x, drift = 40, 0.0
    for ch in text:
        size = int(56 * rnd.uniform(0.85, 1.15))
        f = ImageFont.truetype(CAVEAT, size)
        drift += rnd.uniform(-1.5, 1.5)
        glyph = Image.new("L", (size * 2, size * 2), 0)
        ImageDraw.Draw(glyph).text((size // 2, size // 3), ch, fill=255, font=f)
        glyph = glyph.rotate(rnd.uniform(-8, 8), resample=Image.BICUBIC)
        img.paste(0, (x - size // 2, int(30 + drift + rnd.uniform(-5, 5)) - size // 3), glyph)
        x += int(f.getlength(ch) * rnd.uniform(0.9, 1.15)) + (rnd.randint(0, 4) if ch != " " else 10)
    return img.convert("RGB")


def handwritten_rx() -> Image.Image:
    page = Image.new("RGB", (1800, 520), "white")
    for i, line in enumerate(RX_LINES):
        page.paste(_jittered(line, 10 + i), (0, 20 + 160 * i))
    return page


def with_barcode() -> Image.Image:
    img = Image.new("RGB", (1600, 700), "white")
    d = ImageDraw.Draw(img)
    for i, t in enumerate(["BOARDING PASS", "FLIGHT P4 7123", "SEAT 14C GATE B2"]):
        d.text((80, 40 + 90 * i), t, fill="black", font=pagefont.font(48))
    rnd = random.Random(3)
    x = 80
    while x < 1400:
        w = rnd.choice([3, 5, 8, 12])
        d.rectangle([x, 380, x + w, 560], fill="black")
        x += w + rnd.choice([3, 5, 8])
    return img
