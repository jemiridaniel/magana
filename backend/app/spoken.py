"""Text a voice can say, with every number spelled out exactly as printed.

The MMS voices used for WhatsApp voice notes drop characters they don't know: the English
voice has the digits 0–6 only, Hausa only 6, Yorùbá none (docs/FINDINGS.md). A dose of 8
would simply vanish. So every number is spelled out in English words first, digit for digit
in meaning ("2,350.00" → "two thousand three hundred and fifty point zero zero"), and
`for_voice` refuses (None) any text that still holds a character the voice can't say: then
no voice note is made and the text message, which is exact, is all the user gets.
"""
from __future__ import annotations

import re
import unicodedata

_ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
         "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
_SCALES = [(10**9, "billion"), (10**6, "million"), (1000, "thousand")]

# 1,234,567.89 | 1234.5 | 08 | 2027
_NUMBER = re.compile(r"(?<![\w])([-+−]?)(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d+))?")
_SYMBOLS = {
    "%": " percent ", "₦": " naira ", "$": " dollars ", "£": " pounds ", "€": " euros ", "°": " degrees ",
    "/": " slash ", "&": " and ", "+": " plus ", "=": " equals ", "×": " times ", "@": " at ",
}
UNCLEAR = "[unclear number]"


def _under_1000(n: int) -> str:
    words = []
    if n >= 100:
        words += [_ONES[n // 100], "hundred"]
        n %= 100
        if n:
            words.append("and")
    if n >= 20:
        words.append(_TENS[n // 10] + (f" {_ONES[n % 10]}" if n % 10 else ""))
    elif n or not words:
        words.append(_ONES[n])
    return " ".join(words)


def integer_words(digits: str) -> str:
    """"2350" → "two thousand three hundred and fifty". A leading zero ("08") or more than 12
    digits (an account number) is read digit by digit, as printed."""
    if (len(digits) > 1 and digits[0] == "0") or len(digits) > 12:
        return " ".join(_ONES[int(d)] for d in digits)
    n = int(digits)
    if n < 1000:
        return _under_1000(n)
    parts = []
    for size, name in _SCALES:
        if n >= size:
            parts.append(f"{_under_1000(n // size)} {name}")
            n %= size
    if n:
        parts.append(("and " if n < 100 else "") + _under_1000(n))
    return " ".join(parts)


def number_words(sign: str, whole: str, fraction: str | None) -> str:
    words = integer_words(whole.replace(",", ""))
    if fraction is not None:
        words += " point " + " ".join(_ONES[int(d)] for d in fraction)
    if sign in ("-", "−"):
        words = "minus " + words
    elif sign == "+":
        words = "plus " + words
    return words


def spell_numbers(text: str) -> str:
    """Every number in [text] in English words; "[unclear number]" stays as words."""
    text = text.replace(UNCLEAR, " unclear number ")
    text = _NUMBER.sub(lambda m: f" {number_words(m.group(1), m.group(2), m.group(3))} ", text)
    # Digits inside a code ("PCM2291", "B12"): one by one.
    return re.sub(r"\d", lambda m: f" {_ONES[int(m.group())]} ", text)


def for_voice(text: str, vocab: set[str]) -> str | None:
    """[text] as the voice can say it, or None if it can't say all of it.

    Numbers become words, a few symbols become words, other punctuation becomes a pause
    (a space). Any letter or digit the voice doesn't know means None: never drop it."""
    text = unicodedata.normalize("NFC", spell_numbers(text))
    for sym, word in _SYMBOLS.items():
        text = text.replace(sym, word)
    out = []
    for ch in text.lower():
        if ch in vocab:
            out.append(ch)
        elif ch.isspace() or unicodedata.category(ch)[0] in "PSZ":
            out.append(" ")  # punctuation and symbols: a pause, nothing lost
        else:
            return None  # a letter, digit or mark the voice would silently skip
    said = re.sub(r"\s+", " ", "".join(out)).strip()
    return said or None
