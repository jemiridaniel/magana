"""Page reading: OCR into lines with confidence, ready to be spoken.

The OCR engine sits behind a small interface so the team can swap the dev engine
(Tesseract, runs anywhere) for the production engine (PaddleOCR PP-Structure for
layout and tables) without touching the API or safety layer.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Protocol

from PIL import Image, ImageFilter, ImageStat


@dataclass
class Line:
    text: str
    confidence: float  # 0-1
    top: int
    label: str = ""


class OCREngine(Protocol):
    def read(self, image: Image.Image) -> list[Line]: ...


class TesseractEngine:
    """Dev/offline-fallback engine. Groups Tesseract words into lines."""

    def __init__(self, lang: str = "eng"):
        self.lang = lang

    def read(self, image: Image.Image) -> list[Line]:
        import pytesseract

        data = pytesseract.image_to_data(image, lang=self.lang, output_type=pytesseract.Output.DICT)
        lines: dict[tuple, dict] = {}
        for i, word in enumerate(data["text"]):
            if not word.strip():
                continue
            key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
            entry = lines.setdefault(key, {"words": [], "confs": [], "top": data["top"][i]})
            entry["words"].append(word)
            entry["confs"].append(max(float(data["conf"][i]), 0.0) / 100)
        out = []
        for n, (_, e) in enumerate(sorted(lines.items(), key=lambda kv: kv[1]["top"])):
            conf = sum(e["confs"]) / len(e["confs"])
            out.append(Line(" ".join(e["words"]), round(conf, 3), e["top"], label=f"line {n + 1}"))
        return out


def capture_check(image: Image.Image) -> list[str]:
    """Spoken guidance before reading: too dark or too blurry."""
    tips = []
    gray = image.convert("L")
    if ImageStat.Stat(gray).mean[0] < 60:
        tips.append("It's quite dark. Turn on the torch or move to more light.")
    edges = gray.filter(ImageFilter.FIND_EDGES)
    if ImageStat.Stat(edges).var[0] < 50:
        tips.append("The photo looks blurry. Hold the phone still and try again.")
    return tips


def read_page(image: Image.Image, engine: OCREngine | None = None) -> dict:
    engine = engine or TesseractEngine()
    lines = engine.read(image)
    return {"tips": capture_check(image), "lines": [asdict(l) for l in lines]}
