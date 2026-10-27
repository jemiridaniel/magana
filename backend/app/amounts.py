"""Money amounts said only when two separate readings agree (the app's rule, app/lib/amount_check.dart).
On WhatsApp there is no phone reading, so the second reading comes from a second engine on the
server: RapidOCR (PaddleOCR's PP-OCR models on ONNX Runtime) next to Tesseract (second_ocr.py).

- Both readings hold the amount exactly, sign included: said as printed. "Naira" is only ever
  said for a "₦" both readings read (spoken.py says "₦" as naira; "#" and "N" stay as printed).
- The digits (commas and decimal point included) agree but the sign doesn't, or both read an
  unlikely sign ("₩", "¥": a misread "₦"): the digits, then "I can't read the currency sign
  clearly" (code currency_unclear).
- Otherwise, or with no second reading: "I can't read the amount clearly" (amount_unconfirmed).
The first reading is never changed: amounts are only held back.
"""
from __future__ import annotations

import re
import unicodedata

_DIGITS = r"(\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2}|\d+)"
_SIGN_WORDS = {"₦", "NGN", "N", "#"}
# Signs an amount on a Nigerian paper may really have; any other is a misread sign.
LIKELY_SIGNS = {"", "₦", "NGN", "N", "#", "$", "£", "€"}


def _is_currency(s: str) -> bool:
    return len(s) == 1 and unicodedata.category(s) == "Sc"


def is_sign_word(word: str) -> bool:
    w = word.strip()
    return w in _SIGN_WORDS or _is_currency(w)


def amount_in(word: str, sign: str | None = None) -> tuple[str, str] | None:
    """(sign, digits) of the amount [word] holds as printed, with [sign] a sign word just before
    it ("NGN 8,000.00"), or None. Plain numbers ("2026", "0123456789") are not amounts."""
    w = re.sub(r"^[(\[]+|[.,;:)\]]+$", "", word)
    m = re.fullmatch(r"(NGN|N|#|[^\d\s])?" + _DIGITS, w)  # a sign is never a digit
    if not m:
        return None
    own, digits = m.group(1), m.group(2)
    if own is not None and own not in _SIGN_WORDS and not _is_currency(own):
        return None  # "A500", "x2": not a sign
    s = own if own is not None else sign
    plain = "," not in digits and "." not in digits
    if (s is None and plain) or (s == "N" and plain):
        return None  # "N5": a code or a room, not an amount
    return (s or "", digits)


def _words(line: dict) -> list[str]:
    return [w["text"] for w in line.get("words") or []] or line.get("text", "").split()


def amounts(lines: list[dict]) -> list[tuple[int, int, str, str]]:
    """(line index, word index, sign, digits) for each amount on the page."""
    out = []
    for i, line in enumerate(lines):
        words = _words(line)
        for j, w in enumerate(words):
            sign = words[j - 1].strip() if j and is_sign_word(words[j - 1]) else None
            if (a := amount_in(w, sign)) is not None:
                out.append((i, j, *a))
    return out


def confirm(lines: list[dict], second: list[str] | None) -> list[dict]:
    """Warnings (block_index, word_index, code) for the amounts in [lines] that [second] (the
    second engine's lines of text, None if there is none) doesn't confirm. Each of the second
    reading's amounts confirms one of the first's: exactly first, then by digits alone."""
    spots = amounts(lines)
    if not spots:
        return []
    exact: dict[tuple[str, str], int] = {}
    digits: dict[str, int] = {}
    for _, _, s, d in amounts([{"text": t} for t in second or []]):
        exact[(s, d)] = exact.get((s, d), 0) + 1
        digits[d] = digits.get(d, 0) + 1
    out, pending = [], []
    for i, j, s, d in spots:
        if exact.get((s, d), 0) > 0:
            exact[(s, d)] -= 1
            digits[d] -= 1
            if s not in LIKELY_SIGNS:
                out.append({"block_index": i, "word_index": j, "code": "currency_unclear"})
        else:
            pending.append((i, j, d))
    for i, j, d in pending:
        if digits.get(d, 0) > 0:
            digits[d] -= 1
            out.append({"block_index": i, "word_index": j, "code": "currency_unclear"})
        else:
            out.append({"block_index": i, "word_index": j, "code": "amount_unconfirmed"})
    return out


def digits_of(word: str, sign: str | None = None) -> str:
    """The digits of the amount in [word], for "8,000.00 [I can't read the currency sign clearly]"."""
    a = amount_in(word, sign)
    return a[1] if a else word
