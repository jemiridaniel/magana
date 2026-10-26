"""Synthetic stand-ins for two real iPhone failures (docs/FINDINGS.md, 27 Oct 2026). No real photo
is in the repository: the tester's boarding pass carried their name.

- small_card(): a small printed card held against a pale, textured wall, filling about 6% of
  a 12-megapixel-style photo. No page edges stand out from the wall.
- thermal_slip(): a faint thermal-printed slip (grey print on grey-white paper) whose left edge
  is torn off through the words, lying on a darker surface.
Both are drawn at phone-photo size (2016 x 1512 or 1512 x 2016) and saved as JPEG, like a camera.
"""
from __future__ import annotations

import io
import random

from PIL import Image, ImageDraw, ImageFilter

import pagefont

CARD_LINES = ["St Luke's Church", "Harvest Thanksgiving", "Sunday 16 November 2026", "Service starts 9:30 am",
              "All are welcome"]
SLIP_LINES = ["BOARDING PASS", "PASSENGER TEST/ADA", "FROM LAGOS LOS", "TO ABUJA ABV", "FLIGHT P4 7123",
              "SEAT 14C GATE B2", "BOARDING 06:45"]


def _jpeg(img: Image.Image) -> Image.Image:
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


def _wall(size: tuple[int, int], tone: int, seed: int) -> Image.Image:
    """A pale painted wall: an even tone with fine noise and a soft light fall-off."""
    rnd = random.Random(seed)
    w, h = size
    noise = Image.new("L", (w // 8, h // 8))
    noise.putdata([tone + rnd.randint(-6, 6) for _ in range((w // 8) * (h // 8))])
    wall = noise.resize(size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(3))
    return Image.merge("RGB", [wall, wall, wall.point(lambda v: max(0, v - 8))])


def small_card(size: tuple[int, int] = (1512, 2016)) -> Image.Image:
    """Portrait photo; the card (white, about 500 x 300 px) sits in the middle of a cream wall."""
    photo = _wall(size, 214, seed=7)
    card = Image.new("RGB", (520, 300), (250, 250, 247))
    d = ImageDraw.Draw(card)
    f = pagefont.font(30)
    for i, line in enumerate(CARD_LINES):
        d.text((24, 22 + i * 52), line, fill=(25, 25, 30), font=f)
    card = card.rotate(2, resample=Image.BICUBIC, expand=True, fillcolor=(214, 214, 206))
    photo.paste(card, ((size[0] - card.width) // 2, (size[1] - card.height) // 2))
    return _jpeg(photo.filter(ImageFilter.GaussianBlur(0.6)))


def thermal_slip(size: tuple[int, int] = (2016, 1512)) -> Image.Image:
    """Landscape photo; a faint slip whose left edge is torn through the first letters."""
    photo = Image.new("RGB", size, (92, 84, 78))  # a dark table
    slip = Image.new("RGB", (1300, 860), (236, 234, 230))
    d = ImageDraw.Draw(slip)
    f = pagefont.font(52)
    for i, line in enumerate(SLIP_LINES):
        # Starts left of the slip: the tear cut through the first letter or two.
        d.text((-18, 40 + i * 110), line, fill=(188, 186, 184), font=f)
    photo.paste(slip, ((size[0] - slip.width) // 2, (size[1] - slip.height) // 2))
    return _jpeg(photo.filter(ImageFilter.GaussianBlur(0.8)))
