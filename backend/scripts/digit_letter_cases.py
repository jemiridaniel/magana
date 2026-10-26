"""Igbo words in which Tesseract `eng` read ọ as the digit 9 (docs/FINDINGS.md, 26 Oct 2026).

    cd backend && .venv/bin/python scripts/digit_letter_cases.py [--out tests/fixtures/letters/ig_digit_cases.json]

The 10 Igbo benchmark pages (benchmark/letters/ig.json, Wikipedia, CC BY-SA 4.0) drawn clean and
phone-like as in letter_ocr_test.py, read with `eng`; each place where the page's ọ came back as
"9" gives one case: the word as printed, the word as read, and the words around it as read.
"""
from __future__ import annotations

import argparse
import difflib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path[:0] = [str(HERE.parents[1]), str(HERE.parent), str(HERE.parents[1] / "tests")]
import bank_benchmark as bb  # noqa: E402
from letter_ocr_test import PAGES, draw, flat  # noqa: E402
from app.reader import TesseractEngine  # noqa: E402


def cases(model: str = "eng") -> list[dict]:
    out = []
    engine = TesseractEngine(lang=model)
    for n, page in enumerate(json.load(open(PAGES / "ig.json"))):
        src = flat(page["text"])
        for kind in ("clean", "photo"):
            img = draw(page["text"])
            img = bb.photo_like(img) if kind == "photo" else img
            got = flat(" ".join(l.text for l in engine.read(img).lines))
            sm = difflib.SequenceMatcher(None, src, got, autojunk=False)
            for op, a0, a1, b0, b1 in sm.get_opcodes():
                if op != "replace":
                    continue
                for k in range(min(a1 - a0, b1 - b0)):
                    if src[a0 + k] in "ọỌ" and got[b0 + k] == "9":
                        # The whole word around it, as read and as printed, and its neighbours as read.
                        bs, be = got.rfind(" ", 0, b0 + k) + 1, got.find(" ", b0 + k)
                        as_, ae = src.rfind(" ", 0, a0 + k) + 1, src.find(" ", a0 + k)
                        words = got.split(" ")
                        w = got[:bs].count(" ")
                        out.append({"page": n + 1, "kind": kind, "printed": src[as_:ae if ae >= 0 else None],
                                    "read": got[bs:be if be >= 0 else None],
                                    "context": " ".join(words[max(0, w - 3):w + 4])})
    return out


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--out")
    p.add_argument("--model", default="eng", help="Latin: the model Igbo pages are read again with")
    a = p.parse_args()
    found = cases(a.model)
    for c in found:
        print(c["kind"], c["page"], c["printed"], "→", c["read"])
    print(len(found), "cases;", sum(c["kind"] == "clean" for c in found), "clean")
    if a.out:
        Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        json.dump(found, open(a.out, "w"), ensure_ascii=False, indent=1)
