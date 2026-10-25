"""Private bank-statement benchmark: how Magana reads every number on a real statement.

    cd backend && .venv/bin/python scripts/bank_benchmark.py ~/magana-private-pages/bank_a_statement.pdf

The statement never leaves this computer: it is read from disk into memory, nothing is
written, nothing is sent to any service (OCR is local Tesseract; money papers never go to
a model). The output is totals only: no amounts, dates, names or account numbers, and
error messages are reduced to their type. A locked PDF's password comes from the
MAGANA_PDF_PASSWORD environment variable and is never printed.

Ground truth is the PDF's own text layer. Each number (a word with a digit) is scored on
three readings of the page:
  text   the "Read a PDF" path (pdfs.py): the text layer, tables row by row
  scan   the page rendered at 300 dpi (pdfs.DPI), private parts masked, through the money-mode
         OCR and safety checks (second pass, re-read crops), as a scanned PDF would be
  photo  the masked scan made phone-like (150 dpi, tilted 1°, slightly blurred, uneven
         light, JPEG): SIMULATED, not a real phone photo

Each number ends up as one of: correct (the same value, no warning; "9999.99," for
9,999.99 is the same value and is spoken the same), correct but flagged,
misread and flagged, misread NOT flagged (the dangerous one), missed with a warning
(faint region), or missed silently.

Scored: the date and amount cells (date, value date, debit, credit, balance) of every
transaction row. Masked with black boxes before OCR, and never scored: everything else
(the name, address and account details above the table, summaries, descriptions,
references and channels, which hold counterparty names), plus any run of 8+ digits.
"""
from __future__ import annotations

import io
import json
import math
import os
import re
import sys
import time
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import main, pdfs  # noqa: E402
from app.reader import TesseractEngine, read_page  # noqa: E402

PRIVATE_LABELS = re.compile(r"name|address|addr|account|acct|a/c|bvn|phone|mobile|e-?mail|branch|customer|nuban",
                            re.I)
LONG_DIGITS = re.compile(r"\d{8,}")
EMAIL = re.compile(r"\S+@\S+")
AMOUNT = re.compile(r"^-?[₦N]?\(?-?\d{1,3}(,\d{3})*(\.\d{2})\)?(CR|DR)?$|^-?\d+\.\d{2}$", re.I)
DATE = re.compile(r"^\d{1,4}[-/.]\d{1,2}([-/.]\d{2,4})?$|^\d{1,2}-?[A-Za-z]{3}-?\d{2,4}$")
SCORED_KINDS = {"date", "value_date", "debit", "credit", "balance"}


def core(t: str) -> str:
    return t.strip("()[]{},;:!\"'₦").rstrip(".")


def has_digit(t: str) -> bool:
    return any(c.isdigit() for c in t)


def kind_of(text: str, column: str | None) -> str:
    """The column decides ("7.50" under Debit is an amount, though it looks like a date)."""
    c = core(text)
    if column in {"date", "value_date"}:
        return "date"
    if column in {"debit", "credit", "balance"}:
        return "amount"
    return "date" if DATE.match(c) else "amount" if AMOUNT.match(c) else "other"


def ground_truth(words: list[pdfs._W], carried):
    """(scored numbers, private boxes, columns) for one text-layer page, in PDF points.

    Scored: the date and amount cells of each transaction row (pdfs' own rows). Masked:
    everything else, except the column headers."""
    lines = pdfs._lines(words)
    heads, header_lines = {}, set()
    k = 0
    while k < len(lines):
        h = pdfs.find_header(lines[k])
        if h:
            cols, used = pdfs.merge_header(lines, k, h)
            heads[min(used)] = cols
            header_lines |= used
            k = max(used) + 1
        else:
            k += 1
    cols, private, scored = carried, [], []
    for i, ws in enumerate(lines):
        cols = heads.get(i, cols)
        if i in header_lines:
            continue
        if cols is None or not pdfs._is_anchor(ws, cols):
            private.append((min(w.x0 for w in ws), min(w.top for w in ws), max(w.x1 for w in ws),
                            max(w.bottom for w in ws)))
            continue
        for g in pdfs._groups(ws):
            col = cols[pdfs._column_of(g, cols)].kind
            for w in g:
                if (col not in SCORED_KINDS or LONG_DIGITS.search(w.text) or EMAIL.search(w.text)
                        or PRIVATE_LABELS.search(w.text)):
                    private.append((w.x0, w.top, w.x1, w.bottom))
                elif has_digit(w.text):
                    scored.append((w, kind_of(w.text, col)))
                # month names and "--" stay on the page, unscored
    return scored, private, cols


def masked_render(page, private) -> Image.Image:
    img = pdfs.render(page)
    d = ImageDraw.Draw(img)
    s = pdfs.SCALE
    for x0, y0, x1, y1 in private:
        # White, not black: black blocks beside the text made Tesseract read the dates as
        # letters (first run: 1,261 of 1,605 date parts misread).
        d.rectangle([x0 * s - 2, y0 * s - 2, x1 * s + 2, y1 * s + 2], fill="white")
    return img


ANGLE = 1.0
PHOTO_SCALE = 0.5  # 300 dpi scan to 150 dpi


def photo_like(img: Image.Image) -> Image.Image:
    w, h = img.size
    small = img.resize((int(w * PHOTO_SCALE), int(h * PHOTO_SCALE)), Image.LANCZOS)
    tilted = small.rotate(ANGLE, resample=Image.BICUBIC, fillcolor="white")
    soft = tilted.filter(ImageFilter.GaussianBlur(0.7))
    light = Image.linear_gradient("L").rotate(90).resize(soft.size)  # dimmer to one side
    shade = Image.merge("RGB", [light.point(lambda v: 190 + v * 65 // 255)] * 3)
    from PIL import ImageChops
    lit = ImageChops.multiply(soft, shade)
    buf = io.BytesIO()
    lit.save(buf, "JPEG", quality=70)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


def to_photo(x: float, y: float, size: tuple[int, int]) -> tuple[float, float]:
    """Where a scan pixel lands in photo_like (scaled, then turned about the centre)."""
    x, y = x * PHOTO_SCALE, y * PHOTO_SCALE
    cx, cy = size[0] / 2, size[1] / 2
    t = math.radians(ANGLE)
    return (cx + (x - cx) * math.cos(t) + (y - cy) * math.sin(t),
            cy - (x - cx) * math.sin(t) + (y - cy) * math.cos(t))


def value(t: str) -> str:
    """The number as spoken: thousands commas don't change it ("9999.99," is 9,999.99)."""
    return core(t).replace(",", "")


def score_ocr(result: dict, scored, place, scale: float = 1.0) -> Counter:
    """Match each true number to the OCR words at its place on the image."""
    flagged_words, flagged_lines = set(), set()
    for w in result["warnings"]:
        if w.get("word_index") is None:
            flagged_lines.add(w["block_index"])
        else:
            flagged_words.add((w["block_index"], w["word_index"]))
    faint = result.get("faint_regions", [])
    out = Counter()
    for w, kind in scored:
        (cx, cy), half_h = place((w.x0 + w.x1) / 2 * pdfs.SCALE, (w.top + w.bottom) / 2 * pdfs.SCALE), \
            (w.bottom - w.top) * pdfs.SCALE * scale * 0.8
        x0, x1 = place(w.x0 * pdfs.SCALE, 0)[0], place(w.x1 * pdfs.SCALE, 0)[0]
        hits = []
        for li, line in enumerate(result["lines"]):
            for wi, ow in enumerate(line["words"]):
                if not ow["width"]:
                    continue
                mx, my = ow["left"] + ow["width"] / 2, ow["top"] + ow["height"] / 2
                if abs(my - cy) <= max(half_h, 8) and min(x1, ow["left"] + ow["width"]) - max(x0, ow["left"]) > 0:
                    hits.append((li, wi, ow["text"], mx))
        hits.sort(key=lambda h: h[3])
        truth = core(w.text)
        if not hits:
            # Warned all the same: a faint region there, or a warning on a line of that row
            # (line_part_unclear: print in the row that no word covers).
            row_warned = any(li in flagged_lines and abs(l["top"] + l["height"] / 2 - cy) <= max(half_h, 8)
                             for li, l in enumerate(result["lines"]))
            near_faint = row_warned or any(abs(f.get("top", 0) - cy) < 60 for f in faint)
            out[f"{kind}:missed_flagged" if near_faint else f"{kind}:missed_silently"] += 1
            continue
        exact = any(value(h[2]) == value(truth) for h in hits) or value("".join(h[2] for h in hits)) == value(truth)
        flagged = any((h[0], h[1]) in flagged_words or h[0] in flagged_lines for h in hits)
        if exact:
            out[f"{kind}:correct_flagged" if flagged else f"{kind}:correct"] += 1
        else:
            out[f"{kind}:misread_flagged" if flagged else f"{kind}:misread_NOT_flagged"] += 1
            if not flagged:
                out[f"how:{misread_shape(truth, ''.join(core(h[2]) for h in hits))}"] += 1
    return out


def misread_shape(truth: str, read: str) -> str:
    """What kind of mistake, without the numbers themselves."""
    td, rd = re.sub(r"\D", "", truth), re.sub(r"\D", "", read)
    if td == rd:
        return "same_digits_punctuation_differs"
    if len(td) != len(rd):
        return "digit_count_differs"
    return f"{sum(a != b for a, b in zip(td, rd))}_digit_substituted"


def score_text(body: dict, scored_total: Counter, truths: list[str]) -> Counter:
    said = Counter()
    for l in body["lines"]:
        said.update(core(t) for t in l["text"].split())
    for t in body["tables"]:
        for row in t["rows"]:
            for c in row:
                said.update(core(x) for x in c["text"].split())
    out = Counter()
    for t in truths:
        if said[t] > 0:
            said[t] -= 1
            out["correct"] += 1
        else:
            out["missing"] += 1
    out["warnings"] = len(body["warnings"]) + len(body["cell_warnings"])
    return out


def main_(path: str) -> None:
    data = Path(path).expanduser().read_bytes()
    password = os.environ.get("MAGANA_PDF_PASSWORD") or None
    engine = TesseractEngine()
    report: dict = {"paper": "Bank A statement", "pages": 0, "text_layer_pages": 0, "masked_boxes": 0,
                    "header_columns": Counter(), "numbers": Counter(), "text": Counter(), "scan": Counter(),
                    "photo_simulated": Counter(), "page_tips": Counter(), "seconds": {}}
    t0 = time.time()
    body = pdfs.read_pdf(data, password, engine, True, main.checked)
    report["seconds"]["text_path"] = round(time.time() - t0, 1)
    report["tables_found"] = len(body["tables"])
    report["table_rows"] = sum(len(t["rows"]) - 1 for t in body["tables"])
    all_truths = []
    t_scan = t_photo = 0.0
    carried = None
    for number, count, words, page in pdfs.pages(data, password):
        report["pages"] = count
        if words is None:
            continue
        report["text_layer_pages"] += 1
        scored, private, carried = ground_truth(words, carried)
        report["masked_boxes"] += len(private)
        if carried and not report["header_columns"]:
            report["header_columns"].update(c.kind for c in carried)
        report["numbers"].update(k for _, k in scored)
        all_truths += [core(w.text) for w, _ in scored]
        img = masked_render(page, private)
        t = time.time()
        scan = main.checked(read_page(img, engine, second_pass=True))
        t_scan += time.time() - t
        report["scan"] += score_ocr(scan, scored, lambda x, y: (x, y))
        report["page_tips"].update(f"scan:{t}" for t in scan["tips"])
        photo = photo_like(img)
        t = time.time()
        res = main.checked(read_page(photo, engine, second_pass=True))
        t_photo += time.time() - t
        size = photo.size
        report["page_tips"].update(f"photo:{t}" for t in res["tips"])
        if not res["lines"]:  # the app says "no text found" and doesn't open a reading
            report["page_tips"]["photo:no_text_found_page"] += 1
            report["photo_simulated"]["on_no_text_found_pages"] += len(scored)
        else:
            report["photo_simulated"] += score_ocr(res, scored, lambda x, y: to_photo(x, y, size), PHOTO_SCALE)
        del img, photo, scan, res
    report["text"] = score_text(body, report["numbers"], all_truths)
    report["seconds"]["scan_ocr"] = round(t_scan, 1)
    report["seconds"]["photo_ocr"] = round(t_photo, 1)
    print(json.dumps({k: dict(sorted(v.items())) if isinstance(v, Counter) else v for k, v in report.items()},
                     indent=1))


if __name__ == "__main__":
    try:
        main_(sys.argv[1])
    except pdfs.PdfError as e:
        print(json.dumps({"error": e.code}))
    except Exception as e:  # never print a message that could quote the statement
        print(json.dumps({"error": type(e).__name__}))
