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
# A lone symbol where a number belongs ("more than @ in 24 hours").
_NUMBER_SYMBOLS = set("@§#&?*~")
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
    if len(core) <= 2 and all(ch in _NUMBER_SYMBOLS for ch in core):
        near = words[max(0, i - 2):i] + words[i + 1:i + 3]
        if any(_has_digit(n) or _core(n).lower() in _DOSE_WORDS for n in near):
            return "unreadable_number"
    return None


def _line_words(line: dict) -> list[dict]:
    words = line.get("words") or []
    if words:
        return [{"text": w["text"], "confidence": w.get("confidence", 1.0), "reread_text": w.get("reread_text"),
                 "reread_confidence": w.get("reread_confidence")} for w in words]
    return [{"text": w, "confidence": line.get("confidence", 1.0), "reread_text": None, "reread_confidence": None}
            for w in line.get("text", "").split()]


def number_accepted(w: dict, threshold: float = CRITICAL_WORD_THRESHOLD,
                    pair_threshold: float = TWO_READING_THRESHOLD) -> bool:
    """One reading at `threshold`, or two agreeing independent readings at `pair_threshold`."""
    if w["confidence"] >= threshold:
        return True
    reread = w.get("reread_text")
    return (reread is not None and _digits(reread) == _digits(w["text"])
            and w["confidence"] >= pair_threshold and (w.get("reread_confidence") or 0) >= pair_threshold)


def number_warnings(lines: list[dict], threshold: float = CRITICAL_WORD_THRESHOLD) -> list[Warning]:
    """One warning per critical word that is unreadable, read differently by its second
    (cropped) reading, or not confident enough: below 0.90, unless both readings agree and
    each reaches 0.80."""
    out = []
    for i, line in enumerate(lines):
        words = _line_words(line)
        texts = [w["text"] for w in words]
        for j, w in enumerate(words):
            problem = number_problem(texts, j)
            if problem is None and _has_digit(w["text"]):
                if w["reread_text"] is not None and _digits(w["reread_text"]) != _digits(w["text"]):
                    problem = "number_mismatch"  # the two readings disagree: never pick one
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


def _digits(token: str) -> str:
    return re.sub(r"\D", "", token)


def number_mismatches(first: dict, second: dict, scale: float = 1.5) -> tuple[list[Warning], list[CellWarning]]:
    """Compare every number between two OCR passes of the same photo. A number that
    the passes disagree on is flagged; the first reading is never replaced."""
    found: list[tuple[str, tuple]] = []  # (digits, where) from the first pass
    for i, line in enumerate(first.get("lines", [])):
        found += [(_digits(w), ("line", i)) for w in line.get("text", "").split() if _has_digit(w)]
    for t_i, t in enumerate(first.get("tables", [])):
        for row in t.get("rows", []):
            for c in row:
                found += [(_digits(w), ("cell", t_i, c["row"], c["col"])) for w in c.get("text", "").split() if _has_digit(w)]

    others: dict[str, list[int]] = {}  # digits -> tops (first-pass scale) in the second pass
    for line in second.get("lines", []):
        for w in line.get("text", "").split():
            if _has_digit(w):
                others.setdefault(_digits(w), []).append(int(line.get("top", 0) / scale))
    for t in second.get("tables", []):
        for row in t.get("rows", []):
            for c in row:
                for w in c.get("text", "").split():
                    if _has_digit(w):
                        others.setdefault(_digits(w), []).append(int(t.get("top", 0) / scale))

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
