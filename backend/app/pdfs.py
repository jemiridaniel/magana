"""Reading a PDF (bank statements, results, letters): in memory, never stored.

A page with a text layer is read from the file's own characters: no OCR, so every
number is exactly as printed. A statement's transaction table is read row by row
under its column names (Date, Description, Debit, Credit, Balance). A page without
text (a scan) is rendered and goes through the same OCR and safety checks as a photo.

A locked PDF needs its password (often sent by the bank in the same email). It is
used once to open the file for this request and is never stored, logged or returned.
"""
from __future__ import annotations

import io
import re
from dataclasses import asdict, dataclass

import pdfplumber
from pdfminer.pdfdocument import PDFPasswordIncorrect
from PIL import Image

from .reader import Cell, Line, OCREngine, Page, Table, Word, read_page

MAX_PAGES = 20
MAX_BYTES = 15 * 1024 * 1024
# Fewer characters than this on a page: it's a scan (or a picture of text).
MIN_TEXT_CHARS = 20
# Scans are rendered at this resolution for OCR; text pages use it for positions only.
# 300, not 200: on a statement's 7 pt print, 200 dpi read 23 of 34 amounts on a test
# page and 300 dpi 31 (docs/FINDINGS.md).
DPI = 300
SCALE = DPI / 72
# Items on later pages sort after earlier ones (the app orders a reading by `top`).
PAGE_SPAN = 100_000
# Words further apart than this (points) on one line sit in different columns.
COLUMN_GAP = 10


class PdfError(Exception):
    """A message code (messages.py): pdf_password_needed, pdf_password_wrong, unreadable_pdf, pdf_too_long."""

    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


# Column names on Nigerian bank statements, by kind. Matched on whole header cells.
HEADER_KINDS = {
    "date": {"date", "trans date", "trans. date", "txn date", "transaction date", "tran date", "posted",
             "posting date", "post date", "booking date", "entry date", "trans. time", "trans time",
             "transaction time", "date/time", "date time", "date & time", "time"},
    "value_date": {"value date", "val date", "value dt"},
    "description": {"description", "narration", "details", "remarks", "particulars", "transaction details",
                    "narrative", "transaction description", "memo"},
    "reference": {"reference", "ref", "ref.", "ref no", "reference no", "ref. no", "cheque no", "chq no",
                  "transaction ref", "transaction reference", "channel", "session id", "transaction id",
                  "transaction type", "type", "category"},
    "debit": {"debit", "debits", "withdrawal", "withdrawals", "money out", "dr", "debit amount", "out"},
    "credit": {"credit", "credits", "deposit", "deposits", "lodgement", "lodgements", "money in", "cr",
               "credit amount", "in"},
    "balance": {"balance", "running balance", "closing balance", "available balance", "bal", "balance after",
                "balance after transaction", "ledger balance", "book balance"},
}
_NUMBERISH = re.compile(r"\d")


def header_kind(text: str) -> str | None:
    """'Debit(₦)', 'Balance (NGN)' and 'Balance( ₦)' (split over two lines) are all their kind."""
    t = re.sub(r"\(\s*(₦|ngn|n)?\s*\)?|\)|₦|:", " ", text.strip().lower())
    t = re.sub(r"\s+", " ", t).strip()
    for kind, names in HEADER_KINDS.items():
        if t in names:
            return kind
    return None


@dataclass
class _W:
    text: str
    x0: float
    x1: float
    top: float
    bottom: float


def _lines(words: list[_W]) -> list[list[_W]]:
    """Words into lines by their vertical position, each line left to right."""
    out: list[list[_W]] = []
    for w in sorted(words, key=lambda w: (round(w.top), w.x0)):
        if out and abs(out[-1][0].top - w.top) <= 3:
            out[-1].append(w)
        else:
            out.append([w])
    return [sorted(l, key=lambda w: w.x0) for l in out]


def _groups(line: list[_W]) -> list[list[_W]]:
    """A line's words into runs separated by a column-sized gap."""
    out: list[list[_W]] = []
    for w in line:
        if out and w.x0 - out[-1][-1].x1 <= COLUMN_GAP:
            out[-1].append(w)
        else:
            out.append([w])
    return out


def _text(ws: list[_W]) -> str:
    return " ".join(w.text for w in ws)


@dataclass
class Column:
    kind: str
    name: str
    x0: float
    x1: float


def find_header(line: list[_W]) -> list[Column] | None:
    """A transaction table's header: at least three known column names, one of them an
    amount or the balance."""
    cols = []
    for g in _groups(line):
        kind = header_kind(_text(g))
        if kind is None:
            return None  # a header line holds column names only
        cols.append(Column(kind, _text(g), g[0].x0, g[-1].x1))
    kinds = {c.kind for c in cols}
    if len(cols) >= 3 and kinds & {"debit", "credit", "balance"}:
        return cols
    return None


def _column_of(g: list[_W], cols: list[Column]) -> int:
    """The column a run of words belongs to: the header it overlaps most (a date is wider
    than "Date", an amount ends under "Debit"), else the one its middle falls in, with each
    boundary halfway between neighbouring columns."""
    x0, x1 = g[0].x0, g[-1].x1
    overlap = [min(x1, c.x1) - max(x0, c.x0) for c in cols]
    best = max(range(len(cols)), key=lambda i: overlap[i])
    if overlap[best] > 0:
        return best
    mid = (x0 + x1) / 2
    for i in range(len(cols) - 1):
        if mid < (cols[i].x1 + cols[i + 1].x0) / 2:
            return i
    return len(cols) - 1


def _word(w: _W) -> Word:
    return Word(w.text, 1.0, int(w.x0 * SCALE), int(w.top * SCALE), int((w.x1 - w.x0) * SCALE),
                int((w.bottom - w.top) * SCALE))


def _line(ws: list[_W]) -> Line:
    return Line(text=_text(ws), confidence=1.0, top=int(ws[0].top * SCALE), words=[_word(w) for w in ws],
                left=int(ws[0].x0 * SCALE), width=int((ws[-1].x1 - ws[0].x0) * SCALE),
                height=int((max(w.bottom for w in ws) - ws[0].top) * SCALE))


AMOUNT_KINDS = {"debit", "credit", "balance"}
ANCHOR_KINDS = {"date", "value_date"} | AMOUNT_KINDS


def merge_header(lines: list[list[_W]], at: int, cols: list[Column]) -> tuple[list[Column], set[int]]:
    """Header names split over the lines just above and below ("Balance(" / "₦)", with the
    other names on the middle line): join each split name and add it as a column."""
    used = {at}
    height = max(w.bottom for w in lines[at]) - min(w.top for w in lines[at])
    frags: list[tuple[int, list[_W]]] = []
    for k in (at - 1, at + 1):
        if 0 <= k < len(lines):
            gap = abs(lines[k][0].top - lines[at][0].top)
            if gap <= 1.6 * height + 2:
                frags += [(k, g) for g in _groups(lines[k])]
    new: list[Column] = []
    taken: set[int] = set()
    for i, (k, g) in enumerate(frags):
        if i in taken:
            continue
        x0, x1 = g[0].x0, g[-1].x1
        parts = [(k, g)]
        for j in range(i + 1, len(frags)):
            k2, g2 = frags[j]
            if j not in taken and k2 != k and min(x1, g2[-1].x1) - max(x0, g2[0].x0) > 0:
                parts.append((k2, g2))
                taken.add(j)
        parts.sort(key=lambda p: p[0])
        name = " ".join(_text(g) for _, g in parts)
        kind = header_kind(name)
        overlaps = any(min(x1, c.x1) - max(x0, c.x0) > 0 for c in cols)
        if kind is None or overlaps:
            continue
        new.append(Column(kind, re.sub(r"\(\s+", "(", name), min(g[0].x0 for _, g in parts),
                          max(g[-1].x1 for _, g in parts)))
        used.update(k for k, _ in parts)
    # A neighbouring line joins the header only if all of it did.
    for k in list(used - {at}):
        if any(not any(min(g[-1].x1, c.x1) - max(g[0].x0, c.x0) > 0 for c in new) for g in _groups(lines[k])):
            return cols, {at}
    return sorted(cols + new, key=lambda c: c.x0), used


def _cells(ws: list[_W], cols: list[Column]) -> list[str]:
    cells = [""] * len(cols)
    for g in _groups(ws):
        i = _column_of(g, cols)
        cells[i] = f"{cells[i]} {_text(g)}".strip()
    return cells


# 02 Sep 2026, 02-SEP-26, 02/09/2026, 2026-09-02 (not 9,999.99).
DATEISH = re.compile(r"(?<![\d,.])(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{4}-\d{2}-\d{2}"
                     r"|\d{1,2}[-/ ]?[A-Za-z]{3,9}[-/ ,]*\d{2,4})(?![\d,.]*\d)")
DATE_KINDS = {"date", "value_date"}


def _is_anchor(ws: list[_W], cols: list[Column]) -> bool:
    """A transaction's own line: a date in the date column, or, in a table without one,
    an amount. A summary above a new header ("Opening balance ₦…") is not a row."""
    cells = list(zip(_cells(ws, cols), cols))
    if any(c.kind in DATE_KINDS for c in cols):
        return any(DATEISH.search(t) and "₦" not in t for t, c in cells if c.kind in DATE_KINDS)
    return any(_NUMBERISH.search(t) for t, c in cells if c.kind in AMOUNT_KINDS)


def _only_text(ws: list[_W], cols: list[Column]) -> bool:
    """Wrapped description or reference text: nothing in the date or amount columns."""
    return all(not t or c.kind not in ANCHOR_KINDS for t, c in zip(_cells(ws, cols), cols))


def text_page(words: list[_W], carried: list[Column] | None = None) -> tuple[Page, list[Column] | None]:
    """A text-layer page: lines, with each transaction table read row by row.

    Later pages often have no header: the previous page's columns carry on until a new
    header (a second account or month can start halfway down a page, laid out anew)."""
    page = Page()
    lines = _lines(words)
    heads: list[tuple[list[Column], set[int]]] = []
    k = 0
    while k < len(lines):
        if (h := find_header(lines[k])) is not None:
            cols, used = merge_header(lines, k, h)
            heads.append((cols, used))
            k = max(used) + 1
        else:
            k += 1
    parts = [(0, carried, set())] + [(min(used), cols, used) for cols, used in heads]
    for i, (begin, cols, used) in enumerate(parts):
        stop = parts[i + 1][0] if i + 1 < len(parts) else len(lines)
        _segment(page, lines, begin, stop, cols, used)
    page.lines.sort(key=lambda l: l.top)
    return page, heads[-1][0] if heads else carried


def _segment(page: Page, lines: list[list[_W]], begin: int, stop: int, cols: list[Column] | None,
             used: set[int]) -> None:
    """Lines [begin, stop) under one header (or the carried columns).

    Each row is a line with a date or an amount (its anchor). Statements centre a long
    description in a tall row, so wrapped text above and below goes with the nearest
    anchor."""
    start = max(used) + 1 if used else begin
    anchors = [k for k in range(start, stop) if cols and _is_anchor(lines[k], cols)]
    if not anchors:
        page.lines += [_line(lines[k]) for k in range(begin, stop) if k not in used]
        return
    tops = [lines[a][0].top for a in anchors]
    spacing = sorted(b - a for a, b in zip(tops, tops[1:]))[(len(tops) - 1) // 2] if len(tops) > 1 else 40
    end = anchors[-1]
    while (end + 1 < stop and _only_text(lines[end + 1], cols)
           and lines[end + 1][0].top - lines[anchors[-1]][0].top < 0.75 * spacing):
        end += 1
    rows: dict[int, list[list[_W]]] = {a: [] for a in anchors}
    for k in range(begin, stop):
        ws = lines[k]
        if k in used:
            continue
        if k < start or k > end:
            page.lines.append(_line(ws))
        elif k in rows:
            rows[k].append(ws)
        elif _only_text(ws, cols):
            rows[min(anchors, key=lambda a: (abs(lines[a][0].top - ws[0].top), a))].append(ws)
        else:
            page.lines.append(_line(ws))
    cells = [[Cell(c.name, 1.0, 0, i) for i, c in enumerate(cols)]]
    for r, a in enumerate(anchors, start=1):
        joined = [""] * len(cols)
        for ws in sorted(rows[a], key=lambda ws: ws[0].top):
            for i, t in enumerate(_cells(ws, cols)):
                if t:
                    joined[i] = f"{joined[i]} {t}".strip()
        cells.append([Cell(t, 1.0, r, i) for i, t in enumerate(joined)])
    top = lines[min(used)][0].top if used else lines[start][0].top
    page.tables.append(Table(rows=cells, top=int(top * SCALE), header=True))


def _page_words(p) -> list[_W]:
    return [_W(w["text"], w["x0"], w["x1"], w["top"], w["bottom"])
            for w in p.extract_words(x_tolerance=1.5, y_tolerance=3, keep_blank_chars=False)]


def open_pdf(data: bytes, password: str | None):
    if len(data) > MAX_BYTES:
        raise PdfError("pdf_too_long")
    try:
        return pdfplumber.open(io.BytesIO(data), password=password or "")
    except Exception as e:  # pdfplumber wraps pdfminer's errors
        inner = getattr(e, "args", [None])[0] if e.args else None
        if isinstance(e, PDFPasswordIncorrect) or isinstance(inner, PDFPasswordIncorrect):
            raise PdfError("pdf_password_wrong" if password else "pdf_password_needed") from None
        raise PdfError("unreadable_pdf") from None


def scanned_page(p) -> bool:
    """A picture of the page with a hidden text layer on top (what scanner apps make). That
    layer is another program's OCR, so Magana reads the picture itself, with its checks."""
    area = float(p.width * p.height) or 1.0
    covered = sum(max(0.0, (min(im["x1"], p.width) - max(im["x0"], 0)))
                  * max(0.0, (min(im["bottom"], p.height) - max(im["top"], 0))) for im in p.images)
    return covered / area > 0.5


def render(p) -> Image.Image:
    return p.to_image(resolution=DPI).original.convert("RGB")


def pages(data: bytes, password: str | None = None):
    """(page number, page count, words or None, the page object) for each page."""
    pdf = open_pdf(data, password)
    try:
        n = len(pdf.pages)
        if n == 0:
            raise PdfError("unreadable_pdf")
        if n > MAX_PAGES:
            raise PdfError("pdf_too_long")
        for i, p in enumerate(pdf.pages, start=1):
            try:
                words = _page_words(p)
            except Exception:
                raise PdfError("unreadable_pdf") from None
            chars = sum(len(w.text) for w in words)
            text = chars >= MIN_TEXT_CHARS and not scanned_page(p)
            yield i, n, (words if text else None), p
    finally:
        pdf.close()


def read_pdf(data: bytes, password: str | None, engine: OCREngine, second_pass: bool, check,
             strict_handwriting: bool = False) -> dict:
    """The whole PDF as one /read response. `check(result)` adds the safety warnings for
    one page (main.checked); their indexes are shifted as pages are joined."""
    out = {"tips": [], "lines": [], "tables": [], "faint_regions": [], "warnings": [], "cell_warnings": [],
           "pages": []}
    cols = None  # a statement's columns carry on to pages without a header
    for number, count, words, p in pages(data, password):
        if words is not None:
            pg, cols = text_page(words, cols)
            # The file's own characters: there is no reading to doubt, so no OCR checks
            # (they take a real "|" beside a number for a smudged digit).
            result = {"tips": [], "lines": [asdict(l) for l in pg.lines], "tables": [asdict(t) for t in pg.tables],
                      "faint_regions": [], "warnings": [], "cell_warnings": []}
            source = "text"
        else:
            result = read_page(render(p), engine, second_pass=second_pass, strict_handwriting=strict_handwriting)
            result = check(result)
            source = "scan"
            cols = None
        shift_lines, shift_tables = len(out["lines"]), len(out["tables"])
        offset = (number - 1) * PAGE_SPAN
        for l in result["lines"]:
            out["lines"].append({**l, "top": l["top"] + offset, "page": number})
        for t in result["tables"]:
            out["tables"].append({**t, "top": t["top"] + offset, "page": number})
        for f in result.get("faint_regions", []):
            out["faint_regions"].append({**f, "top": f.get("top", 0) + offset, "page": number})
        out["warnings"] += [{**w, "block_index": w["block_index"] + shift_lines} for w in result["warnings"]]
        out["cell_warnings"] += [{**w, "table_index": w["table_index"] + shift_tables} for w in result["cell_warnings"]]
        out["tips"] += [t for t in result.get("tips", []) if t not in out["tips"]]
        out["pages"].append({"number": number, "source": source})
    out["page_count"] = len(out["pages"])
    return out
