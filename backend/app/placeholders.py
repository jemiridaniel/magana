"""Numbers out of the model's hands (CLAUDE.md rule 1).

Before schoolwork goes to N-ATLaS, every number on the page, with its unit or currency,
becomes a numbered placeholder: "Take 2 tablets every 4 to 6 hours" ->
"Take ⟦N1⟧ tablets every ⟦N2⟧ to ⟦N3⟧". The model is told to copy each placeholder exactly
once. Its answer is rejected unless:
- every placeholder appears exactly once, and no others;
- no digit or number word appears outside the placeholders, in the answer's language or
  English (content/number_words/, needs native review), unless the page itself has that
  word outside its numbers;
- no unit word stands next to a number (a placeholder, digits or a number word): "kowane
  minti ⟦N1⟧" (every ⟦N1⟧ minutes) is refused, but "Shekara tana da ⟦N1⟧" (a year has …)
  may use "shekara" as an ordinary noun;
- no arithmetic links two placeholders (=, +, -, −, ×, ÷ …).
Only then is each placeholder put back with the page's exact text.

Health and money papers never reach a model at all (templates.py).
"""
from __future__ import annotations

import json
import os
import re
import unicodedata
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

LANGUAGES = ("en", "ha", "yo", "ig")
PLACEHOLDER = re.compile(r"⟦N(\d+)⟧")


def content_dir() -> Path:
    return Path(os.environ.get("MAGANA_CONTENT_DIR", Path(__file__).resolve().parents[2] / "content"))


# ---------- word lists

_HOOKS = str.maketrans({"ɗ": "d", "ƙ": "k", "ɓ": "b", "ƴ": "y", "’": "'", "‘": "'", "ʼ": "'"})


def plain(word: str) -> str:
    """Lower case, no tone marks, under-dots or hooks: 'Méjì' -> 'meji', 'ɗari' -> 'dari'."""
    w = unicodedata.normalize("NFD", word.lower().translate(_HOOKS))
    return unicodedata.normalize("NFC", "".join(c for c in w if unicodedata.category(c) != "Mn"))


def marked(word: str) -> str:
    return unicodedata.normalize("NFC", word.lower().translate(_HOOKS))


@dataclass(frozen=True)
class WordList:
    words: frozenset[str]  # plain forms
    exact: frozenset[str]  # marked forms, matched only with their marks
    units: frozenset[str]  # plain forms (single words)
    unit_phrases: tuple[str, ...]  # plain multi-word units ("per cent")


@lru_cache(maxsize=None)
def word_list(lang: str) -> WordList:
    d = json.loads((content_dir() / "number_words" / f"{lang}.json").read_text(encoding="utf-8"))
    units = [plain(u) for u in d["units"]]
    return WordList(
        words=frozenset(plain(w) for w in d["words"]),
        exact=frozenset(marked(w) for w in d["exact_only"]),
        units=frozenset(u for u in units if " " not in u),
        unit_phrases=tuple(u for u in units if " " in u),
    )


# Letters with any combining marks (Yorùbá "ọ̀sẹ̀" has accents with no precomposed form).
_LETTERS = r"[^\W\d_](?:[^\W\d_]|[\u0300-\u036f])*"
_WORD = re.compile(rf"{_LETTERS}(?:['’-]{_LETTERS})*")
_TOKEN = re.compile(rf"⟦N\d+⟧|\d+(?:[.,]\d+)*|{_LETTERS}(?:['’-]{_LETTERS})*")


def words(text: str) -> list[str]:
    return _WORD.findall(text)


# ---------- masking the page

_MONTH = (r"(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?"
          r"|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?")
_DAY = r"\d{1,2}(?:st|nd|rd|th)?"
_NUM = r"\d+(?:,\d{3})*(?:\.\d+)?(?:\s?/\s?\d+(?:\.\d+)?)?"  # 1,250.50  3/4
_UNIT = (r"(?:°\s?C\b|°|%|per\s?cent\b|degrees?(?:\s+(?:celsius|c)\b)?"
         r"|(?:kwh|mmol/l|g/dl|mg|mcg|ml|kg|km|cm|mm|g|l|m)\b"
         r"|(?:hours?|minutes?|seconds?|days?|weeks?|months?|years?|litres?|liters?|millilitres?"
         r"|metres?|meters?|centimetres?|millimetres?|kilometres?|grams?|milligrams?|kilograms?"
         r"|kilos?|naira|kobo|units?|tablets?|capsules?)\b)")
_CURRENCY = r"(?:₦|\bNGN\s?|\bN(?=\d)|\$|£)"
_EN_NUMBER_WORDS = (r"\b(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen"
                    r"|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty"
                    r"|sixty|seventy|eighty|ninety|hundred|thousand|million|billion|half|quarter"
                    r"|first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|twice|dozen)\b")

# Leftmost-first alternation: the longer, more specific forms come first.
_MASK = re.compile(
    "|".join(f"(?:{p})" for p in [
        rf"{_DAY}\s+{_MONTH},?\s+\d{{4}}",                    # 14 November 2026
        rf"{_MONTH}\s+{_DAY},?\s+\d{{4}}",                    # October 3, 2026
        rf"{_MONTH}\s+\d{{4}}",                               # September 2026
        rf"{_DAY}\s+{_MONTH}",                                # 14 Nov
        r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b",                 # 14/10/2026
        r"\b\d{1,2}/\d{4}\b",                                 # 08/2027
        r"\b\d{1,2}:\d{2}(?:\s?[ap]\.?m\.?)?",                # 10:00 a.m.
        rf"{_CURRENCY}\s?{_NUM}(?:\s?{_UNIT})?",              # N6,450.00
        rf"\b{_NUM}\s?[–—-]\s?{_NUM}(?:\s?{_UNIT})?",          # 12.0 – 16.0 g/dL (one range)
        r"\b[^\W\d_]+\d[\w]*|\b\d+[^\W\d_]\w*",               # H2O, OPV0, PCM2291, 8x, 500mg
        rf"\b{_NUM}(?:\s?{_UNIT})?",                          # 4 hours, 7.5%, 30 °C, 186
        rf"{_EN_NUMBER_WORDS}(?:\s+{_UNIT})?",                # two tablets, second
    ]),
    re.IGNORECASE,
)


@dataclass
class Masked:
    text: str
    slots: list[str]  # slot k (1-based) is slots[k-1]: the page's exact text


def mask(text: str, start: int = 1) -> Masked:
    slots: list[str] = []

    def put(m: re.Match) -> str:
        slots.append(m.group(0))
        return f"⟦N{start + len(slots) - 1}⟧"

    return Masked(_MASK.sub(put, text), slots)


def unmask(answer: str, slots: list[str], start: int = 1) -> str:
    return PLACEHOLDER.sub(lambda m: slots[int(m.group(1)) - start], answer)


# ---------- checking the answer

_ARITHMETIC = re.compile(r"⟦N\d+⟧\s*[=+\-−–—×x*÷/]\s*⟦N\d+⟧|⟧\s*=|=\s*⟦", re.IGNORECASE)
_SYMBOLS = re.compile(r"[%₦$£°]")


@dataclass
class Problem:
    code: str  # placeholder_missing | placeholder_repeated | placeholder_unknown | digit |
    #            number_word | unit_word | arithmetic | wrong_language (explain.check_answer)
    detail: str = ""


def check(answer: str, masked_source: str, required: range, optional: range = range(0),
          lang: str = "en") -> list[Problem]:
    """Problems with a model answer to a masked page. [required] placeholders must each
    appear exactly once (the page's); [optional] ones at most once (the reader's question)."""
    problems: list[Problem] = []
    seen: dict[int, int] = {}
    for m in PLACEHOLDER.finditer(answer):
        n = int(m.group(1))
        seen[n] = seen.get(n, 0) + 1
    for n in required:
        if seen.get(n, 0) == 0:
            problems.append(Problem("placeholder_missing", f"⟦N{n}⟧"))
    for n, count in seen.items():
        if n not in required and n not in optional:
            problems.append(Problem("placeholder_unknown", f"⟦N{n}⟧"))
        elif count > 1:
            problems.append(Problem("placeholder_repeated", f"⟦N{n}⟧"))
    if _ARITHMETIC.search(answer):
        problems.append(Problem("arithmetic", _ARITHMETIC.search(answer).group(0)))
    rest = PLACEHOLDER.sub(" ", answer)
    for d in re.findall(r"\d+(?:[.,]\d+)*", rest):
        problems.append(Problem("digit", d))
    for s in _SYMBOLS.findall(rest):
        problems.append(Problem("digit", s))

    # Words the page itself prints (outside its numbers) may be repeated.
    on_page_plain = {plain(w) for w in words(masked_source)}
    on_page_marked = {marked(w) for w in words(masked_source)}
    lists = {word_list(lang), word_list("en")}

    def number_word(w: str) -> bool:
        p, mk = plain(w), marked(w)
        return any((mk in lst.exact and mk not in on_page_marked) or (p in lst.words and p not in on_page_plain)
                   for lst in lists)

    # The answer as tokens: placeholders, digit runs and words, so "next to a number" can be seen.
    tokens = _TOKEN.findall(answer)
    numeric = [bool(PLACEHOLDER.fullmatch(t) or t[0].isdigit() or number_word(t)) for t in tokens]
    for i, t in enumerate(tokens):
        if PLACEHOLDER.fullmatch(t) or t[0].isdigit():
            continue
        if number_word(t):
            problems.append(Problem("number_word", t))
            continue
        p = plain(t)
        beside = (i > 0 and numeric[i - 1]) or (i + 1 < len(tokens) and numeric[i + 1])
        if beside and any(p in lst.units for lst in lists) and p not in on_page_plain:
            problems.append(Problem("unit_word", t))
    page_text_plain = " ".join(plain(w) for w in words(masked_source))
    for lst in lists:
        for phrase in lst.unit_phrases:
            if re.search(rf"(⟦⟧|\d)\s*{re.escape(phrase)}\b|\b{re.escape(phrase)}\s*(⟦⟧|\d)",
                         PLACEHOLDER.sub("⟦⟧", answer).lower()) and not re.search(
                    rf"\b{re.escape(phrase)}\b", page_text_plain):
                problems.append(Problem("unit_word", phrase))
    return problems
