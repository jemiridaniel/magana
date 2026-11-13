"""Hausa, Yorùbá and Igbo letters the OCR can miss (board 5d; docs/FINDINGS.md, 26 Oct 2026).

Measured on 10 pages per language (benchmark/letters, scripts/letter_ocr_test.py):
- Tesseract `eng` keeps none of ɓ ɗ ƙ ƴ, ẹ ọ ṣ or ị ọ ụ, and read Igbo ọ as "9" 37 times.
- `yor` keeps most Yorùbá dotted letters, and the `Latin` script model keeps Igbo ọ; no model
  keeps Hausa ɓ ɗ ƙ ƴ.
So a page in one of these languages is read again with the better model (`READ_AGAIN`), the
app warns once per page, and words that could be a special-letter word are marked. A word is
never changed: "kaya" may be "ƙaya" (thorn) or really "kaya" (load), and only a person can say.
Two exceptions on Hausa pages (restore_hausa; Brydl's review, 13 Nov 2026), both still marked:
"đ" is ɗ ("Đ" is Ɗ), a letter Hausa doesn't have; and a capital K in the middle of a sentence
("ta Kungiyar") is ƙ when the ƙ word is in the word list: Tesseract reads the hooked ƙ as K,
and a capital there is otherwise a name.
A digit inside a word on these pages ("uz9" for ụzọ) is an unclear letter, never a number
(digit_in_word); a number standing alone keeps the verbatim rule.
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


# A number with its unit or an ordinal, written as one word ("500mg", "2nd", "10am"): a number.
_NUMBER_WORD = re.compile(r"^\d+(?:[.,]\d+)?(?:mg|mcg|ml|l|g|kg|km|cm|mm|m|am|pm|st|nd|rd|th|h|hr|hrs|min|s|x)$", re.I)
_EDGES = "()[]{},.;:!?\"'“”‘’"


def digit_in_word(token: str) -> bool:
    """A digit inside a word made of letters: "uz9", "9zo", "n'9". On these pages that digit
    is an unclear letter, never a number (`eng` read Igbo ọ as "9"). Not "929" (digits only:
    a number), "500mg" or "2nd" (a number with its unit), nor capitals with digits ("SS2",
    "JSS3", "B12", "N500"), which are class levels, vitamins and amounts."""
    for part in re.split(r"[-/–—]", token.strip(_EDGES)):
        if (any(c.isdigit() for c in part) and any(c.isalpha() and c.islower() for c in part)
                and not _NUMBER_WORD.match(part)):
            return True
    return False


_D = str.maketrans({"đ": "ɗ", "Đ": "Ɗ"})
_SENTENCE_END = re.compile(r"[.!?][\"'”’)\]]*$")
_LETTER = re.compile(r"[^\W\d_]")


def _hooked_k(token: str, previous: str | None) -> str | None:
    """[token] with its capital K made ƙ, or None: mid-sentence only (not the line's first word,
    not after . ! ?), the rest of the word in small letters, and the ƙ word in the list.
    [previous] is the nearest earlier word with a letter in it: a heading's "== Kuruciya ==" or
    a list's "• Kasar" starts its line (Brydl's review: "== Kuruciya ==" was changed)."""
    if previous is None or _SENTENCE_END.search(previous):
        return None
    m = _WORD.search(token)
    if not m or len(m.group()) < 2 or m.group()[0] != "K" or m.group()[1:] != m.group()[1:].lower():
        return None
    hooked = "ƙ" + m.group()[1:]
    if untoned(hooked) not in _index("ha").get(plain(hooked), ()):
        return None
    return token[: m.start()] + hooked + token[m.end():]


def restore_hausa(lines: list[dict]) -> None:
    """Hausa pages, in place: "đ"/"Đ" become ɗ/Ɗ, and a mid-sentence capital K becomes ƙ where
    the ƙ word is listed (_hooked_k). Each changed word's index goes in the line's
    "restored_words", and marks() marks it: a person should still check it."""
    for line in lines:
        words = line.get("words") or []
        tokens = [w.get("text", "") for w in words] if words else line.get("text", "").split()
        new = [t.translate(_D) for t in tokens]
        changed = [j for j, (a, b) in enumerate(zip(tokens, new)) if a != b]
        for j in range(len(new)):
            previous = next((new[i] for i in range(j - 1, -1, -1) if _LETTER.search(new[i])), None)
            k = _hooked_k(new[j], previous)
            if k is not None:
                new[j] = k
                changed.append(j)
        if new == tokens:
            continue
        if words:
            for w, text in zip(words, new):
                w["text"] = text
        # The line's text: each word replaced where it stands, spacing kept.
        text, at, out = line.get("text", ""), 0, []
        for old, text_new in zip(tokens, new):
            i = text.find(old, at)
            if i < 0:
                continue
            out.append(text[at:i] + text_new)
            at = i + len(old)
        line["text"] = "".join(out) + text[at:]
        line["restored_words"] = sorted(set(changed))


def marks(lines: list[dict], lang: str) -> list[dict]:
    """Words to check with a person: {"block_index", "word_index", "kind"}. "special_letter":
    a listed word with a special letter has this spelling without it. "unclear_letter": a
    digit inside a word (digit_in_word), which is read as "unclear letter", never as a number.
    Words in no list and numbers standing alone are never marked; nothing is changed."""
    out = []
    for i, line in enumerate(lines):
        words = line.get("words") or [{"text": t} for t in line.get("text", "").split()]
        for j, w in enumerate(words):
            text = w.get("text", "")
            if digit_in_word(text):
                out.append({"block_index": i, "word_index": j, "kind": "unclear_letter"})
            elif j in line.get("restored_words", ()) or may_miss_letter(text, lang):
                out.append({"block_index": i, "word_index": j, "kind": "special_letter"})
    return out
