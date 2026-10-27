"""Page reading: OCR into lines with confidence, ready to be spoken.

The OCR engine sits behind a small interface so the team can swap the dev engine
(Tesseract, runs anywhere) for the production engine (PaddleOCR PP-Structure for
layout and tables) without touching the API or safety layer.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, asdict, field
from html.parser import HTMLParser
from typing import Any, Callable, Protocol

from PIL import Image, ImageChops, ImageFilter, ImageOps, ImageStat


@dataclass
class Word:
    text: str
    confidence: float  # 0-1
    # Box on the page in pixels; width 0 when the engine gives no word boxes (PaddleOCR).
    left: int = 0
    top: int = 0
    width: int = 0
    height: int = 0
    # Numbers only: an independent second reading of a crop around this word.
    reread_text: str | None = None
    reread_confidence: float | None = None


@dataclass
class Line:
    text: str
    confidence: float  # 0-1
    top: int
    label: str = ""
    height: int = 0
    # Per-word confidence, so one shaky number is not hidden by confident words around it.
    words: list[Word] = field(default_factory=list)
    left: int = 0
    width: int = 0  # horizontal extent of the recognised text; 0 if unknown
    # Ink carries on past the last recognised word: the end of this line was not read.
    end_unclear: bool = False
    # Text-sized ink inside this row that no recognised word covers (a dropped "7.50").
    part_unclear: bool = False
    # "handwritten" or "printed" (handwriting.classify); which engine read a handwritten line.
    script: str = ""
    reader: str = ""
    # Layout (layout.arrange): 1, 2, ... the column it is in, 0 when it runs across the
    # columns (a title); and whether it is a heading.
    column: int = 1
    heading: bool = False


@dataclass
class Cell:
    text: str
    confidence: float  # 0-1
    row: int  # 0-based
    col: int  # 0-based, after expanding spans to the left
    rowspan: int = 1
    colspan: int = 1


@dataclass
class Table:
    """A table read row by row. rows[0] is the header when header is True."""
    rows: list[list[Cell]]
    top: int
    label: str = ""
    header: bool = False
    confidence: float = 1.0  # whole-table structure score
    height: int = 0


@dataclass
class Page:
    lines: list[Line] = field(default_factory=list)
    tables: list[Table] = field(default_factory=list)


class OCREngine(Protocol):
    def read(self, image: Image.Image) -> Page: ...


class TesseractEngine:
    """Dev/offline-fallback engine. Groups Tesseract words into lines."""

    def __init__(self, lang: str = "eng", psm: int | None = None):
        self.lang = lang
        self.psm = psm  # Tesseract page segmentation mode; 7 = a single line of text

    def snippet_engine(self) -> "TesseractEngine":
        """The same engine set up for a small crop holding one word or line."""
        return TesseractEngine(self.lang, psm=7)

    def read(self, image: Image.Image) -> Page:
        import pytesseract

        config = f"--psm {self.psm}" if self.psm else ""
        data = pytesseract.image_to_data(image, lang=self.lang, config=config, output_type=pytesseract.Output.DICT)
        lines: dict[tuple, dict] = {}
        for i, word in enumerate(data["text"]):
            if not word.strip():
                continue
            key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
            entry = lines.setdefault(key, {"words": [], "confs": [], "boxes": [], "top": data["top"][i], "bottom": 0})
            entry["words"].append(word)
            entry["confs"].append(max(float(data["conf"][i]), 0.0) / 100)
            entry["boxes"].append((data["left"][i], data["top"][i], data["width"][i], data["height"][i]))
            entry["bottom"] = max(entry["bottom"], data["top"][i] + data["height"][i])
        out = []
        for n, (_, e) in enumerate(sorted(lines.items(), key=lambda kv: kv[1]["top"])):
            conf = sum(e["confs"]) / len(e["confs"])
            words = [Word(w, round(c, 3), *box) for w, c, box in zip(e["words"], e["confs"], e["boxes"])]
            left = min(b[0] for b in e["boxes"])
            right = max(b[0] + b[2] for b in e["boxes"])
            out.append(Line(" ".join(e["words"]), round(conf, 3), e["top"], label=f"line {n + 1}",
                            height=e["bottom"] - e["top"], words=words, left=left, width=right - left))
        return Page(lines=out)


class _TableHTML(HTMLParser):
    """Collects <tr>/<td>/<th> into rows of (text, rowspan, colspan, is_header)."""

    def __init__(self):
        super().__init__()
        self.rows: list[list[tuple[str, int, int, bool]]] = []
        self._cell: list[str] | None = None
        self._span = (1, 1, False)

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.rows.append([])
        elif tag in ("td", "th"):
            if not self.rows:
                self.rows.append([])
            a = dict(attrs)
            self._cell = []
            self._span = (_int(a.get("rowspan")), _int(a.get("colspan")), tag == "th")

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self._cell is not None:
            text = " ".join("".join(self._cell).split())
            self.rows[-1].append((text, *self._span))
            self._cell = None

    def handle_data(self, data):
        if self._cell is not None:
            self._cell.append(data)


def _int(v) -> int:
    try:
        return max(int(v), 1)
    except (TypeError, ValueError):
        return 1


def parse_table_html(html: str, confidence: float = 1.0) -> tuple[list[list[Cell]], bool]:
    """Turn table HTML into rows of cells, placing spanned cells on a grid.

    A cell spanning rows appears once, in the row where it starts; later rows skip
    its columns so every cell keeps its true column number.
    """
    p = _TableHTML()
    p.feed(html)
    taken: set[tuple[int, int]] = set()
    rows: list[list[Cell]] = []
    for r, raw in enumerate(p.rows):
        row, c = [], 0
        for text, rowspan, colspan, _ in raw:
            while (r, c) in taken:
                c += 1
            row.append(Cell(text, confidence, r, c, rowspan, colspan))
            for dr in range(rowspan):
                for dc in range(colspan):
                    taken.add((r + dr, c + dc))
            c += colspan
        if row:
            rows.append(row)
    if p.rows and p.rows[0] and all(h for *_, h in p.rows[0]):
        header = True
    else:
        # PP-StructureV3 never emits <th>: treat a first row of words over rows with
        # numbers as the header, so "Result: 11.2 g/dL" can be read row by row.
        has_digit = lambda row: any(ch.isdigit() for c in row for ch in c.text)
        header = len(rows) > 1 and not has_digit(rows[0]) and any(has_digit(r) for r in rows[1:])
    return rows, header


def _top(box) -> int:
    """Top y of a [x1, y1, x2, y2] box or a list of [x, y] points."""
    if box is None or len(box) == 0:
        return 0
    first = box[0]
    if isinstance(first, (list, tuple)) or hasattr(first, "__len__"):
        return int(min(pt[1] for pt in box))
    return int(box[1])


def _boxes_overlap(a, b) -> float:
    """Fraction of box b's area that lies inside box a ([x1, y1, x2, y2])."""
    ix = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    area = max((b[2] - b[0]) * (b[3] - b[1]), 1e-6)
    return ix * iy / area


class PaddleStructureEngine:
    """Production engine: PaddleOCR PP-StructureV3 for layout and tables.

    `pipeline` is anything with predict(ndarray) -> results whose .json (or the dict
    itself) has PP-StructureV3's "res" layout; tests inject a fake so they never
    need paddle installed.
    """

    def __init__(self, lang: str = "en", pipeline: Any = None, factory: Callable[[], Any] | None = None):
        self.lang = lang
        self._pipeline = pipeline
        self._factory = factory

    @property
    def pipeline(self):
        if self._pipeline is None:
            if self._factory is not None:
                self._pipeline = self._factory()
            else:
                from paddleocr import PPStructureV3

                self._pipeline = PPStructureV3(
                    lang=self.lang,
                    use_doc_orientation_classify=False,
                    use_doc_unwarping=False,
                    use_seal_recognition=False,
                    use_formula_recognition=False,
                    use_chart_recognition=False,
                )
        return self._pipeline

    def read(self, image: Image.Image) -> Page:
        import numpy as np

        # Paddle expects BGR like OpenCV.
        arr = np.asarray(image.convert("RGB"))[:, :, ::-1].copy()
        results = list(self.pipeline.predict(arr))
        return page_from_structure(results[0] if results else {})


def page_from_structure(result: Any) -> Page:
    """Build a Page from one PP-StructureV3 result (object with .json, or a dict)."""
    data = getattr(result, "json", result) or {}
    data = data.get("res", data)
    ocr = data.get("overall_ocr_res") or {}
    texts = list(ocr.get("rec_texts") or [])
    scores = [float(s) for s in (ocr.get("rec_scores") or [])]
    boxes = [list(map(float, b)) for b in (ocr.get("rec_boxes") or [])]

    table_regions = [list(map(float, b["block_bbox"])) for b in data.get("parsing_res_list") or []
                     if b.get("block_label") == "table"]
    tables_raw = list(data.get("table_res_list") or [])

    tables = []
    for n, t in enumerate(tables_raw):
        tocr = t.get("table_ocr_pred") or {}
        tscores = [float(s) for s in (tocr.get("rec_scores") or [])]
        tboxes = [list(map(float, b)) for b in (tocr.get("rec_boxes") or [])]
        cells_xyxy = [_xyxy(b) for b in (t.get("cell_box_list") or [])]
        region = table_regions[n] if n < len(table_regions) else (_union(cells_xyxy) if cells_xyxy else None)
        overall = min(tscores) if tscores else 1.0
        rows, header = parse_table_html(t.get("pred_html", ""), confidence=round(overall, 3))
        flat = [c for row in rows for c in row]
        # When cell boxes line up one-to-one with HTML cells, give each cell the
        # lowest score among the words inside it, so one shaky value is flagged alone.
        if cells_xyxy and len(cells_xyxy) == len(flat) and tboxes:
            for cell, cbox in zip(flat, cells_xyxy):
                inside = [s for s, wb in zip(tscores, tboxes) if _boxes_overlap(cbox, wb) > 0.5]
                cell.confidence = round(min(inside), 3) if inside else (1.0 if not cell.text else cell.confidence)
        top = int(region[1]) if region else 0
        height = int(region[3] - region[1]) if region else 0
        tables.append(Table(rows, top, label=f"table {n + 1}", header=header, confidence=round(overall, 3), height=height))

    # Page lines: overall OCR text that is not inside a table (tables are read cell by cell).
    regions = table_regions or [_union([_xyxy(b) for b in t["cell_box_list"]])
                                for t in tables_raw if t.get("cell_box_list")]
    lines = []
    for text, score, box in zip(texts, scores, boxes):
        if not text.strip() or any(_boxes_overlap(r, box) > 0.5 for r in regions):
            continue
        # PP-OCR scores whole text lines, so each word carries its line's score, and
        # gets an approximate box so its numbers can be re-read from a crop.
        x1y1x2y2 = _xyxy(box)
        words = _split_line_box(text, round(score, 3), x1y1x2y2)
        lines.append(Line(text.strip(), round(score, 3), _top(box), height=int(x1y1x2y2[3] - x1y1x2y2[1]), words=words,
                          left=int(x1y1x2y2[0]), width=int(x1y1x2y2[2] - x1y1x2y2[0])))
    lines.sort(key=lambda l: l.top)
    for i, l in enumerate(lines):
        l.label = f"line {i + 1}"
    tables.sort(key=lambda t: t.top)
    return Page(lines=lines, tables=tables)


def _xyxy(box) -> list[float]:
    """Accept [x1, y1, x2, y2] or 8-number / 4-point polygons."""
    flat = [float(v) for pt in box for v in (pt if hasattr(pt, "__len__") else [pt])]
    if len(flat) == 4:
        return flat
    xs, ys = flat[0::2], flat[1::2]
    return [min(xs), min(ys), max(xs), max(ys)]


def _split_line_box(text: str, score: float, box: list[float]) -> list[Word]:
    """Approximate word boxes for an engine that only boxes whole lines (PP-OCR): the line
    box split in proportion to each word's characters, spaces included. The number re-read
    crops each number with its whole neighbouring words, so this is close enough."""
    x1, y1, x2, y2 = box
    chars = max(len(text), 1)
    per_char = (x2 - x1) / chars
    words, at = [], 0
    for w in text.split():
        start = text.index(w, at)
        at = start + len(w)
        words.append(Word(w, score, int(x1 + start * per_char), int(y1),
                          max(1, int(len(w) * per_char)), max(1, int(y2 - y1))))
    return words


def _union(boxes: list[list[float]]) -> list[float]:
    return [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]


def default_engine() -> OCREngine:
    """MAGANA_OCR=paddle selects PP-StructureV3; anything else uses Tesseract."""
    if os.environ.get("MAGANA_OCR", "tesseract").lower() == "paddle":
        return PaddleStructureEngine(lang=os.environ.get("MAGANA_OCR_LANG", "en"))
    return TesseractEngine()


CUT_MARGIN = 0.004  # a word this close to the photo's edge (share of its size) runs off it


def cut_off(image: Image.Image, page: Page) -> list[str]:
    """'cut_off_top' ... 'cut_off_right': words touching the photo's edge, so part of the page
    is outside the photo (a gallery photo has no live framing to prevent it). Words of one
    character are left out: a speck or a ruled line's end is not text."""
    w, h = image.size
    mx, my = max(3, int(w * CUT_MARGIN)), max(3, int(h * CUT_MARGIN))
    sides = set()
    for line in page.lines:
        for word in line.words:
            if not (word.width and word.height) or len(word.text.strip()) < 2:
                continue
            if word.top <= my:
                sides.add("top")
            if word.top + word.height >= h - my:
                sides.add("bottom")
            if word.left <= mx:
                sides.add("left")
            if word.left + word.width >= w - mx:
                sides.add("right")
    return [f"cut_off_{s}" for s in ("top", "bottom", "left", "right") if s in sides]


def capture_check(image: Image.Image) -> list[str]:
    """Capture tips as message codes: too_dark, blurry."""
    tips = []
    gray = image.convert("L")
    if ImageStat.Stat(gray).mean[0] < 60:
        tips.append("too_dark")
    edges = gray.filter(ImageFilter.FIND_EDGES)
    if ImageStat.Stat(edges).var[0] < 50:
        tips.append("blurry")
    return tips


SMALL_PRINT_PX = 10  # median word height below this: too small to read every number


def _median_height(page: Page) -> float:
    heights = sorted(w.height for l in page.lines for w in l.words if w.height and len(w.text) >= 2)
    return heights[len(heights) // 2] if heights else 0.0


def small_print(page: Page) -> list[str]:
    """'small_print' from the OCR's first pass, before faint-print recovery: its words are
    tiny, or it read almost nothing. Sharp 14 px digits (a statement at 300 dpi) read well; a
    phone-like copy at half that size gave the first pass no words at all, and what recovery
    found lost 300 of 1,998 numbers with no other warning (docs/FINDINGS.md)."""
    heights = sorted(w.height for l in page.lines for w in l.words if w.height and len(w.text) >= 2)
    if len(heights) < 5:
        return ["read_little"]  # read_page keeps it only if faint recovery then found text
    return ["small_print"] if heights[len(heights) // 2] < SMALL_PRINT_PX else []


# ---------- Where the paper ends (torn slips, cards on a wall)

PAPER_DROP = 18  # grey levels below the paper's own level that count as off the paper
EDGE_GAP = 0.5   # first word this close to the paper's edge (in line heights): the edge cut it
EDGE_FRAGMENT_GAP = 1.6  # ...or this close with pieces of letters between (what the tear left)
EDGE_LINES = 0.4  # share of lines that must start (or end) at the edge
FRAGMENT_DARK = 30  # grey levels below the paper that count as ink in a fragment


def paper_span(gray, line: Line, x_from: int, x_to: int) -> tuple[int, int, bool, bool]:
    """(left, right, left_is_edge, right_is_edge): how far the paper runs either side of
    [x_from, x_to] on this line's band. The walk steps over short dark stretches (letters, a
    ruled line, pieces of torn letters) and stops after a line height of non-paper: that is a
    real edge, with background beyond. Reaching the photo's side is not an edge."""
    import numpy as np

    band = gray[line.top:line.top + line.height]
    med = np.median(band, axis=0)
    paper = np.percentile(med[x_from:x_to + 1], 90)
    ok = med >= paper - PAPER_DROP
    h, w = max(4, line.height), len(ok)

    def walk(x: int, step: int) -> tuple[int, bool]:
        last, run = x, 0
        while 0 <= x + step < w:
            x += step
            if ok[x]:
                last, run = x, 0
            else:
                run += 1
                if run >= h:
                    return last, True
        return last, False

    left, left_edge = walk(x_from, -1)
    right, right_edge = walk(x_to, 1)
    return left, right, left_edge, right_edge


def _fragment(gray, line: Line, x0: int, x1: int) -> bool:
    """Pieces of letters between x0 and x1 on this line (what a tear leaves of a word)."""
    import numpy as np

    if x1 - x0 < 2:
        return False
    region = gray[line.top:line.top + line.height, x0 + 1:x1]
    paper = np.percentile(region, 90)
    return int((region < paper - FRAGMENT_DARK).sum()) >= max(4, line.height // 2)


def _edges(gray, line: Line, first: Word, last: Word) -> dict:
    h = line.height
    pl, _, pl_edge, _ = paper_span(gray, line, first.left, first.left + first.width)
    _, pr, _, pr_edge = paper_span(gray, line, last.left, last.left + last.width)
    gap_l, gap_r = first.left - pl, pr - (last.left + last.width)
    cut_l = gap_l < EDGE_GAP * h or (gap_l < EDGE_FRAGMENT_GAP * h and _fragment(gray, line, pl, first.left))
    cut_r = gap_r < EDGE_GAP * h or (gap_r < EDGE_FRAGMENT_GAP * h and
                                     _fragment(gray, line, last.left + last.width, pr))
    return {"pl": pl, "pr": pr, "pl_edge": bool(pl_edge), "pr_edge": bool(pr_edge), "cut_l": bool(cut_l),
            "cut_r": bool(cut_r), "first": first.left, "last": last.left + last.width, "h": h}


def paper_bounds(gray, page: Page) -> dict[int, dict]:
    """Per line (by id): where its paper ends, and whether a tear or trim cut its words. An edge
    counts only when another line's edge on that side lies within a line height of it: a real
    paper edge is a straight boundary down the slip, while a smudge or a picture marks one line
    (a smudged line end must still be flagged)."""
    found = {}
    for line in page.lines:
        words = [w for w in line.words if w.width and w.height and len(w.text.strip()) >= 2]
        if words and line.height:
            found[id(line)] = _edges(gray, line, words[0], words[-1])
    for side in ("l", "r"):
        at = [e[f"p{side}"] for e in found.values() if e[f"p{side}_edge"]]
        for e in found.values():
            agree = sum(abs(x - e[f"p{side}"]) <= e["h"] for x in at) >= 2
            e[f"p{side}_edge"] = e[f"p{side}_edge"] and agree
            e[f"cut_{side}"] = e[f"cut_{side}"] and e[f"p{side}_edge"]
    return found


def on_paper(bounds: dict | None, line: Line, width: int) -> tuple[int, int]:
    """The columns of [line] that are its own paper: up to a confirmed edge, and not the cut
    letters before (or after) the words when the edge cut them. The whole row otherwise."""
    e = (bounds or {}).get(id(line))
    if e is None:
        return 0, width
    start = e["first"] if e["cut_l"] else (e["pl"] if e["pl_edge"] else 0)
    stop = e["last"] if e["cut_r"] else (e["pr"] + 1 if e["pr_edge"] else width)
    return start, max(start, stop)


def edge_cuts(image: Image.Image, page: Page, bounds: dict | None = None) -> list[str]:
    """'edge_cut_left' / 'edge_cut_right': lines run right up to the paper's own edge, as on a
    torn or trimmed slip: "Some words at the left edge are cut off." What is there is still read
    and never repaired. The photo's edge is cut_off's job."""
    import numpy as np

    if bounds is None:
        bounds = paper_bounds(np.asarray(image.convert("L"), dtype=float), page)
    n = len(bounds)
    need = max(2, EDGE_LINES * n)
    return [f"edge_cut_{side}" for side, key in (("left", "cut_l"), ("right", "cut_r"))
            if n and sum(e[key] for e in bounds.values()) >= need]


# ---------- Straightening a tilted photo

SKEW_MAX = 15.0   # degrees tried either way
SKEW_MIN = 1.5    # smaller tilts read fine as they are


def skew_angle(image: Image.Image) -> float:
    """The angle (degrees, counter-clockwise) that makes the text rows level: the turn whose
    row-by-row ink profile is sharpest, on a small copy. Tesseract reads a page tilted up to
    about 6° but nothing at 8° or more (docs/FINDINGS.md, 27 Oct 2026)."""
    import numpy as np

    small = image.convert("L")
    small.thumbnail((800, 800))
    arr = np.asarray(small, dtype=float)
    mask = arr < arr.mean() - 30
    if not mask.any():
        return 0.0  # nothing to level
    ink = Image.fromarray((mask * 255).astype("uint8"))

    def sharpness(angle: float) -> float:
        rows = np.asarray(ink.rotate(angle, resample=Image.NEAREST, expand=True), dtype=float).sum(axis=1)
        return float(np.var(rows))

    coarse = max((a for a in range(-int(SKEW_MAX), int(SKEW_MAX) + 1)), key=sharpness)
    fine = [coarse + d / 4 for d in range(-4, 5)]
    return max(fine, key=sharpness)


def straighten(image: Image.Image) -> tuple[Image.Image, float]:
    """The photo turned so its text is level (and the angle), or the photo as it is."""
    angle = skew_angle(image)
    if abs(angle) < SKEW_MIN:
        return image, 0.0
    fill = tuple(int(v) for v in ImageStat.Stat(image.convert("RGB")).median)
    return image.convert("RGB").rotate(angle, resample=Image.BICUBIC, expand=True, fillcolor=fill), angle


# ---------- Barcodes: not text

BAR_SHARE = 0.25  # of a "line"'s columns that are ink from top to bottom...
BAR_MIN = 12      # ...in at least this many separate bars: a barcode, not words


def is_barcode(gray, line: Line) -> bool:
    """A boarding pass's or a parcel's barcode, which the OCR reads as a line of junk words (on
    the tester's boarding pass, 27 Oct 2026, 27–65% of such a line's columns were full-height
    bars; letters, even capitals, leave space above or below most columns)."""
    import numpy as np

    crop = gray[line.top:line.top + line.height, line.left:line.left + line.width]
    if crop.size == 0 or line.height < 6:
        return False
    hi, lo = np.percentile(crop, 90), np.percentile(crop, 5)
    if hi - lo < 40:
        return False
    tall = (crop < hi - 0.5 * (hi - lo)).mean(axis=0) > 0.85
    bars = int(np.count_nonzero(tall[1:] & ~tall[:-1]) + (1 if tall.size and tall[0] else 0))
    return tall.mean() >= BAR_SHARE and bars >= BAR_MIN


def drop_barcodes(image: Image.Image, page: Page) -> int:
    """Leaves barcodes out of the reading (their junk could be read as numbers) and says how
    many there were: the page then says "I skipped a barcode"."""
    import numpy as np

    gray = np.asarray(image.convert("L"), dtype=float)
    kept = [l for l in page.lines if not is_barcode(gray, l)]
    dropped = len(page.lines) - len(kept)
    page.lines[:] = kept
    return dropped


# ---------- Thermal and faint print: flatten the paper, then stretch

def flatten_contrast(image: Image.Image) -> Image.Image:
    """Faint print (thermal slips, worn receipts): each pixel divided by the blurred paper around
    it, so uneven light goes and the paper turns even white, then stretched to full contrast. A
    plain stretch doesn't help when a dark table already uses the full range (measured: 0 words
    either way; flattened, 19 of the slip's words)."""
    import numpy as np

    gray = image.convert("L")
    background = np.asarray(gray.filter(ImageFilter.GaussianBlur(25)), dtype=float) + 1
    flat = np.clip(np.asarray(gray, dtype=float) / background * 235, 0, 255).astype("uint8")
    return ImageOps.autocontrast(Image.fromarray(flat), cutoff=1).convert("RGB")


FAINT_CONFIDENCE = 0.75  # a first reading this unsure (or nearly empty) is tried flattened too


def _words(page: Page) -> list[Word]:
    return [w for l in page.lines for w in l.words if len(w.text.strip()) >= 2]


def reads_faint(page: Page) -> bool:
    words = _words(page)
    return len(words) < 5 or sum(w.confidence for w in words) / len(words) < FAINT_CONFIDENCE


# ---------- Faint print

INK_DELTA = 10  # grey levels darker than the local paper that count as ink


def ink_map(image: Image.Image) -> Image.Image:
    """How much darker each pixel is than the paper around it, so shading and
    tinted paper don't count as ink but faint print does."""
    gray = image.convert("L")
    small = gray.resize((max(1, gray.width // 4), max(1, gray.height // 4)))
    paper = small.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(4)).resize(gray.size)
    return ImageChops.subtract(paper, gray)


def ink_bands(ink: Image.Image) -> list[tuple[int, int]]:
    """Horizontal bands (top, bottom) that hold text-like ink."""
    import numpy as np

    a = np.asarray(ink) > INK_DELTA
    h, w = a.shape
    rows = a.sum(axis=1) >= max(3, int(w * 0.002))
    bands, start, gap = [], None, 0
    for y, on in enumerate(list(rows) + [False] * 4):
        if on:
            start, gap = (y if start is None else start), 0
        elif start is not None:
            gap += 1
            if gap > 3:
                bands.append((start, y - gap + 1))
                start, gap = None, 0
    out = []
    for top, bottom in bands:
        height = bottom - top
        cover = a[top:bottom].mean() if height else 0
        # Text-sized and text-like: not a speck, not a dark edge or photo filling the band.
        if max(4, h * 0.004) <= height <= h * 0.25 and 0.002 <= cover <= 0.4:
            out.append((top, bottom))
    return out


def _covered(band: tuple[int, int], spans: list[tuple[int, int]]) -> bool:
    top, bottom = band
    return any(min(bottom, b) - max(top, t) >= 0.5 * (bottom - top) for t, b in spans)


def recover_faint(image: Image.Image, page: Page, engine: OCREngine) -> list[dict]:
    """Find ink the OCR skipped, contrast-boost each such band and read it again.
    Recovered lines join the page; bands that still give no text are returned as
    faint regions, so the user hears that something is there but unreadable."""
    ink = ink_map(image)
    spans = [(l.top, l.top + max(l.height, 1)) for l in page.lines]
    spans += [(t.top, t.top + t.height) for t in page.tables if t.height]
    faint = []
    for top, bottom in ink_bands(ink):
        if _covered((top, bottom), spans):
            continue
        pad = max(6, (bottom - top) // 2)
        y0, y1 = max(0, top - pad), min(image.height, bottom + pad)
        # Stretch contrast within the band only: one dark heading elsewhere on the
        # page no longer pushes the faint line below the OCR's threshold.
        crop = ImageOps.invert(ImageOps.autocontrast(ink.crop((0, y0, image.width, y1)), cutoff=1))
        found = [l for l in engine.read(crop).lines if l.text.strip()]
        for l in found:
            l.top += y0
            for w in l.words:
                w.top += y0
        # A tall band can hold lines already read (a sharp card's lines and border merge into
        # one band): only lines no existing line covers are new, or the card is read twice.
        new = [l for l in found if not _covered((l.top, l.top + max(l.height, 1)), spans)]
        if found and not new:
            continue
        found = new
        if found:
            page.lines.extend(found)
            spans += [(l.top, l.top + max(l.height, 1)) for l in found]
        else:
            middle = (top + bottom) / 2 / max(image.height, 1)
            where = "top" if middle < 1 / 3 else "middle" if middle < 2 / 3 else "bottom"
            faint.append({"code": "faint_region", "top": top, "bottom": bottom, "where": where})
    page.lines.sort(key=lambda l: l.top)
    for i, l in enumerate(page.lines):
        l.label = f"line {i + 1}"
    return faint


# ---------- Whole lines the OCR dropped

MISSED_EDGE = 3.0  # ink running down a column this many line heights is a border, not letters
MISSED_PIECES = 4  # separate pieces of ink in the row (letters, words), at least
MISSED_WIDTH = 3.0  # inked columns, in line heights, at least


def missed_lines(image: Image.Image, page: Page, faint: list[dict]) -> list[dict]:
    """Rows of text-like ink that no read line or word covers: a line Tesseract dropped without a
    trace ("in all things" on a script-font card, docs/FINDINGS.md). Said at its place as "I may
    have missed a line here". Only inside the text's own area, so a wall or a picture beside a
    card is not a line; borders and rules are left out; the row must be line-sized and made of
    several separate pieces of ink. Faint bands are faint_regions' job."""
    import numpy as np

    lines = [l for l in page.lines if l.width and l.height]
    heights = sorted(w.height for l in lines for w in l.words if w.height and len(w.text.strip()) >= 2)
    if not heights:
        return []
    h = heights[len(heights) // 2]
    ink = np.asarray(ink_map(image)) > INK_DELTA
    rows, cols = ink.shape
    # Everything read, with a margin of half its own height (a heading's letters reach further).
    boxes = [(l.left, l.top, l.width, l.height) for l in lines]
    boxes += [(w.left, w.top, w.width, w.height) for l in lines for w in l.words if w.width]
    boxes += [(0, t.top, cols, t.height) for t in page.tables if t.height]
    for left, top, width, height in boxes:
        m = 0.5 * max(height, h)
        ink[max(0, int(top - m)): int(top + height + m), max(0, int(left - m)): int(left + width + m)] = False
    for f in faint:
        ink[f["top"]: f["bottom"]] = False
    x0 = max(0, int(min(l.left for l in lines) - 2 * h))
    x1 = min(cols, int(max(l.left + l.width for l in lines) + 2 * h))
    y0 = max(0, int(min(l.top for l in lines) - 4 * h))
    y1 = min(rows, int(max(l.top + l.height for l in lines) + 4 * h))
    area = ink[y0:y1, x0:x1]
    longest = int(MISSED_EDGE * h)
    for x in range(area.shape[1]):
        col = area[:, x]
        if col.sum() <= longest:
            continue
        d = np.diff(np.concatenate(([0], col.astype(np.int8), [0])))
        for start, stop in zip(np.where(d == 1)[0], np.where(d == -1)[0]):
            if stop - start > longest:
                col[start:stop] = False
    on = area.sum(axis=1) >= max(2, 0.003 * (x1 - x0))
    bands, start, gap = [], None, 0
    for y, lit in enumerate(list(on) + [False] * 4):
        if lit:
            start, gap = (y if start is None else start), 0
        elif start is not None:
            gap += 1
            if gap > 2:
                bands.append((start, y - gap + 1))
                start, gap = None, 0
    found = []
    for top, bottom in bands:
        height = bottom - top
        if not 0.5 * h <= height <= 2.5 * h:
            continue
        inked = area[top:bottom].sum(axis=0) > 0
        pieces = int(inked[0]) + int(np.sum(inked[1:] & ~inked[:-1]))
        density = area[top:bottom].sum() / max(1, height * int(inked.sum()))
        if pieces >= MISSED_PIECES and inked.sum() >= MISSED_WIDTH * h and 0.05 <= density <= 0.6:
            middle = (y0 + (top + bottom) / 2) / max(rows, 1)
            where = "top" if middle < 1 / 3 else "middle" if middle < 2 / 3 else "bottom"
            found.append({"code": "missed_line", "top": y0 + top, "bottom": y0 + bottom, "where": where})
    return found


# ---------- Line ends: ink that carries on past the recognised text

END_GAP = 1.5  # ink this many line-heights past the last word still belongs to the line
END_MIN_WIDTH = 0.6  # unread ink at least this many line-heights wide flags the line


def mark_unclear_line_ends(image: Image.Image, page: Page, bounds: dict | None = None) -> None:
    """Flag lines whose ink continues to the right of the recognised text, e.g. a damaged
    or faint end of line the OCR silently dropped ("Do not take more than ... "). Only ink on
    the line's own paper ([bounds], paper_bounds): a card's border against a wall is not text,
    and a slip torn at the right is edge_cuts' job."""
    import numpy as np

    ink = np.asarray(ink_map(image)) > INK_DELTA
    gray = np.asarray(image.convert("L"), dtype=float)
    boxes = [(w.left, w.top, w.left + w.width, w.top + w.height) for l in page.lines for w in l.words if w.width]
    for line in page.lines:
        if not (line.width and line.height):
            continue
        top, bottom = line.top, line.top + line.height
        # Columns already explained by a recognised word on this text row (any line).
        covered = np.zeros(ink.shape[1], dtype=bool)
        for x0, y0, x1, y1 in boxes:
            if min(bottom, y1) - max(top, y0) >= 0.5 * (y1 - y0):
                covered[max(0, x0 - 2): x1 + 2] = True
        # Ignore specks: a column counts as ink when a tenth of the line's height is inked.
        inked = ink[top:bottom].sum(axis=0) >= max(2, line.height // 10)
        end = line.left + line.width
        _, limit = on_paper(bounds, line, ink.shape[1])
        window = slice(end, max(end, min(ink.shape[1], end + int(line.height * (END_GAP + 4)), limit)))
        unread = inked[window] & ~covered[window]
        if not unread.any():
            continue
        first = int(np.argmax(unread))
        if first <= line.height * END_GAP and int(unread[first:].sum()) >= line.height * END_MIN_WIDTH:
            line.end_unclear = True


# ---------- Parts of a row: ink between or beside the words that nothing read

PART_MIN_WIDTH = 0.6  # unread ink at least this many line-heights wide flags the row
PART_MIN_HEIGHT = 0.4  # ...and at least this tall at its highest: glyphs, not a ruled line
PART_JOIN = 0.3  # gaps up to this many line-heights join one unread run (the "." in 7.50)


def mark_unread_parts(image: Image.Image, page: Page, bounds: dict | None = None) -> None:
    """Flag a line when text-sized ink in its row is covered by no recognised word. On a
    statement Tesseract read a row's date and balance but silently dropped a small amount
    ("7.50") between them (docs/FINDINGS.md). The nearest line on that row is flagged,
    once; ink just past a line's end is mark_unclear_line_ends' job."""
    import numpy as np

    ink = np.asarray(ink_map(image)) > INK_DELTA
    boxes = [(w.left, w.top, w.left + w.width, w.top + w.height) for l in page.lines for w in l.words if w.width]
    lines = [l for l in page.lines if l.width and l.height]
    for line in lines:
        top, bottom, h = line.top, line.top + line.height, line.height
        row = [l for l in lines if min(bottom, l.top + l.height) - max(top, l.top) >= 0.5 * min(h, l.height)]
        covered = np.zeros(ink.shape[1], dtype=bool)
        for x0, y0, x1, y1 in boxes:
            if min(bottom, y1) - max(top, y0) >= 0.5 * (y1 - y0):
                covered[max(0, x0 - 2): x1 + 2] = True
        counts = ink[top:bottom].sum(axis=0)
        # Only ink on this line's paper: a card's border against a wall is not unread text, and
        # letters a tear cut through are edge_cuts' job.
        paper = np.zeros(ink.shape[1], dtype=bool)
        start, stop = on_paper(bounds, line, ink.shape[1])
        paper[start:stop] = True
        unread = (counts >= max(2, h // 10)) & ~covered & paper
        runs, start, gap = [], None, 0
        for x, on in enumerate(list(unread) + [False] * (int(h * PART_JOIN) + 2)):
            if on:
                start, gap = (x if start is None else start), 0
            elif start is not None:
                gap += 1
                if gap > h * PART_JOIN:
                    runs.append((start, x - gap + 1))
                    start, gap = None, 0
        for x0, x1 in runs:
            if x1 - x0 < h * PART_MIN_WIDTH or counts[x0:x1].max() < h * PART_MIN_HEIGHT:
                continue
            nearest = min(row, key=lambda l: max(0, l.left - x1, x0 - (l.left + l.width)))
            end = nearest.left + nearest.width
            if nearest is line and not (line.end_unclear and end <= x0 <= end + h * END_GAP):
                line.part_unclear = True


# ---------- Numbers: a second, independent reading of every number

REREAD_HEIGHT = 36  # crops are scaled so text is about this tall (Tesseract misreads larger, e.g. 5 as 9)


def _has_digit(text: str) -> bool:
    return any(ch.isdigit() for ch in text)


def _window_crop(image: Image.Image, words: list[Word]) -> Image.Image:
    """A crop around whole words (the number and its neighbours), scaled, strokes thickened,
    on a wide white border. Whole neighbouring words, not slivers: a sliver of a letter
    reads as a 1, and Tesseract's word boxes are too loose to crop one word tightly."""
    h = max(w.height for w in words)
    pad_x, pad_y = int(h * 0.25), int(h * 0.3)
    box = (max(0, min(w.left for w in words) - pad_x), max(0, min(w.top for w in words) - pad_y),
           min(image.width, max(w.left + w.width for w in words) + pad_x),
           min(image.height, max(w.top + w.height for w in words) + pad_y))
    crop = image.convert("L").crop(box)
    scale = max(1.0, REREAD_HEIGHT / max(h, 1))
    crop = crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.LANCZOS)
    crop = crop.filter(ImageFilter.MinFilter(3))  # recovers faint or broken digits (8 read as 6)
    return ImageOps.expand(crop, border=32, fill=255)


def _pick(reread: Page, position: int, count: int) -> Word | None:
    """The word in the re-read that stands where the number stood in the window."""
    words = [w for l in reread.lines for w in l.words]
    if len(words) == count:
        return words[position]
    numbers = [w for w in words if _has_digit(w.text)]
    return numbers[0] if len(numbers) == 1 else None


def reread_numbers(image: Image.Image, page: Page, engine: OCREngine) -> None:
    """Re-read a crop around every number word and store the result on the word, so the
    safety layer can flag numbers whose two readings disagree. Runs in every mode."""
    # Engines without their own single-line reader (PaddleOCR) are re-read by Tesseract:
    # always installed, and an independent second reader.
    snippet = engine.snippet_engine() if hasattr(engine, "snippet_engine") else TesseractEngine(psm=7)
    jobs = []
    for line in page.lines:
        boxed = [w for w in line.words if w.width and w.height]
        for i, w in enumerate(boxed):
            if _has_digit(w.text):
                window = boxed[max(0, i - 1): i + 2]
                jobs.append((w, window, window.index(w)))
    if not jobs:
        return

    def reread(job: tuple[Word, list[Word], int]) -> tuple[Word, Word | None]:
        w, window, position = job
        return w, _pick(snippet.read(_window_crop(image, window)), position, len(window))

    from concurrent.futures import ThreadPoolExecutor

    with ThreadPoolExecutor(max_workers=4) as pool:
        for w, found in pool.map(reread, jobs):
            w.reread_text = found.text if found else ""
            w.reread_confidence = found.confidence if found else 0.0


SECOND_PASS_SCALE = 1.5


def second_pass_image(image: Image.Image) -> Image.Image:
    """A differently prepared copy for the number cross-check: upscaled with
    thickened strokes, which recovers digits that faint or broken print turns
    into look-alikes (8 read as 6 or @)."""
    gray = image.convert("L")
    size = (int(gray.width * SECOND_PASS_SCALE), int(gray.height * SECOND_PASS_SCALE))
    return gray.resize(size, Image.LANCZOS).filter(ImageFilter.MinFilter(3))


def _page_dict(page: Page) -> dict:
    return {"lines": [asdict(l) for l in page.lines], "tables": [asdict(t) for t in page.tables]}


def upright(image: Image.Image) -> Image.Image:
    """The photo the way it was held: phone cameras (CameraX, the iPhone) often save the pixels
    sideways with an EXIF orientation tag. Applied before every reading (the phone's own offline
    reader does the same in its "upright" step)."""
    from PIL import ImageOps

    try:
        if image.getexif().get(0x0112, 1) == 1:
            # Already upright: the same object, so pytesseract hands Tesseract the photo exactly
            # as before (it re-saves a JPEG as JPEG; a copy would go as PNG and read differently).
            return image
        turned = ImageOps.exif_transpose(image)
    except Exception:  # a broken tag: read it as it is
        return image
    return turned if turned is not None else image


def read_page(image: Image.Image, engine: OCREngine | None = None, second_pass: bool = False,
              handwriting=None, strict_handwriting: bool = False) -> dict:
    """OCR one photo. With second_pass, also read a differently prepared copy so the
    safety layer can compare every number between the two readings. `handwriting` is an
    optional second reader for handwritten lines (handwriting.py; schoolwork only)."""
    import numpy as np

    from . import handwriting as hw
    from . import layout, letters

    engine = engine or default_engine()
    image = upright(image)
    page = engine.read(image)
    # A tilted photo (tilt no longer holds the camera back): a nearly empty or unsure reading
    # is tried again on the photo turned level, kept if it finds more words.
    if reads_faint(page) and ImageStat.Stat(image.convert("L")).stddev[0] > 3:
        level, angle = straighten(image)
        if angle:
            again = engine.read(level)
            if len(_words(again)) > len(_words(page)):
                image, page = level, again
    original = image  # where the paper ends is judged on the photo as taken
    # A Hausa, Yorùbá or Igbo page: read again with the model that keeps more of its letters
    # (letters.READ_AGAIN). Numbers are still re-read by the first engine, independently.
    language = letters.page_language(" ".join(l.text for l in page.lines))
    reader = _language_engine(engine, language) or engine
    if reader is not engine:
        page = reader.read(image)
    tiny = small_print(page)
    first = len(page.lines)
    faint = recover_faint(image, page, reader)
    if tiny == ["read_little"]:
        # A short label is just short. Text only recovery could find is small print if its
        # words are small; a normal-size card on a wall is not ("Move closer" would be wrong).
        tiny = ([t for t in small_print(page) if t != "read_little"] or ["small_print"]
                if len(page.lines) > first and _median_height(page) < SMALL_PRINT_PX else [])
    # Thermal or faint print still unread or unsure after recovery: read a flattened copy and
    # keep it if it finds more words. Every later step (number re-reads included) then uses it.
    enhanced = False
    # Not for a blank photo (nothing varies): faint thermal ink is too weak for ink_bands.
    if reads_faint(page) and ImageStat.Stat(original.convert("L")).stddev[0] > 3:
        flat = flatten_contrast(original)
        again = engine.read(flat)
        if len(_words(again)) > len(_words(page)):
            image, page, enhanced = flat, again, True
            language = letters.page_language(" ".join(l.text for l in page.lines))
            reader = _language_engine(engine, language) or engine
            if reader is not engine:
                page = reader.read(image)
            faint = recover_faint(image, page, reader)
            tiny = [t for t in small_print(page) if t != "read_little"]
    # A whole line the OCR dropped without a trace: on the photo as taken, before barcodes go
    # (their own boxes still cover their bars).
    faint = faint + missed_lines(original, page, faint)
    barcodes = drop_barcodes(original, page)
    bounds = paper_bounds(np.asarray(original.convert("L"), dtype=float), page)
    columns = layout.arrange(page, image)
    # On the photo as taken: flattening amplifies noise into "ink"; faint print is still ink there.
    mark_unclear_line_ends(original, page, bounds)
    mark_unread_parts(original, page, bounds)
    reread_numbers(image, page, engine)
    # Health papers: stricter, so a neatly handwritten dose is never read (handwriting.WOBBLE).
    script = hw.classify(page, original, strict=strict_handwriting)
    if handwriting is not None and script != "printed":
        hw.reread_handwritten(image, page, handwriting)
    tips = (capture_check(original) + cut_off(original, page) + edge_cuts(original, page, bounds) + tiny
            + (["faint_print"] if enhanced else []) + (["barcode_skipped"] if barcodes else [])
            # "This page looks handwritten" only when most of it does. A few unsure lines on a
            # printed page were called "mixed" from OCR doubt alone: a thermal slip and a
            # decorative card (27 Oct 2026). Their lines keep the handwriting number rules; the
            # app says "N lines are hard to read" instead (warning summary).
            + (["handwritten_page"] if script == "handwritten" else []) + ([f"letters_{language}"] if language else []))
    result = {"tips": tips, **_page_dict(page), "faint_regions": faint, "script": script, "columns": columns,
              "page_language": language}
    if language:
        result["letter_marks"] = letters.marks(result["lines"], language)
    if second_pass:
        result["second_pass"] = _page_dict(engine.read(second_pass_image(image)))
    return result


def _language_engine(engine: OCREngine, language: str | None) -> OCREngine | None:
    """The Tesseract model that reads [language]'s letters better, when it is installed."""
    model = letters_model(language)
    if model is None or not isinstance(engine, TesseractEngine) or engine.lang != "eng":
        return None
    return TesseractEngine(lang=model) if model in installed_models() else None


def letters_model(language: str | None) -> str | None:
    from .letters import READ_AGAIN

    return READ_AGAIN.get(language or "")


_models: set[str] | None = None


def installed_models() -> set[str]:
    """Tesseract's installed language and script models (cached)."""
    global _models
    if _models is None:
        try:
            import pytesseract

            _models = {m.removeprefix("script/") for m in pytesseract.get_languages(config="")}
        except Exception:
            _models = set()
    return _models


class NumberRereadMissing(RuntimeError):
    """An OCR engine left a number without its independent second reading."""


def check_number_reread(engine: OCREngine) -> None:
    """Start-up self-test (CLAUDE.md rule 2): read a rendered dose line with this engine and
    make sure every number was re-read from its own crop. The server refuses to start if
    not, so no engine (e.g. OCR_ENGINE=paddle) can silently skip the check."""
    from PIL import ImageDraw, ImageFont

    img = Image.new("RGB", (900, 160), "white")
    draw = ImageDraw.Draw(img)
    draw.text((40, 50), "Take 2 tablets every 6 hours", fill="black", font=ImageFont.load_default(size=44))
    page = engine.read(img)
    reread_numbers(img, page, engine)
    numbers = [w for line in page.lines for w in line.words if _has_digit(w.text)]
    if not numbers:
        raise NumberRereadMissing(f"{type(engine).__name__} read no numbers from the self-test line")
    missing = [w.text for w in numbers if w.reread_text is None]
    if missing:
        raise NumberRereadMissing(
            f"{type(engine).__name__} cannot re-read numbers from crops ({missing}): refusing to run")
