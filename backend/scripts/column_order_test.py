"""Reading order on two-column pages, before and after layout.arrange (board 5c).

    cd backend
    .venv/bin/python scripts/column_order_test.py [--photos DIR]

Pages: benchmark/columns/pages.json (10 team-written two-column pages), drawn at about 300 dpi,
clean and made phone-like (bank_benchmark.photo_like). "Before" is the same reading with the
layout step switched off, which is what read_page did until now.

Scores, per page and in total:
- in order: the share of the page's words read in the right order (the longest common
  subsequence of the true word order and the order Magana reads them in);
- mixed lines: lines that join words from both columns (read across the gutter);
- headings: the title and the two column headings found, and lines wrongly called headings.
Also: the 10 one-column pages in benchmark/explain/pages must be read in exactly the same
order with the layout step as without it.

--photos DIR: real photos, each with a .txt of the same name holding the page's text in the
right reading order (one printed line per line). Only "in order" is scored for them.
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve()
sys.path[:0] = [str(HERE.parents[1]), str(HERE.parent), str(HERE.parents[1] / "tests")]
import bank_benchmark as bb  # noqa: E402
import ocr_compare as oc  # noqa: E402
import pagefont  # noqa: E402
from app import layout  # noqa: E402
from app.reader import TesseractEngine, read_page  # noqa: E402

PAGES = HERE.parents[2] / "benchmark" / "columns" / "pages.json"
WIDTH, MARGIN, GUTTER, SIZE, STEP = 2480, 150, 140, 40, 62
WORD = re.compile(r"[\w'’-]+")


def draw(page: dict) -> tuple[Image.Image, list[str], list[str]]:
    """The page, its lines in true reading order, and its headings."""
    col_w = (WIDTH - 2 * MARGIN - GUTTER) // 2
    body, head, title = pagefont.font(SIZE), pagefont.font(SIZE + 6), pagefont.font(SIZE + 24)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    chars = max(10, int(col_w / probe.textlength("abcdefghij klmnopqrs", font=body) * 20))

    columns = []
    for side in ("left", "right"):
        lines = [(page[side]["heading"], head, True)] + [(l, body, False) for l in textwrap.wrap(page[side]["text"], chars)]
        columns.append(lines)
    height = 2 * MARGIN + 140 + STEP * max(len(c) for c in columns) + 40
    img = Image.new("RGB", (WIDTH, height), "white")
    d = ImageDraw.Draw(img)
    tw = d.textlength(page["title"], font=title)
    d.text(((WIDTH - tw) / 2, MARGIN), page["title"], fill="black", font=title, stroke_width=1, stroke_fill="black")
    order = [page["title"]]
    for c, lines in enumerate(columns):
        x = MARGIN + c * (col_w + GUTTER)
        for i, (text, font, bold) in enumerate(lines):
            d.text((x, MARGIN + 140 + i * STEP), text, fill="black", font=font,
                   stroke_width=1 if bold else 0, stroke_fill="black")
            order.append(text)
    return img, order, [page["title"], page["left"]["heading"], page["right"]["heading"]]


def words(text: str) -> list[str]:
    return [w.lower() for w in WORD.findall(text)]


def in_order(truth: list[str], lines: list[dict]) -> float:
    a = [w for t in truth for w in words(t)]
    b = [w for l in lines for w in words(l["text"])]
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    return sum(blk.size for blk in sm.get_matching_blocks()) / max(len(a), 1)


def mixed(page: dict, lines: list[dict]) -> int:
    left, right = set(words(page["left"]["text"])), set(words(page["right"]["text"]))
    only_left, only_right = left - right, right - left
    return sum(1 for l in lines if set(words(l["text"])) & only_left and set(words(l["text"])) & only_right)


def read(img: Image.Image, with_layout: bool) -> dict:
    if with_layout:
        return read_page(img, TesseractEngine())
    original = layout.arrange
    layout.arrange = lambda page, image=None: 1  # the old order: lines by their top edge
    try:
        return read_page(img, TesseractEngine())
    finally:
        layout.arrange = original


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--photos")
    a = p.parse_args()
    totals = {}
    for kind in ("clean", "photo"):
        for when in ("before", "after"):
            score, mix, found, extra, pages = 0.0, 0, 0, 0, 0
            for page in json.load(open(PAGES)):
                img, truth, heads = draw(page)
                img = bb.photo_like(img) if kind == "photo" else img
                r = read(img, when == "after")
                lines = r["lines"]
                s = in_order(truth, lines)
                score += s
                mix += mixed(page, lines)
                pages += 1
                if when == "after":
                    marked = [l["text"] for l in lines if l.get("heading")]
                    hit = sum(any(words(h) == words(m) for m in marked) for h in heads)
                    found += hit
                    extra += len(marked) - hit
                print(f"{kind} {when:6} page {page['id']}: in order {s:.0%}  columns {r.get('columns', 1)}  "
                      f"mixed lines {mixed(page, lines)}", flush=True)
            totals[(kind, when)] = (score / pages, mix, found, extra)
    print()
    for (kind, when), (s, mix, found, extra) in totals.items():
        print(f"{kind:5} {when:6}: words in order {s:.1%}, lines mixing both columns {mix}"
              + (f", headings found {found}/30, wrong headings {extra}" if when == "after" else ""))

    # One-column pages: exactly the same order with the layout step as without it.
    same = 0
    for path in sorted((HERE.parents[2] / "benchmark" / "explain" / "pages").glob("*.txt")):
        img, _ = oc.draw(path.read_text())
        a_lines = [l["text"] for l in read(img, False)["lines"]]
        b = read(img, True)
        same += a_lines == [l["text"] for l in b["lines"]] and b["columns"] == 1
    print(f"one-column pages read in the same order: {same}/10")

    if a.photos:
        for photo in sorted(Path(a.photos).iterdir()):
            truth_file = photo.with_suffix(".txt")
            if photo.suffix.lower() not in {".jpg", ".jpeg", ".png"} or not truth_file.exists():
                continue
            truth = [l for l in truth_file.read_text().splitlines() if l.strip()]
            img = Image.open(photo).convert("RGB")
            before, after = read(img, False), read(img, True)
            print(f"{photo.name}: in order {in_order(truth, before['lines']):.0%} -> {in_order(truth, after['lines']):.0%}"
                  f"  columns {after['columns']}")


if __name__ == "__main__":
    main()
