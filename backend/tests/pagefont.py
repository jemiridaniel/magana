"""The font every generated test page is drawn with: DejaVu Sans, shipped in
tests/fixtures/fonts (free licence, tests/fixtures/fonts/LICENSE). One font everywhere, so a
page looks the same to Tesseract on a Mac, in CI and in the production image; before this,
macOS drew pages in Arial and Linux in DejaVu, and three faint-print tests passed on one and
failed on the other (docs/FINDINGS.md, 25 Oct 2026)."""
from pathlib import Path

from PIL import ImageFont

PATH = Path(__file__).parent / "fixtures" / "fonts" / "DejaVuSans.ttf"


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(PATH), size)
