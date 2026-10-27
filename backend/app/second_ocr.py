"""The second engine for WhatsApp's money amounts (amounts.py): RapidOCR, PaddleOCR's PP-OCR
models on ONNX Runtime (Apache-2.0), next to Tesseract.

It runs in a short-lived child process, one photo at a time, so its memory (about 400 MB while
reading, measured on the Mac with one thread) goes back as soon as it has read: the server is a
2 GB t3.small. Only the lines' text comes back. The photo goes to the child through a pipe and
is never written to disk. Any failure (not installed, too slow, crashed) means no second
reading, and then no amount is said.

    python -m app.second_ocr < photo  →  {"lines": ["Amount", "#8,000.00", ...]}
"""
from __future__ import annotations

import importlib.util
import json
import logging
import subprocess
import sys
import threading
from pathlib import Path

log = logging.getLogger("magana.second_ocr")

TIMEOUT_S = 20
_one_at_a_time = threading.Semaphore(1)


def available() -> bool:
    # Found without importing it: ONNX Runtime is only ever loaded in the child.
    return importlib.util.find_spec("rapidocr_onnxruntime") is not None


def read_lines(data: bytes) -> list[str] | None:
    """The second engine's lines of text for the photo [data], or None if it couldn't read."""
    if not available():
        return None
    with _one_at_a_time:
        try:
            done = subprocess.run([sys.executable, "-m", "app.second_ocr"], input=data,
                                  capture_output=True, timeout=TIMEOUT_S, check=True,
                                  cwd=Path(__file__).resolve().parents[1])
            return json.loads(done.stdout)["lines"]
        except Exception as e:  # never the photo or its text in the log
            log.warning("second OCR failed: %s", type(e).__name__)
            return None


def _main() -> None:
    import io

    import numpy as np
    from PIL import Image, ImageOps
    from rapidocr_onnxruntime import RapidOCR

    image = ImageOps.exif_transpose(Image.open(io.BytesIO(sys.stdin.buffer.read()))).convert("RGB")
    engine = RapidOCR(intra_op_num_threads=1, inter_op_num_threads=1, det_limit_type="max",
                      det_limit_side_len=1600)
    found, _ = engine(np.asarray(image)[:, :, ::-1])  # BGR, as OpenCV
    json.dump({"lines": [text for _, text, _ in found or []]}, sys.stdout)


if __name__ == "__main__":
    _main()
