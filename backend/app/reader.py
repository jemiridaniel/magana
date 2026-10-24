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

from PIL import Image, ImageFilter, ImageStat


@dataclass
class Word:
    text: str
    confidence: float  # 0-1


@dataclass
class Line:
    text: str
    confidence: float  # 0-1
    top: int
    label: str = ""
    height: int = 0
    # Per-word confidence, so one shaky number is not hidden by confident words around it.
    words: list[Word] = field(default_factory=list)


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


@dataclass
class Page:
    lines: list[Line] = field(default_factory=list)
    tables: list[Table] = field(default_factory=list)


class OCREngine(Protocol):
    def read(self, image: Image.Image) -> Page: ...


class TesseractEngine:
    """Dev/offline-fallback engine. Groups Tesseract words into lines."""

    def __init__(self, lang: str = "eng"):
        self.lang = lang

    def read(self, image: Image.Image) -> Page:
        import pytesseract

        data = pytesseract.image_to_data(image, lang=self.lang, output_type=pytesseract.Output.DICT)
        lines: dict[tuple, dict] = {}
        for i, word in enumerate(data["text"]):
            if not word.strip():
                continue
            key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
            entry = lines.setdefault(key, {"words": [], "confs": [], "top": data["top"][i], "bottom": 0})
            entry["words"].append(word)
            entry["confs"].append(max(float(data["conf"][i]), 0.0) / 100)
            entry["bottom"] = max(entry["bottom"], data["top"][i] + data["height"][i])
        out = []
        for n, (_, e) in enumerate(sorted(lines.items(), key=lambda kv: kv[1]["top"])):
            conf = sum(e["confs"]) / len(e["confs"])
            words = [Word(w, round(c, 3)) for w, c in zip(e["words"], e["confs"])]
            out.append(Line(" ".join(e["words"]), round(conf, 3), e["top"], label=f"line {n + 1}",
                            height=e["bottom"] - e["top"], words=words))
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
        tables.append(Table(rows, top, label=f"table {n + 1}", header=header, confidence=round(overall, 3)))

    # Page lines: overall OCR text that is not inside a table (tables are read cell by cell).
    regions = table_regions or [_union([_xyxy(b) for b in t["cell_box_list"]])
                                for t in tables_raw if t.get("cell_box_list")]
    lines = []
    for text, score, box in zip(texts, scores, boxes):
        if not text.strip() or any(_boxes_overlap(r, box) > 0.5 for r in regions):
            continue
        # PP-OCR scores whole text lines, so each word carries its line's score.
        words = [Word(w, round(score, 3)) for w in text.split()]
        x1y1x2y2 = _xyxy(box)
        lines.append(Line(text.strip(), round(score, 3), _top(box), height=int(x1y1x2y2[3] - x1y1x2y2[1]), words=words))
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


def _union(boxes: list[list[float]]) -> list[float]:
    return [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]


def default_engine() -> OCREngine:
    """MAGANA_OCR=paddle selects PP-StructureV3; anything else uses Tesseract."""
    if os.environ.get("MAGANA_OCR", "tesseract").lower() == "paddle":
        return PaddleStructureEngine(lang=os.environ.get("MAGANA_OCR_LANG", "en"))
    return TesseractEngine()


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


def read_page(image: Image.Image, engine: OCREngine | None = None, second_pass: bool = False) -> dict:
    """OCR one photo. With second_pass, also read a differently prepared copy so the
    safety layer can compare every number between the two readings."""
    engine = engine or default_engine()
    result = {"tips": capture_check(image), **_page_dict(engine.read(image))}
    if second_pass:
        result["second_pass"] = _page_dict(engine.read(second_pass_image(image)))
    return result
