"""What OCR does to Hausa, Yorùbá and Igbo letters (docs/FINDINGS.md, board 5d).

    cd backend
    .venv/bin/python scripts/letter_ocr_test.py --tessdata DIR [--langs eng,Latin,yor]

Pages: benchmark/letters/{ha,yo,ig}.json, 10 Wikipedia extracts per language (CC BY-SA 4.0,
credited in docs/DATA_SOURCES.md), drawn at about 300 dpi in DejaVu Sans (which has every
letter), clean and made phone-like. For each special letter: kept, replaced (by what) or
dropped; for Yorùbá and Igbo tone marks (grave, acute, macron): kept or lost. Alignment is
difflib on the whole page text, so a letter counts as kept only where OCR wrote the same
letter in the same place.
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import sys
import textwrap
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve()
sys.path[:0] = [str(HERE.parents[1]), str(HERE.parent), str(HERE.parents[1] / "tests")]
import bank_benchmark as bb  # noqa: E402
import pagefont  # noqa: E402
from app.reader import TesseractEngine  # noqa: E402

PAGES = HERE.parents[2] / "benchmark" / "letters"
SPECIAL = {"ha": "ɓɗƙƴƁƊƘƳ", "yo": "ẹọṣẸỌṢ", "ig": "ịọụṅỊỌỤṄ"}
TONES = {"̀": "grave", "́": "acute", "̄": "macron"}


def draw(text: str) -> Image.Image:
    lines = [w for para in text.splitlines() for w in (textwrap.wrap(para, 60) or [""])]
    img = Image.new("RGB", (2480, 200 + 66 * len(lines)), "white")
    d, f = ImageDraw.Draw(img), pagefont.font(40)
    for i, line in enumerate(lines):
        d.text((100, 100 + i * 66), line, fill="black", font=f)
    return img


def flat(text: str) -> str:
    return " ".join(unicodedata.normalize("NFC", text).split())


def letters(src: str, got: str, special: str) -> tuple[Counter, dict]:
    """Per special letter: kept / replaced / dropped, and what replaced it."""
    out, became = Counter(), defaultdict(Counter)
    sm = difflib.SequenceMatcher(None, src, got, autojunk=False)
    for op, a0, a1, b0, b1 in sm.get_opcodes():
        for k, i in enumerate(range(a0, a1)):
            ch = src[i]
            if ch not in special:
                continue
            if op == "equal":
                out[(ch, "kept")] += 1
            elif op == "replace" and b0 + k < b1:
                out[(ch, "replaced")] += 1
                became[ch][got[b0 + k]] += 1
            else:
                out[(ch, "dropped")] += 1
    return out, became


def tones(src: str, got: str) -> Counter:
    """Tone marks kept or lost, on the decomposed text."""
    a, b = unicodedata.normalize("NFD", src), unicodedata.normalize("NFD", got)
    out = Counter()
    for op, a0, a1, b0, b1 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        for i in range(a0, a1):
            if a[i] in TONES:
                out["kept" if op == "equal" else "lost"] += 1
    return out


def cer(src: str, got: str) -> float:
    sm = difflib.SequenceMatcher(None, src, got, autojunk=False)
    same = sum(b.size for b in sm.get_matching_blocks())
    return 1 - same / max(len(src), 1)


def pipeline() -> None:
    """Magana's letter check end to end: the first (eng) reading decides the page language,
    the page is read again with READ_AGAIN's model, then words are marked. Scores: of the words
    that really lost a special letter, how many are marked; how many marked words were right.
    The 10 English benchmark pages must not be taken for Hausa, Yorùbá or Igbo."""
    from app import letters as L
    from app.reader import TesseractEngine as T
    for path in sorted((HERE.parents[2] / "benchmark" / "explain" / "pages").glob("*.txt")):
        text = " ".join(l.text for l in T().read(draw(path.read_text())).lines)
        print(f"en {path.stem}: detected {L.page_language(text)}")
    for lang in ("ha", "yo", "ig"):
        for kind in ("clean", "photo"):
            detected, lost, marked_lost, marked, marked_ok, words = Counter(), 0, 0, 0, 0, 0
            for page in json.load(open(PAGES / f"{lang}.json")):
                img = draw(page["text"])
                img = bb.photo_like(img) if kind == "photo" else img
                first = T().read(img)
                found = L.page_language(" ".join(l.text for l in first.lines))
                detected[found] += 1
                model = L.READ_AGAIN.get(found or "")
                lines = (T(lang=model).read(img) if model else first).lines
                got = [w.text for l in lines for w in l.words]
                src = flat(page["text"]).split()
                sm = difflib.SequenceMatcher(None, [L.plain(w) for w in src], [L.plain(w) for w in got], autojunk=False)
                for blk in sm.get_matching_blocks():
                    for k in range(blk.size):
                        s, g = src[blk.a + k], got[blk.b + k]
                        words += 1
                        wrong = L.untoned(L._WORD.search(s).group() if L._WORD.search(s) else s) != \
                            L.untoned(L._WORD.search(g).group() if L._WORD.search(g) else g)
                        m = L.may_miss_letter(g, lang)
                        lost += wrong
                        marked_lost += wrong and m
                        marked += m
                        marked_ok += m and not wrong
            print(f"{lang} {kind:5} detected {dict(detected)}  words {words}  lost a letter {lost}, marked {marked_lost} "
                  f"({100 * marked_lost / max(lost, 1):.0f}%)  marked but right {marked_ok} of {marked} marks", flush=True)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--tessdata", required=True)
    p.add_argument("--langs", default="eng,Latin,yor")
    p.add_argument("--out")
    p.add_argument("--pipeline", action="store_true", help="the letter check end to end")
    a = p.parse_args()
    os.environ["TESSDATA_PREFIX"] = a.tessdata
    if a.pipeline:
        return pipeline()
    rows = []
    for lang in ("ha", "yo", "ig"):
        pages = json.load(open(PAGES / f"{lang}.json"))
        for model in a.langs.split(","):
            if model == "yor" and lang != "yo":
                continue
            engine = TesseractEngine(lang=model)
            for kind in ("clean", "photo"):
                total, became, tone, errs = Counter(), defaultdict(Counter), Counter(), []
                for page in pages:
                    img = draw(page["text"])
                    if kind == "photo":
                        img = bb.photo_like(img)
                    got = flat(" ".join(l.text for l in engine.read(img).lines))
                    src = flat(page["text"])
                    c, b = letters(src, got, SPECIAL[lang])
                    total += c
                    for ch, cnt in b.items():
                        became[ch] += cnt
                    tone += tones(src, got)
                    errs.append(cer(src, got))
                per = {}
                for ch in SPECIAL[lang]:
                    n = sum(total[(ch, k)] for k in ("kept", "replaced", "dropped"))
                    if n:
                        per[ch] = {"n": n, "kept": total[(ch, "kept")], "replaced": total[(ch, "replaced")],
                                   "dropped": total[(ch, "dropped")], "became": dict(became[ch].most_common(3))}
                row = {"lang": lang, "model": model, "kind": kind, "pages": len(pages),
                       "cer": round(sum(errs) / len(errs), 3), "letters": per, "tones": dict(tone)}
                rows.append(row)
                kept = sum(v["kept"] for v in per.values())
                n = sum(v["n"] for v in per.values())
                print(f"{lang} {model:5} {kind:5} CER {row['cer']:.3f}  special letters kept {kept}/{n}"
                      + (f"  tone marks kept {tone['kept']}/{tone['kept'] + tone['lost']}" if tone else ""), flush=True)
    if a.out:
        json.dump(rows, open(a.out, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
