"""Safety layer: every AI output passes through here before a user hears it.

Two core rules from the Magana design:
1. Critical values (numbers, money, doses, dates, percentages, ranges) are read
   verbatim from the page. If a model-generated explanation contains a critical
   value that is not on the page, the explanation is rejected.
2. Low-confidence text is never read as if it were certain: it gets a warning
   instead. Warnings are message codes (messages.py); the app words them.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

# Order matters: longer, more specific patterns first.
_CRITICAL_PATTERNS = [
    r"₦\s?\d[\d,]*(?:\.\d+)?",                      # naira amounts
    r"\bN\s?\d[\d,]*(?:\.\d+)?\b",                  # N1,000 style amounts
    r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b",           # dates 14/10/2026
    r"\b\d{1,2}[/-]\d{4}\b",                        # expiry 08/2027
    r"\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|kg|ml|mL|l|L|IU|units?|g/dL|mmol/L|%)",  # doses, units, percent
    r"\b\d+(?:\.\d+)?\s?[–-]\s?\d+(?:\.\d+)?\b",    # ranges 12.0 – 16.0
    r"\b\d[\d,]*(?:\.\d+)?\b",                      # any other number
]
_CRITICAL_RE = re.compile("|".join(f"(?:{p})" for p in _CRITICAL_PATTERNS))


def _norm(token: str) -> str:
    """Normalise a critical token so '₦6,450.00' and 'N6450.00' compare equal."""
    t = token.replace("₦", "").replace(",", "").replace(" ", "").replace("–", "-")
    t = re.sub(r"^N(?=\d)", "", t)
    return t.lower()


def extract_critical(text: str) -> list[str]:
    """Return the critical values found in text, in order."""
    return [m.group(0).strip() for m in _CRITICAL_RE.finditer(text)]


@dataclass
class GuardResult:
    ok: bool
    unsupported: list[str] = field(default_factory=list)
    message: str | None = None  # a code from messages.ENGLISH


def guard_explanation(source_text: str, explanation: str) -> GuardResult:
    """Reject an explanation that introduces numbers not present on the page."""
    source_values = {_norm(v) for v in extract_critical(source_text)}
    # Also allow bare numbers that appear inside a longer source token (e.g. '500' in '500mg').
    source_digits = set(re.findall(r"\d+(?:\.\d+)?", source_text.replace(",", "")))
    unsupported = []
    for value in extract_critical(explanation):
        n = _norm(value)
        bare = re.sub(r"[^\d.]", "", n)
        if n in source_values or (bare and bare in source_digits):
            continue
        unsupported.append(value)
    if unsupported:
        return GuardResult(
            ok=False,
            unsupported=unsupported,
            message="numbers_unconfirmed",
        )
    return GuardResult(ok=True)


@dataclass
class Warning:
    block_index: int
    code: str = "low_confidence"
    word_index: int | None = None  # the word in the line, for number warnings


def confidence_warnings(blocks: list[dict], threshold: float = 0.75) -> list[Warning]:
    """Warnings for blocks the OCR is unsure about (confidence 0-1)."""
    out = []
    for i, b in enumerate(blocks):
        if b.get("confidence", 1.0) < threshold:
            out.append(Warning(i))
    return out


@dataclass
class CellWarning:
    table_index: int
    row: int
    col: int
    code: str = "low_confidence"


def table_warnings(tables: list[dict], threshold: float = 0.75) -> list[CellWarning]:
    """Warnings for table cells the OCR is unsure about (row and column are 0-based)."""
    out = []
    for t_i, t in enumerate(tables):
        for row in t.get("rows", []):
            for c in row:
                if c.get("text") and c.get("confidence", 1.0) < threshold:
                    out.append(CellWarning(t_i, c["row"], c["col"]))
    return out


# ---------- Critical words: numbers, doses, amounts, dates

# Each critical word must reach this on its own; a line average can hide one bad digit.
# PENDING CLINICAL SIGN-OFF (see CLAUDE.md).
CRITICAL_WORD_THRESHOLD = 0.90
# ...or two independent readings (the page and a re-read crop) agree and both reach this.
# PENDING CLINICAL SIGN-OFF (see CLAUDE.md).
TWO_READING_THRESHOLD = 0.80

# Characters OCR produces when it half-reads a digit.
_LOOKALIKES = "OoQDlI|SsBZG@§&"
# At the end of a number fewer count: "5l" (litres) and "2B" (pencil) are real.
_TRAILING = "OoQI|@§&"
_BROKEN_NUMBER_RE = re.compile(
    rf"\d[{re.escape(_LOOKALIKES)}]+\d"        # 5O0, 1l2
    rf"|\d[.,]?[{re.escape(_TRAILING)}]+$"      # 50O, 12.O, 38,75O
    r"|^[@§&]\d"                                # @5 (letters before digits are often real: B12, O2)
)
# A lone symbol where a number belongs ("more than @ in 24 hours", "more than ® in 24"): any
# token of one or two characters with no letter or digit, except punctuation that really
# sits between numbers ("4 - 6", "1 / 2", "38 ° C") and a currency sign before an amount.
# Not a closed list of symbols: a smudged 8 came back as "®", which no list had (FINDINGS.md).
_NUMBER_PUNCT = set("-–—/+%:.,;()[]'\"×=<>°")
_CURRENCY = set("₦$£€")
_DOSE_WORDS = {
    "than", "every", "take", "times", "x", "daily", "per", "hour", "hours", "hrs", "day", "days", "week", "weeks",
    "tablet", "tablets", "tabs", "capsule", "capsules", "caps", "mg", "mcg", "ml", "g", "kg", "iu", "units", "drops",
    "spoon", "spoons", "teaspoon", "teaspoons", "naira", "kobo",
}


def _core(token: str) -> str:
    return token.strip("()[]{},.;:!\"'")


def _has_digit(token: str) -> bool:
    return any(ch.isdigit() for ch in token)


def number_problem(words: list[str], i: int) -> str | None:
    """'unreadable_number' when a word sits where a number belongs but holds non-digit
    characters (8 read as @, 500 as 5O0); never try to repair it."""
    core = _core(words[i]) or words[i].strip()
    if not core:
        return None
    if _has_digit(core) and _BROKEN_NUMBER_RE.search(core):
        return "unreadable_number"
    symbols = not any(ch.isalnum() for ch in core) and not all(ch in _NUMBER_PUNCT for ch in core)
    if len(core) <= 2 and symbols:
        if all(ch in _CURRENCY for ch in core) and i + 1 < len(words) and _has_digit(words[i + 1]):
            return None  # "₦ 15,000"
        near = words[max(0, i - 2):i] + words[i + 1:i + 3]
        if any(_has_digit(n) or _core(n).lower() in _DOSE_WORDS for n in near):
            return "unreadable_number"
    return None


def _line_words(line: dict) -> list[dict]:
    words = line.get("words") or []
    if words:
        return [{"text": w["text"], "confidence": _own_confidence(w), "reread_text": w.get("reread_text"),
                 "reread_confidence": w.get("reread_confidence")} for w in words]
    return [{"text": w, "confidence": line.get("confidence", 1.0), "reread_text": None, "reread_confidence": None}
            for w in line.get("text", "").split()]


def _own_confidence(w: dict) -> float:
    """A word's own confidence. A number behind one sign ("₦8,000.00" read "#8,000.00": Tesseract
    doesn't know ₦) is scored by its digits read alone, when they read as the same number
    (reader.reread_numbers): the sign is not the number. Its second, cropped reading must still
    agree, and every threshold is unchanged."""
    conf = w.get("confidence", 1.0)
    alone = w.get("digits_text")
    if alone and _number(alone) == _number(w["text"]):
        return max(conf, w.get("digits_confidence") or 0.0)
    return conf


def number_accepted(w: dict, threshold: float = CRITICAL_WORD_THRESHOLD,
                    pair_threshold: float = TWO_READING_THRESHOLD) -> bool:
    """One reading at `threshold`, or two agreeing independent readings at `pair_threshold`."""
    if w["confidence"] >= threshold:
        return True
    reread = w.get("reread_text")
    return (reread is not None and _number(reread) == _number(w["text"])
            and w["confidence"] >= pair_threshold and (w.get("reread_confidence") or 0) >= pair_threshold)


_MONTHS = {"jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec", "january",
           "february", "march", "april", "june", "july", "august", "september", "october", "november", "december"}
# Letters OCR gives for a whole number it half-read ("02" as "OZ", "10" as "lO").
_ALL_LOOKALIKE = set(_LOOKALIKES) | set("zZ")
_REAL_SHORT = {"is", "so", "do", "go", "oz", "os", "io", "sos", "dog", "god", "zoo", "boss", "glob", "bid", "lbs"}


def letters_for_number(words: list[dict], i: int, threshold: float = CRITICAL_WORD_THRESHOLD) -> bool:
    """A low-confidence word made only of digit look-alikes beside a number or a month name:
    "OZ Sep 2026". It stands where a number belongs, so it is unreadable; never repaired."""
    core = _core(words[i]["text"])
    if not core or len(core) > 4 or words[i]["confidence"] >= threshold:
        return False
    # Right before a month name is where the day goes ("OZ Sep 2026", "oe Sep"): any unsure
    # word of one or two characters there, whatever letters OCR chose.
    if len(core) <= 2 and i + 1 < len(words) and _core(words[i + 1]["text"]).lower() in _MONTHS:
        return True
    if not set(core) <= _ALL_LOOKALIKE:
        return False
    near = [_core(w["text"]) for w in words[max(0, i - 1):i] + words[i + 1:i + 2]]
    if any(n.lower() in _MONTHS for n in near):
        return True
    # Beside a number, only two letters or more that aren't a real word: "I take 2", "2 oz".
    return len(core) >= 2 and core.lower() not in _REAL_SHORT and any(_has_digit(n) for n in near)


NUMBER_CODES = {"unreadable_number", "number_mismatch", "low_confidence_number", "handwritten_number"}


def letters_not_numbers(warnings: list[Warning], result: dict) -> list[Warning]:
    """On a Hausa, Yorùbá or Igbo page, a digit inside a word is an unclear letter
    (letters.digit_in_word, marked "unclear_letter"): it gets no number warning, so it is
    never read as a number. Numbers standing alone keep every check."""
    letter_words = {(m["block_index"], m["word_index"]) for m in result.get("letter_marks") or []
                    if m.get("kind") == "unclear_letter"}
    return [w for w in warnings if not (w.code in NUMBER_CODES and (w.block_index, w.word_index) in letter_words)]


def number_warnings(lines: list[dict], threshold: float = CRITICAL_WORD_THRESHOLD) -> list[Warning]:
    """One warning per critical word that is unreadable, read differently by its second
    (cropped) reading, or not confident enough: below 0.90, unless both readings agree and
    each reaches 0.80."""
    out = []
    for i, line in enumerate(lines):
        words = _line_words(line)
        texts = [w["text"] for w in words]
        # Handwriting: one confident reading is never enough (handwriting.py).
        hand = line.get("script") == "handwritten"
        for j, w in enumerate(words):
            problem = number_problem(texts, j)
            if problem is None and not _has_digit(w["text"]) and letters_for_number(words, j, threshold):
                problem = "unreadable_number"
            if problem is None and _has_digit(w["text"]):
                if w["reread_text"] is not None and _number(w["reread_text"]) != _number(w["text"]):
                    problem = "number_mismatch"  # the two readings disagree: never pick one
                elif hand and not number_accepted(w, threshold=2.0):  # two agreeing readings only
                    problem = "low_confidence_number"
                elif not number_accepted(w, threshold):
                    problem = "low_confidence_number"
            if problem:
                out.append(Warning(i, code=problem, word_index=j))
    return out


def cell_number_warnings(tables: list[dict], threshold: float = CRITICAL_WORD_THRESHOLD) -> list[CellWarning]:
    out = []
    for t_i, t in enumerate(tables):
        for row in t.get("rows", []):
            for c in row:
                texts = c.get("text", "").split()
                problem = next((p for j in range(len(texts)) if (p := number_problem(texts, j))), None)
                if problem is None and any(_has_digit(w) for w in texts) and c.get("confidence", 1.0) < threshold:
                    problem = "low_confidence_number"
                if problem:
                    out.append(CellWarning(t_i, c["row"], c["col"], code=problem))
    return out


def _number(token: str) -> str:
    """A number as it would be spoken: its digits and decimal point, without thousands
    commas. Two readings agree only if these match: "999" and "9.99" have the same digits
    but are not the same amount (a statement's 9.99 was accepted as 999, docs/FINDINGS.md)."""
    core = re.sub(r"[^\d.,:/-]", "", token).strip(".,:/-")
    return re.sub(r",(?=\d{3}\b)", "", core)  # other commas stay: "5,00" may be 5.00


def _digits(token: str) -> str:
    return re.sub(r"\D", "", token)


def number_mismatches(first: dict, second: dict, scale: float = 1.5) -> tuple[list[Warning], list[CellWarning]]:
    """Compare every number between two OCR passes of the same photo. A number that
    the passes disagree on is flagged; the first reading is never replaced."""
    found: list[tuple[str, tuple]] = []  # (digits, where) from the first pass
    for i, line in enumerate(first.get("lines", [])):
        found += [(_number(w), ("line", i)) for w in line.get("text", "").split() if _has_digit(w)]
    for t_i, t in enumerate(first.get("tables", [])):
        for row in t.get("rows", []):
            for c in row:
                found += [(_number(w), ("cell", t_i, c["row"], c["col"])) for w in c.get("text", "").split() if _has_digit(w)]

    others: dict[str, list[int]] = {}  # digits -> tops (first-pass scale) in the second pass
    for line in second.get("lines", []):
        for w in line.get("text", "").split():
            if _has_digit(w):
                others.setdefault(_number(w), []).append(int(line.get("top", 0) / scale))
    for t in second.get("tables", []):
        for row in t.get("rows", []):
            for c in row:
                for w in c.get("text", "").split():
                    if _has_digit(w):
                        others.setdefault(_number(w), []).append(int(t.get("top", 0) / scale))

    flagged: set[tuple] = set()
    for digits, where in found:
        if others.get(digits):
            others[digits].pop()
        else:
            flagged.add(where)
    # Numbers only the second pass saw belong to the nearest first-pass line.
    lines = first.get("lines", [])
    for tops in others.values():
        for top in tops:
            if lines:
                nearest = min(range(len(lines)), key=lambda i: abs(lines[i].get("top", 0) - top))
                flagged.add(("line", nearest))

    line_out, cell_out = [], []
    for where in sorted(flagged, key=str):
        if where[0] == "line":
            line_out.append(Warning(where[1], code="number_mismatch"))
        else:
            _, t_i, r, c = where
            cell_out.append(CellWarning(t_i, r, c, code="number_mismatch"))
    return line_out, cell_out


def line_end_warnings(lines: list[dict]) -> list[Warning]:
    """Lines whose ink carries on past the recognised text: the end was not read."""
    return [Warning(i, code="line_end_unclear") for i, l in enumerate(lines) if l.get("end_unclear")]


def handwritten_health(result: dict) -> tuple[list[Warning], list[str]]:
    """A health paper's handwritten lines: none of their numbers is read (a handwritten dose
    is never guessed) and the page asks for the pharmacist or nurse. PENDING CLINICAL
    SIGN-OFF (Dr. Amos; docs/review/handwriting_signoff.md)."""
    out = []
    hand = [i for i, l in enumerate(result.get("lines", [])) if l.get("script") == "handwritten"]
    for i in hand:
        for j, w in enumerate(_line_words(result["lines"][i])):
            if _has_digit(w["text"]):
                out.append(Warning(i, code="handwritten_number", word_index=j))
    return out, (["handwritten_prescription"] if hand else [])


def line_part_warnings(lines: list[dict]) -> list[Warning]:
    """Lines with print in their row that no word covers: part of the line was not read."""
    return [Warning(i, code="line_part_unclear") for i, l in enumerate(lines) if l.get("part_unclear")]


# ---------- Money pages from a photo: no partial amounts

# 45,250.50 | 7.50 | ₦2,000 | N2,000.00 (a currency sign or letter, then digits)
_AMOUNT = re.compile(r"(?<![\d/.:-])[₦N#]?\d{1,3}(?:,\d{3})+(?:\.\d{2})?(?![\d/:])|(?<![\d/.:-])[₦N#]?\d+\.\d{2}(?![\d/:])")
_DATE = re.compile(r"\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b"
                   r"|\b\d{1,2}[-/ ]?(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-/ ,]*\d{2,4}\b", re.I)


def money_photo_check(result: dict) -> dict:
    """A money page read from a photo (or a scanned PDF page) whose amounts aren't all
    reliable is not read in part. A statement photo lost amounts with no warning at all
    (docs/FINDINGS.md), so the page is unreliable when any of these holds:
      - the print was too small or faint (tip small_print, or a faint region);
      - any line or table cell has a warning;
      - a dated row has no amount, or fewer amounts than the page's other dated rows (what a
        silently dropped amount looks like).
    Then the reading starts with money_amounts_unreliable and reading_incomplete, and keeps
    only the lines and rows that passed every check; dated rows short of an amount go too."""
    lines, tables = result.get("lines", []), result.get("tables", [])
    flagged = {w["block_index"] for w in result.get("warnings", [])}
    bad_rows = {(w["table_index"], w["row"]) for w in result.get("cell_warnings", [])}
    # Rows as they sit on the page: OCR often splits a statement row into column blocks
    # (the date, the description, each amount), so lines at the same height are one row.
    rows: list[list[int]] = []
    for i in sorted(range(len(lines)), key=lambda i: lines[i].get("top", 0)):
        top, h = lines[i].get("top", 0), max(lines[i].get("height", 0), 1)
        mid = top + h / 2
        if rows:
            last = lines[rows[-1][0]]
            if abs(mid - (last.get("top", 0) + max(last.get("height", 0), 1) / 2)) <= max(h, last.get("height", 0), 1) / 2:
                rows[-1].append(i)
                continue
        rows.append([i])
    text = lambda row: " ".join(lines[i].get("text", "") for i in sorted(row, key=lambda i: lines[i].get("left", 0)))  # noqa: E731
    dated = [row for row in rows if _DATE.search(text(row))]
    counts = [len(_AMOUNT.findall(text(row))) for row in dated]
    usual = max(set(counts), key=counts.count) if counts else 0
    short = {i for row, n in zip(dated, counts) if n == 0 or n < usual for i in row}
    # A receipt screenshot has one date line with no amount on it ("Date: 27 Oct 2026, 11:47"):
    # that is not a statement row missing its amount. With two dated rows or more it is.
    if result.get("screenshot") and len(dated) < 2:
        short = set()
    unreliable = ("small_print" in result.get("tips", []) or bool(result.get("faint_regions"))
                  or bool(flagged) or bool(bad_rows) or bool(short))
    if not unreliable:
        return result
    keep = [l for i, l in enumerate(lines) if i not in flagged and i not in short]
    kept_tables = []
    for t_i, t in enumerate(tables):
        rows = [r for r_i, r in enumerate(t.get("rows", [])) if (t_i, r_i) not in bad_rows]
        if rows:
            kept_tables.append({**t, "rows": rows})
    tips = [t for t in result.get("tips", []) if t not in ("money_amounts_unreliable", "reading_incomplete")]
    return {**result, "lines": keep, "tables": kept_tables, "warnings": [], "cell_warnings": [],
            "tips": ["money_amounts_unreliable", "reading_incomplete", *tips], "incomplete": True,
            "left_out": len(lines) - len(keep) + sum(len(t.get("rows", [])) for t in tables)
            - sum(len(t["rows"]) for t in kept_tables)}
