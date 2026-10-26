"""Private handwriting benchmark: what Magana makes of real handwritten pages.

    cd backend && .venv/bin/python scripts/handwriting_benchmark.py ~/magana-private-pages/handwriting

Each photo (jpg, jpeg, png) may have a transcript beside it with the same name and .txt,
typed by the team. The pages stay on this computer: nothing is written, sent or uploaded,
and OCR is local Tesseract (MAGANA_HANDWRITING is ignored). Totals only are printed: no
text from the pages. Expected label from the file name: "printed_", "hand_" or "mixed_"
prefixes, so the printed/handwritten/mixed decision can be scored.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import main  # noqa: E402
from app.reader import TesseractEngine, read_page  # noqa: E402

NUM = re.compile(r"\d[\d.,:/-]*")


def words(t: str) -> list[str]:
    return re.findall(r"[\w.,:/-]+", t.lower())


def main_(folder: str) -> None:
    eng = TesseractEngine()
    out = Counter()
    for path in sorted(Path(folder).expanduser().iterdir()):
        if path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
            continue
        out["pages"] += 1
        try:
            img = Image.open(path)
            img.load()
        except Exception:
            out["unreadable_file"] += 1
            continue
        for mode in ("school", "health"):
            body = main.checked(read_page(img, eng, second_pass=mode == "health"), mode)
            if mode == "school":
                out[f"script:{body['script']}"] += 1
                expected = path.name.split("_")[0].lower()
                if expected in {"printed", "hand", "mixed"}:
                    want = "handwritten" if expected == "hand" else expected
                    out["script_right" if body["script"] == want else "script_wrong"] += 1
                said = " ".join(l["text"] for l in body["lines"])
                truth_file = path.with_suffix(".txt")
                if truth_file.exists():
                    truth = truth_file.read_text(encoding="utf-8")
                    tw, sw = Counter(words(truth)), Counter(words(said))
                    out["words_true"] += sum(tw.values())
                    out["words_found"] += sum((tw & sw).values())
                    flagged = {(w["block_index"], w.get("word_index")) for w in body["warnings"]}
                    for i, l in enumerate(body["lines"]):
                        for j, w in enumerate(l["words"]):
                            if NUM.search(w["text"]):
                                ok = w["text"] in truth
                                warned = (i, j) in flagged or (i, None) in flagged
                                out[f"numbers:{'right' if ok else 'wrong'}_{'flagged' if warned else 'not_flagged'}"] += 1
            else:
                out["health:prescription_message"] += "handwritten_prescription" in body["tips"]
    print(json.dumps(dict(sorted(out.items())), indent=1))


if __name__ == "__main__":
    try:
        main_(sys.argv[1])
    except Exception as e:  # never print a message that could quote a page
        print(json.dumps({"error": type(e).__name__}))
