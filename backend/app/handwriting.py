"""Handwriting: which lines are handwritten, and an optional second reader for them.

DRAFT, NOT MEASURED. The printed/handwritten test below is a heuristic on what the OCR
already gives (word confidence, and how much word heights and baselines wander). It has
only been checked on synthetic lines; the 15 to 20 real handwritten pages needed to tune
it (docs/FINDINGS.md) have not been provided yet. It errs towards "handwritten", which
only adds a warning and stricter number checks.

What a handwritten line changes (safety.py, main.py):
  - every number on it needs two agreeing independent readings; one confident reading
    is not enough (Tesseract is confidently wrong on handwriting)
  - on a health paper its numbers are never read: "handwritten_number", and the page
    gets "handwritten_prescription" (ask the pharmacist or nurse). Pending Dr. Amos.
  - the page says it is handwritten or mixed (tips handwritten_page, mixed_page)

Optional engines for schoolwork only (MAGANA_HANDWRITING, off by default):
  trocr   microsoft/trocr-base-handwritten (MIT) on the Magana server; needs
          requirements-trocr.txt and about 1.5 GB of memory, so not on the t3.small
  azure   Azure AI Vision Read: the line crops go to Microsoft. Adults (18+) only,
          and only once PRIVACY.md's note is approved by Nurse Balogun. It costs money
          per page, so it stays off until the team decides to pay for it.
Their reading of a handwritten line is what the learner hears; each number on it must
also agree with Tesseract's own reading, or it is said as "unclear number".
"""
from __future__ import annotations

import io
import os
import re
from statistics import median
from typing import Protocol

from PIL import Image

from .reader import Line, Page, Word

# A line is handwritten when the OCR is unsure of it and its words wander in size and
# height, or when the OCR is very unsure. DRAFT thresholds, to tune on real pages.
UNSURE = 0.70
VERY_UNSURE = 0.50
WANDER = 0.18


def _wander(words: list[Word]) -> float:
    """How irregular a line's words are: spread of heights and of baselines, relative to
    the typical height. Print sits on one line at one size; handwriting doesn't."""
    sized = [w for w in words if w.height]
    if len(sized) < 2:
        return 0.0
    h = median(w.height for w in sized) or 1
    heights = [w.height / h for w in sized]
    bottoms = [(w.top + w.height) / h for w in sized]
    spread = lambda xs: (max(xs) - min(xs)) / 2  # noqa: E731
    return max(spread(heights), spread(bottoms))


def is_handwritten(line: Line, typical_height: float = 0) -> bool:
    """Unsure OCR, and wandering words (or very unsure OCR). Not judged as handwriting: a single
    "word" with no digit (a speck, an ornament, a logo), or a line under half the page's usual
    text height (fine print, which the OCR is unsure of for its size). Both were what made the
    tester's printed church card and thermal boarding pass "look handwritten" (27 Oct 2026). A
    line with a digit is always judged: a handwritten dose must never pass as print."""
    words = [w for w in line.words if w.text.strip()]
    if not words:
        return False
    has_digit = any(ch.isdigit() for w in words for ch in w.text)
    if not has_digit:
        if len(words) == 1:
            return False
        if typical_height and line.height and line.height < SMALL_PRINT * typical_height:
            return False
    conf = median(w.confidence for w in words)
    return conf < VERY_UNSURE or (conf < UNSURE and _wander(words) >= WANDER)


SMALL_PRINT = 0.5  # a line under half the usual text height: fine print, not handwriting

# Health papers (strict): a line with a number whose letters wobble off their word's baseline
# this much (in letter heights) is handwriting, however sure the OCR is. Neat handwriting can
# read with confidence: jittered handwritten doses (Caveat) read at 0.50–0.95 and wobble
# 0.075–0.126, while number lines on the 20 printed benchmark readings wobble at most 0.039
# (27 Oct 2026). A faint thermal receipt can reach 0.07: the safe side, it goes to the pharmacist.
WOBBLE = 0.06


def word_wobble(gray, word: Word) -> float | None:
    """How far a word's letters sit off their shared baseline, in letter heights: the ink cut
    into pieces at blank columns, each piece's lowest ink compared with the word's median
    (descenders, the worst quarter, left out). None when there are under 3 pieces to judge."""
    import numpy as np

    pad = max(2, word.height // 4)
    crop = gray[max(0, word.top - pad):word.top + word.height + pad, max(0, word.left):word.left + word.width]
    if crop.size == 0 or word.width < 8:
        return None
    hi, lo = np.percentile(crop, 90), np.percentile(crop, 5)
    if hi - lo < 25:
        return None
    ink = crop < hi - 0.4 * (hi - lo)
    cols = ink.any(axis=0)
    bottoms, heights, x, n = [], [], 0, len(cols)
    while x < n:
        if not cols[x]:
            x += 1
            continue
        start = x
        while x < n and cols[x]:
            x += 1
        rows = np.where(ink[:, start:x].any(axis=1))[0]
        if len(rows) and x - start >= 2:
            bottoms.append(rows[-1])
            heights.append(rows[-1] - rows[0] + 1)
    if len(bottoms) < 3:
        return None
    h = float(np.median(heights)) or 1.0
    dev = np.sort(np.abs(np.array(bottoms, dtype=float) - np.median(bottoms)) / h)
    return float(np.mean(dev[: max(2, int(len(dev) * 0.75))]))


def wobbles(gray, line: Line) -> bool:
    values = [v for w in line.words if w.width for v in [word_wobble(gray, w)] if v is not None]
    return bool(values) and median(values) >= WOBBLE


def classify(page: Page, image: Image.Image | None = None, strict: bool = False) -> str:
    """Marks each line's `script` and returns the page's: printed, handwritten or mixed. With
    [strict] (health papers) and the photo, a line with a number that wobbles is handwritten too."""
    import numpy as np

    hand = 0
    sure = [l.height for l in page.lines if l.height and l.confidence >= UNSURE]
    typical = median(sure) if sure else 0
    gray = np.asarray(image.convert("L"), dtype=float) if strict and image is not None else None
    for line in page.lines:
        written = is_handwritten(line, typical)
        if not written and gray is not None and any(ch.isdigit() for ch in line.text):
            written = wobbles(gray, line)
        line.script = "handwritten" if written else "printed"
        hand += line.script == "handwritten"
    if not hand:
        return "printed"
    return "handwritten" if hand >= 0.6 * len(page.lines) else "mixed"


# ---------- Optional second readers (schoolwork only)

class LineReader(Protocol):
    name: str

    def read_line(self, crop: Image.Image) -> tuple[str, float]: ...


class TrOCRReader:
    """microsoft/trocr-base-handwritten on the Magana server (requirements-trocr.txt)."""

    name = "trocr"
    MODEL = "microsoft/trocr-base-handwritten"

    def __init__(self):
        from transformers import TrOCRProcessor, VisionEncoderDecoderModel  # optional dependency

        self.processor = TrOCRProcessor.from_pretrained(self.MODEL)
        self.model = VisionEncoderDecoderModel.from_pretrained(self.MODEL)

    def read_line(self, crop: Image.Image) -> tuple[str, float]:
        import torch

        pixels = self.processor(images=crop.convert("RGB"), return_tensors="pt").pixel_values
        with torch.no_grad():
            out = self.model.generate(pixels, output_scores=True, return_dict_in_generate=True, max_new_tokens=64)
        text = self.processor.batch_decode(out.sequences, skip_special_tokens=True)[0].strip()
        scores = self.model.compute_transition_scores(out.sequences, out.scores, normalize_logits=True)
        conf = float(torch.exp(scores.mean())) if scores.numel() else 0.0
        return text, conf


class AzureReadReader:
    """Azure AI Vision Image Analysis 4.0 'read' (synchronous). The crop leaves Magana."""

    name = "azure"

    def __init__(self, endpoint: str, key: str, client=None):
        import httpx

        self.url = endpoint.rstrip("/") + "/computervision/imageanalysis:analyze"
        self.key = key
        self.client = client or httpx.Client(timeout=10)

    def read_line(self, crop: Image.Image) -> tuple[str, float]:
        buf = io.BytesIO()
        crop.convert("RGB").save(buf, "PNG")
        r = self.client.post(self.url, params={"api-version": "2024-02-01", "features": "read"},
                             headers={"Ocp-Apim-Subscription-Key": self.key,
                                      "Content-Type": "application/octet-stream"},
                             content=buf.getvalue())
        r.raise_for_status()
        words = [w for block in r.json().get("readResult", {}).get("blocks", [])
                 for line in block.get("lines", []) for w in line.get("words", [])]
        if not words:
            return "", 0.0
        return " ".join(w["text"] for w in words), min(float(w.get("confidence", 0)) for w in words)


def reader_from_env() -> LineReader | None:
    """MAGANA_HANDWRITING: off (default), trocr, or azure (AZURE_VISION_ENDPOINT, AZURE_VISION_KEY)."""
    kind = os.environ.get("MAGANA_HANDWRITING", "off").strip().lower()
    if kind == "trocr":
        return TrOCRReader()
    if kind == "azure":
        endpoint, key = os.environ.get("AZURE_VISION_ENDPOINT", ""), os.environ.get("AZURE_VISION_KEY", "")
        return AzureReadReader(endpoint, key) if endpoint and key else None
    return None


def _crop(image: Image.Image, line: Line) -> Image.Image:
    pad = max(4, line.height // 3)
    right = line.left + line.width if line.width else image.width
    return image.crop((max(0, line.left - pad), max(0, line.top - pad),
                       min(image.width, right + pad), min(image.height, line.top + line.height + pad)))


_NUM = re.compile(r"\d")


def reread_handwritten(image: Image.Image, page: Page, reader: LineReader) -> int:
    """Reads each handwritten line again with `reader` and uses that reading for the line.
    Each number in it keeps Tesseract's reading of the same number as its second reading,
    so it is spoken only if both agree (safety.number_warnings). Returns lines re-read."""
    done = 0
    for line in page.lines:
        if getattr(line, "script", "") != "handwritten" or not line.height:
            continue
        try:
            text, conf = reader.read_line(_crop(image, line))
        except Exception:
            continue  # the engine failed: keep the first reading and its warnings
        if not text.strip():
            continue
        first_numbers = [w for w in line.words if _NUM.search(w.text)]
        words = []
        for t in text.split():
            w = Word(t, conf)
            if _NUM.search(t):
                other = first_numbers.pop(0) if first_numbers else None
                w.reread_text = other.text if other else ""
                w.reread_confidence = other.confidence if other else 0.0
            words.append(w)
        line.words, line.text, line.confidence = words, text, conf
        line.reader = reader.name
        done += 1
    return done
