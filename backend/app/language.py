"""Is an explanation in the language the learner asked for?

The English-only Magana LoRA answers Hausa, Yorùbá and Igbo requests in English
(docs/FINDINGS.md), and base N-ATLaS can drift too. An answer in the wrong language is
refused like one that fails the number check: the app reads the page instead.

Each answer is scored per language by its common function words and the letters only that
language uses (content/language_words/, DRAFT pending native review). Technical words
("starch", "photosynthesis") and month names stay in English in good answers, so single
words never decide: the answer is refused only when another language clearly outscores the
one asked for.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache

from .placeholders import PLACEHOLDER, content_dir

LANGS = ("en", "ha", "yo", "ig")
# Another language must reach this many points, and twice the asked language's score.
MIN_POINTS = 4
MARGIN = 2.0
_WORD = re.compile(r"[^\W\d_]+(?:[-'’][^\W\d_]+)*", re.UNICODE)


@dataclass(frozen=True)
class Lists:
    words: dict[str, frozenset[str]]
    letters: dict[str, frozenset[str]]
    prefixes: dict[str, tuple[str, ...]]


@lru_cache(maxsize=1)
def _lists() -> Lists:
    words, letters, prefixes = {}, {}, {}
    for lang in LANGS:
        w, l, p = set(), set(), []
        for raw in (content_dir() / "language_words" / f"{lang}.txt").read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("letters:"):
                l |= set(line.removeprefix("letters:").strip())
            elif line.startswith("prefix:"):
                p.append(line.removeprefix("prefix:").strip().lower())
            else:
                w.add(line.lower())
        words[lang], letters[lang], prefixes[lang] = w, l, tuple(p)
    # A word in two lists says nothing about which language it is.
    shared = {x for a in LANGS for b in LANGS if a < b for x in words[a] & words[b]}
    return Lists({k: frozenset(v - shared) for k, v in words.items()}, {k: frozenset(v) for k, v in letters.items()}, prefixes)


def scores(text: str) -> dict[str, int]:
    """Points per language: one per function word, one per word holding a letter or
    beginning only that language uses."""
    lists = _lists()
    text = PLACEHOLDER.sub(" ", text)
    out = dict.fromkeys(LANGS, 0)
    for token in _WORD.findall(text):
        word = token.lower()
        for lang in LANGS:
            if (word in lists.words[lang] or any(ch in lists.letters[lang] for ch in token)
                    or word.startswith(lists.prefixes[lang])):
                out[lang] += 1
    return out


def wrong_language(text: str, lang: str) -> str | None:
    """The language the answer is clearly in instead of [lang], or None if it may be [lang]."""
    if lang not in LANGS:
        return None
    s = scores(text)
    other = max((x for x in LANGS if x != lang), key=lambda x: s[x])
    if s[other] >= MIN_POINTS and s[other] >= MARGIN * max(s[lang], 1):
        return other
    return None
