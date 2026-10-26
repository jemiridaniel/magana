"""Tesseract against PaddleOCR (PP-StructureV3), through Magana's whole pipeline: the same
read_page (faint print, line ends, unread parts, each number re-read from a crop), the same
second pass for health and money pages, the same safety warnings (main.checked).

    cd backend
    .venv/bin/python scripts/ocr_compare.py tesseract --part benchmark|photo|misreads|bank [--bank PDF --bank-pages 2]
    nice -n 19 .venv-paddle/bin/python scripts/ocr_compare.py paddle --part benchmark --max-mb 2500 --out results.jsonl

One line per page, flushed at once (and appended to --out), so a stopped run keeps what it
measured. A watchdog stops the run if it uses more than --max-mb (default 2500), so it can't
freeze the computer. Run each engine and part in its own process.
Pages:
  benchmark  the 10 team-made pages in benchmark/explain/pages, drawn at about 300 dpi
             (clean), and the same made phone-like (bank_benchmark.photo_like)
  misreads   the photos in tests/fixtures/misreads where "8 in 24 hours" was really
             misread: is the 8 read, flagged, or misread with no warning?
  bank       optional, private: the statement's first pages as a 300 dpi masked scan
Totals only are printed: no text from the private statement.
"""
from __future__ import annotations

import json
import os
import re
import resource
import subprocess
import sys
import textwrap
import threading
import time
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parents[1] / "tests"))
import bank_benchmark as bb  # noqa: E402
import pagefont  # noqa: E402
from app import main, pdfs  # noqa: E402
from app.reader import PaddleStructureEngine, TesseractEngine, read_page  # noqa: E402

PAGES = HERE.parents[2] / "benchmark" / "explain" / "pages"
MISREADS = HERE.parents[1] / "tests" / "fixtures" / "misreads"
STRICT = ("medicine", "malaria", "bank", "electricity", "vaccination")  # health/money: second pass
NUM = re.compile(r"\d[\d,./:]*\d|\d")
FONT_PX, LINE_PX, MARGIN = 40, 62, 100


def draw(text: str) -> tuple[Image.Image, list[tuple[str, int, int, int]]]:
    """A page at about 300 dpi, and each number's (text, left, right, middle y) on it."""
    lines = [w for para in text.splitlines() for w in (textwrap.wrap(para, 64) or [""])]
    img = Image.new("RGB", (2480, MARGIN * 2 + LINE_PX * max(len(lines), 1)), "white")
    d, f = ImageDraw.Draw(img), pagefont.font(FONT_PX)
    numbers = []
    for i, line in enumerate(lines):
        y = MARGIN + i * LINE_PX
        d.text((MARGIN, y), line, fill="black", font=f)
        for m in NUM.finditer(line):
            x0 = MARGIN + d.textlength(line[:m.start()], font=f)
            x1 = MARGIN + d.textlength(line[:m.end()], font=f)
            numbers.append((m.group(), int(x0), int(x1), y + FONT_PX // 2))
    return img, numbers


class _W:  # what bb.score_ocr expects of a true number (PDF points: scaled by pdfs.SCALE)
    def __init__(self, text, x0, x1, y, h=FONT_PX):
        s = pdfs.SCALE
        self.text, self.x0, self.x1, self.top, self.bottom = text, x0 / s, x1 / s, (y - h / 2) / s, (y + h / 2) / s


def score(result: dict, numbers, place, scale: float = 1.0) -> Counter:
    scored = [(_W(t, x0, x1, y), "number") for t, x0, x1, y in numbers]
    return bb.score_ocr(result, scored, place, scale)


def run(engine, image: Image.Image, strict: bool) -> tuple[dict, float]:
    t = time.time()
    result = main.checked(read_page(image, engine, second_pass=strict), "health" if strict else "school")
    return result, time.time() - t


def rss_mb() -> int:
    """This process's memory now (resident), in MB."""
    try:
        return int(subprocess.check_output(["ps", "-o", "rss=", "-p", str(os.getpid())]).strip()) // 1024
    except Exception:
        return 0


def watchdog(cap_mb: int, log) -> None:
    """Stops the run cleanly when it uses more than cap_mb, so it can't freeze the computer."""
    def watch():
        while True:
            now = rss_mb()
            if now > cap_mb:
                log({"stopped": "memory", "rss_mb": now, "cap_mb": cap_mb})
                os._exit(3)
            time.sleep(2)
    threading.Thread(target=watch, daemon=True).start()


def main_(name: str, part: str, bank: str | None, bank_pages: int, cap_mb: int, out_file: str | None) -> None:
    def log(row: dict) -> None:  # one line per page, flushed at once: nothing is lost if it stops
        line = json.dumps({"engine": name, "part": part, **row})
        print(line, flush=True)
        if out_file:
            with open(out_file, "a") as f:
                f.write(line + "\n")

    watchdog(cap_mb, log)
    engine = PaddleStructureEngine() if name == "paddle" else TesseractEngine()
    total, seconds, pages = Counter(), 0.0, 0

    def page_done(label: str, counts: Counter, secs: float) -> None:
        nonlocal total, seconds, pages
        total += counts
        seconds += secs
        pages += 1
        log({"page": label, "counts": dict(sorted(counts.items())), "seconds": round(secs, 1), "rss_mb": rss_mb()})

    if part in ("benchmark", "photo"):
        for path in sorted(PAGES.glob("*.txt")):
            strict = any(s in path.name for s in STRICT)
            img, numbers = draw(path.read_text())
            if part == "benchmark":
                res, secs = run(engine, img, strict)
                page_done(path.stem, score(res, numbers, lambda x, y: (x, y)), secs)
            else:
                photo = bb.photo_like(img)
                res, secs = run(engine, photo, strict)
                size = photo.size
                page_done(path.stem, score(res, numbers, lambda x, y: bb.to_photo(x, y, size), bb.PHOTO_SCALE), secs)
    elif part == "misreads":
        for path in sorted(MISREADS.iterdir()):
            if path.suffix.lower() not in {".png", ".jpg", ".jpeg"} or not path.name.startswith("dose"):
                continue
            res, secs = run(engine, Image.open(path).convert("RGB"), True)
            flagged_lines = {w["block_index"] for w in res["warnings"]}
            dose = [(i, l) for i, l in enumerate(res["lines"]) if "24" in l["text"] and "more" in l["text"].lower()]
            if not dose:
                c = Counter({"dose_line_missing_" + ("flagged" if res.get("faint_regions") else "silently"): 1})
            else:
                i, line = dose[0]
                eight = "8" in line["text"].split()
                c = Counter({f"8_{'read' if eight else 'misread'}_{'flagged' if i in flagged_lines else 'not_flagged'}": 1})
            page_done(path.name, c, secs)
    elif part == "bank" and bank:
        data = Path(bank).expanduser().read_bytes()
        carried = None
        for number, count, words, page in pdfs.pages(data):
            if number > bank_pages:
                break
            scored, private, carried = bb.ground_truth(words, carried)
            res, secs = run(engine, bb.masked_render(page, private), True)
            page_done(f"page {number}", bb.score_ocr(res, scored, lambda x, y: (x, y)), secs)
    log({"done": True, "pages": pages, "counts": dict(sorted(total.items())), "seconds": round(seconds, 1),
         "peak_rss_mb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 * 1024 if sys.platform == "darwin" else 1024))})


if __name__ == "__main__":
    args = sys.argv[1:]
    opt = lambda k, d=None: args[args.index(k) + 1] if k in args else d  # noqa: E731
    bank = opt("--bank")
    try:
        main_(args[0], opt("--part", "benchmark"), bank, int(opt("--bank-pages", "2")), int(opt("--max-mb", "2500")),
              opt("--out"))
    except Exception as e:  # never print a message that could quote the statement
        print(json.dumps({"error": type(e).__name__}), flush=True)
        if not bank:
            raise
