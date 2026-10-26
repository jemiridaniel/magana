"""Columns and headings (board 5c; docs/FINDINGS.md, 26 Oct 2026).

Both OCR engines put lines in order by their top edge, and Tesseract even joins a left and a
right column into one line when they share a baseline: a two-column textbook page was read
across both columns ("LEFT one: plants need light. RIGHT one: the heart pumps."). arrange():
- finds a vertical gutter that (nearly) no word crosses, from the words' boxes;
- splits lines at the gutter, then reads column 1 top to bottom, then column 2. A line that
  runs across the gutter (a title) stays whole and stays in its place;
- accepts the columns only when each one reads like paragraphs (several words a line, a fair
  width), so a table or statement, whose columns are one or two words wide, is unchanged;
- marks headings: noticeably taller text, or a short bold line, with text after it. Bold is
  told by stroke width (ink per horizontal run), which a blurred photo keeps far better than
  ink density (measured on the 10 test pages: headings 1.3 to 2.0 times body text, body lines
  at most 1.2).
A single-column page keeps exactly the order it had.
"""
from __future__ import annotations

import statistics
from dataclasses import dataclass

from PIL import Image

from .reader import INK_DELTA, Line, Page, Word, ink_map

MIN_LINES = 6  # fewer lines than this: never split into columns
GUTTER_WORD_HEIGHTS = 1.5  # a gutter is at least this many word heights wide...
GUTTER_SHARE = 0.02  # ...and this share of the text's width
CROSSING = 0.08  # lines (titles) allowed to cross a gutter, as a share of the page's lines
EDGE = 0.2  # a gutter lies between 20% and 80% of the text's width
COLUMN_MIN_LINES = 3
COLUMN_MIN_WORDS = 2.5  # mean words a line in every column: paragraphs, not table cells
COLUMN_MIN_WIDTH = 0.2  # every column at least this share of the text's width
TALL = 1.3  # a heading's text is this much taller than body text...
BOLD = 1.25  # ...or its strokes this much wider (bold)
HEADING_MAX_WORDS = 10


@dataclass
class _Part:
    line: Line
    column: int  # 0: crosses the gutter (full width); 1, 2, ...: its column


def _boxed(line: Line) -> list[Word]:
    return [w for w in line.words if w.width and w.height]


def _sub_line(line: Line, words: list[Word]) -> Line:
    """The part of [line] holding [words] (a line split at the gutter)."""
    left = min(w.left for w in words)
    right = max(w.left + w.width for w in words)
    top = min(w.top for w in words)
    return Line(" ".join(w.text for w in words), round(sum(w.confidence for w in words) / len(words), 3), top,
                height=max(w.top + w.height for w in words) - top, words=words, left=left, width=right - left,
                script=line.script, reader=line.reader)


def _gutters(lines: list[Line], height: float) -> list[tuple[int, int]]:
    """x ranges that (nearly) no line's words cover, wide enough and away from the edges."""
    import numpy as np

    boxed = [_boxed(l) for l in lines]
    x0 = min(w.left for ws in boxed for w in ws)
    x1 = max(w.left + w.width for ws in boxed for w in ws)
    width = x1 - x0
    cover = np.zeros(width + 1, dtype=int)
    for ws in boxed:
        seen = np.zeros(width + 1, dtype=bool)
        for w in ws:
            seen[w.left - x0: w.left + w.width - x0] = True
        cover += seen
    allowed = max(1, round(CROSSING * len(lines)))
    free = cover <= allowed
    min_width = max(GUTTER_WORD_HEIGHTS * height, GUTTER_SHARE * width)
    out, start = [], None
    for x, on in enumerate(list(free) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start >= min_width and EDGE * width <= (start + x) / 2 <= (1 - EDGE) * width:
                out.append((start + x0, x + x0))
            start = None
    return out


def _split(lines: list[Line], gutters: list[tuple[int, int]]) -> list[_Part]:
    """Each line's words by column; a line whose words bridge a gutter stays whole."""
    def column(w: Word) -> int:
        middle = w.left + w.width / 2
        return 1 + sum(middle >= g1 for _, g1 in gutters)

    parts = []
    for line in lines:
        words = _boxed(line)
        if not words:
            parts.append(_Part(line, 0))
            continue
        crossing = any(w.left < g1 and w.left + w.width > g0 for w in words for g0, g1 in gutters)
        groups: dict[int, list[Word]] = {}
        for w in words:
            groups.setdefault(column(w), []).append(w)
        if crossing:
            parts.append(_Part(line, 0))
        elif len(groups) == 1:
            parts.append(_Part(line, next(iter(groups))))
        else:
            # Words on both sides: two columns' lines, unless the gap is an ordinary space.
            cols = sorted(groups)
            gaps = [min(w.left for w in groups[b]) - max(w.left + w.width for w in groups[a]) for a, b in zip(cols, cols[1:])]
            narrowest = min(g1 - g0 for g0, g1 in gutters)
            if min(gaps) < 0.8 * narrowest:
                parts.append(_Part(line, 0))
            else:
                parts.extend(_Part(_sub_line(line, groups[c]), c) for c in cols)
    return parts


def _columns_ok(parts: list[_Part], count: int, text_width: int) -> bool:
    for c in range(1, count + 1):
        mine = [p.line for p in parts if p.column == c]
        if len(mine) < COLUMN_MIN_LINES:
            return False
        if statistics.mean(len(l.text.split()) for l in mine) < COLUMN_MIN_WORDS:
            return False
        left = min(l.left for l in mine)
        right = max(l.left + l.width for l in mine)
        if right - left < COLUMN_MIN_WIDTH * text_width:
            return False
    return True


def _reading_order(parts: list[_Part], count: int) -> list[_Part]:
    """Full-width lines in place; between them, column 1 top to bottom, then column 2..."""
    spans = sorted((p for p in parts if p.column == 0), key=lambda p: p.line.top)
    out, done = [], set()
    bounds = [p.line.top for p in spans] + [float("inf")]
    previous = float("-inf")
    for i, bound in enumerate(bounds):
        for c in range(1, count + 1):
            section = [p for p in parts if p.column == c and previous <= p.line.top < bound and id(p) not in done]
            for p in sorted(section, key=lambda p: (p.line.top, p.line.left)):
                out.append(p)
                done.add(id(p))
        if i < len(spans):
            out.append(spans[i])
            done.add(id(spans[i]))
        previous = bound
    return out


def _stroke_width(ink, line: Line) -> float:
    """Mean width of the line's strokes: inked pixels per horizontal run of ink."""
    import numpy as np

    inked = runs = 0
    for w in _boxed(line):
        a = ink[w.top: w.top + w.height, w.left: w.left + w.width] > INK_DELTA
        if a.size:
            inked += int(a.sum())
            runs += int((np.diff(a.astype(np.int8), axis=1) == 1).sum() + a[:, 0].sum())
    return inked / runs if runs else 0.0


def mark_headings(page: Page, image: Image.Image | None = None) -> None:
    """Headings: taller than body text, or short and bold, with text after them."""
    import numpy as np

    lines = page.lines
    body = [l for l in lines if len(l.text.split()) >= 4 and l.height]
    if len(body) < 2:
        return
    body_height = statistics.median(l.height for l in body)
    ink = np.asarray(ink_map(image)) if image is not None else None
    body_stroke = statistics.median(_stroke_width(ink, l) for l in body) if ink is not None else 0
    for i, line in enumerate(lines):
        words = line.text.split()
        if not words or len(words) > HEADING_MAX_WORDS or i == len(lines) - 1:
            continue
        if line.text.rstrip()[-1] in ".,;:" or not any(ch.isalpha() for ch in line.text):
            continue
        tall = line.height >= TALL * body_height
        bold = ink is not None and body_stroke > 0 and _stroke_width(ink, line) >= BOLD * body_stroke
        line.heading = tall or bold


def arrange(page: Page, image: Image.Image | None = None) -> int:
    """Reading order by columns (1 when the page has none), and headings. Returns the
    number of columns; sets each line's column (0 = across the page) and heading."""
    lines = [l for l in page.lines if _boxed(l)]
    count = 1
    if len(lines) >= MIN_LINES:
        height = statistics.median(w.height for l in lines for w in _boxed(l))
        gutters = _gutters(lines, height)
        if gutters:
            parts = _split(page.lines, gutters)
            text_width = max(w.left + w.width for l in lines for w in _boxed(l)) - min(w.left for l in lines for w in _boxed(l))
            if _columns_ok(parts, len(gutters) + 1, text_width):
                count = len(gutters) + 1
                ordered = _reading_order(parts, count)
                page.lines = [p.line for p in ordered]
                for p in ordered:
                    p.line.column = p.column
    for i, line in enumerate(page.lines):
        line.label = f"line {i + 1}"
        if count == 1:
            line.column = 1
    mark_headings(page, image)
    return count
