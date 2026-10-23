"""Safety layer: every AI output passes through here before a user hears it.

Two core rules from the Magana design:
1. Critical values (numbers, money, doses, dates, percentages, ranges) are read
   verbatim from the page. If a model-generated explanation contains a critical
   value that is not on the page, the explanation is rejected.
2. Low-confidence text is never read as if it were certain: it gets a spoken
   warning instead.
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
    message: str = ""


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
            message="I can't confirm some numbers in this explanation, so I'll read the page exactly instead.",
        )
    return GuardResult(ok=True)


@dataclass
class Warning:
    block_index: int
    spoken: str


def confidence_warnings(blocks: list[dict], threshold: float = 0.75) -> list[Warning]:
    """Spoken warnings for blocks the OCR is unsure about (confidence 0-1)."""
    out = []
    for i, b in enumerate(blocks):
        if b.get("confidence", 1.0) < threshold:
            label = b.get("label") or f"line {i + 1}"
            out.append(Warning(i, f"I'm not sure about {label}. Please check it or retake the photo."))
    return out
