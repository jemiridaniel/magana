"""Hausa, Yorùbá and Igbo letters the OCR can miss (board 5d; docs/FINDINGS.md, 26 Oct 2026).

Measured on 10 pages per language (benchmark/letters, scripts/letter_ocr_test.py):
- Tesseract `eng` keeps none of ɓ ɗ ƙ ƴ, ẹ ọ ṣ or ị ọ ụ, and read Igbo ọ as "9" 37 times.
- `yor` keeps most Yorùbá dotted letters, and the `Latin` script model keeps Igbo ọ; no model
  keeps Hausa ɓ ɗ ƙ ƴ.
So a page in one of these languages is read again with the better model (`READ_AGAIN`), the
app warns once per page, and words that could be a special-letter word are marked. A word is
never changed: "kaya" may be "ƙaya" (thorn) or really "kaya" (load), and only a person can say.
"""
from __future__ import annotations

import re
import unicodedata
from functools import lru_cache

from .placeholders import content_dir

LANGS = ("ha", "yo", "ig")
SPECIAL = {"ha": "ɓɗƙƴ", "yo": "ẹọṣ", "ig": "ịọụṅ"}
# The Tesseract model to read the page again with, when it reads these letters better.
READ_AGAIN = {"yo": "yor", "ig": "Latin"}
_PLAIN = str.maketrans("ɓɗƙƴ", "bdky")
_TONES = {"̀", "́", "̄"}  # grave, acute, macron: Yorùbá and Igbo tone marks
_WORD = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)*", re.UNICODE)
# A page is in one of the languages when its function words reach this many, and at least
# twice the English ones (accents ignored: the first reading drops them).
MIN_WORDS = 5
MARGIN = 2.0


def plain(word: str) -> str:
    """The word with every accent, dot and hook taken off: what the `eng` model reads."""
    decomposed = unicodedata.normalize("NFD", word.lower())
    return "".join(c for c in decomposed if not unicodedata.combining(c)).translate(_PLAIN)


def untoned(word: str) -> str:
    """The word without tone marks, keeping dotted and hooked letters."""
    decomposed = unicodedata.normalize("NFD", word.lower())
    return unicodedata.normalize("NFC", "".join(c for c in decomposed if c not in _TONES))


@lru_cache(maxsize=1)
def _function_words() -> dict[str, frozenset[str]]:
    out = {}
    for lang in ("en", *LANGS):
        words = set()
        for raw in (content_dir() / "language_words" / f"{lang}.txt").read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if line and not line.startswith(("letters:", "prefix:")):
                words.add(plain(line))
        out[lang] = words
    shared = {w for a in out for b in out if a < b for w in out[a] & out[b]}
    return {k: frozenset(v - shared) for k, v in out.items()}


def page_language(text: str) -> str | None:
    """"ha", "yo" or "ig" when the page is clearly in that language, else None."""
    lists = _function_words()
    counts = dict.fromkeys(lists, 0)
    for token in _WORD.findall(text):
        word = plain(token)
        for lang, words in lists.items():
            if word in words:
                counts[lang] += 1
    best = max(LANGS, key=lambda l: counts[l])
    if counts[best] >= MIN_WORDS and counts[best] >= MARGIN * max(counts["en"], 1):
        return best
    return None


@lru_cache(maxsize=3)
def _index(lang: str) -> dict[str, frozenset[str]]:
    """Plain form -> the list's words with that plain form (each holds a special letter)."""
    out: dict[str, set[str]] = {}
    path = content_dir() / "word_lists" / f"{lang}.txt"
    for raw in path.read_text(encoding="utf-8").splitlines():
        word = raw.strip()
        if word and not word.startswith("#"):
            out.setdefault(plain(word), set()).add(untoned(word))
    return {k: frozenset(v) for k, v in out.items()}


def may_miss_letter(token: str, lang: str) -> bool:
    """True when a listed word spelled like [token] has a special letter [token] lacks."""
    word = _WORD.search(token)
    if not word:
        return False
    found = untoned(word.group())
    return any(candidate != found for candidate in _index(lang).get(plain(found), ()))


def marks(lines: list[dict], lang: str) -> list[dict]:
    """Words that could be a special-letter word: {"block_index", "word_index"}. Numbers and
    words in no list are never marked; nothing is changed."""
    out = []
    for i, line in enumerate(lines):
        words = line.get("words") or [{"text": t} for t in line.get("text", "").split()]
        for j, w in enumerate(words):
            if may_miss_letter(w.get("text", ""), lang):
                out.append({"block_index": i, "word_index": j})
    return out
