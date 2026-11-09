"""Explain's text checks: no model is called here (backend/llm/natlas_guard.py is the only way
to N-ATLaS; docs/LLM_SAFETY.md).

Only schoolwork reaches the model, and never its numbers: every number, with its unit or
currency, is replaced by a placeholder (⟦N1⟧ …) first. An answer is spoken only if every
placeholder appears exactly once, none is made up or mangled ("[N1]", "⟦Nl⟧"), and no digit,
number word, unit word or arithmetic was added (placeholders.py); then the page's exact text is
put back and the guard's answer checks run (natlas_guard.answer_problem). Page text is data,
never instructions (rule 6): it is fenced in <page> tags and stripped of the model's control
tokens.
"""
from __future__ import annotations

import re

from . import language, placeholders

# The page text Magana accepts for one explanation (several sections).
MAX_SOURCE_CHARS = 12_000

# The model card's context ("8,092 tokens", probably 8,192; the config allows more). One
# section must leave room for the system prompt (~400 tokens) and the answer.
CONTEXT_TOKENS = 8_092

ANSWER_TOKENS = 700

# Llama 3's tokenizer needs about 2 characters per token for Yorùbá with tone marks, so a
# 6,000-character section stays near 3,000 tokens in any of the four languages.
SECTION_CHARS = 6_000

LANGUAGE_NAMES = {"en": "English", "ha": "Hausa", "yo": "Yorùbá", "ig": "Igbo"}


_CONTROL = re.compile(r"<\|[^|>]{0,40}\|>")


def clean_page(text: str) -> str:
    """Page text as data: no model control tokens, and it can't close its own fence."""
    return _CONTROL.sub(" ", text).replace("</page>", "</ page>").replace("<page>", "< page>")


def user_prompt(section: str, part: tuple[int, int], markers: list[str] | None = None) -> str:
    """The one task, explain_page: no question and no other style ever reaches the model."""
    n, total = part
    where = f" This is part {n} of {total} of the page." if total > 1 else ""
    keep = f" Use each of these markers exactly once: {' '.join(markers)}." if markers else ""
    return f"<page>\n{clean_page(section)}\n</page>\n\nExplain what this page says.{where}{keep}"


def sections(text: str, size: int = SECTION_CHARS) -> list[str]:
    """Whole lines per section where possible; an over-long line is cut at a space."""
    out: list[str] = []
    current = ""
    for line in text.splitlines():
        while len(line) > size:
            cut = line.rfind(" ", 0, size)
            cut = cut if cut > 0 else size
            out.append(line[:cut])
            line = line[cut:].lstrip()
        if current and len(current) + 1 + len(line) > size:
            out.append(current)
            current = line
        else:
            current = f"{current}\n{line}" if current else line
    if current.strip():
        out.append(current)
    return out


_LIST_NUMBER = re.compile(r"^(\s*)(\d+)[.)](?=\s)", re.MULTILINE)


def bullets(answer: str) -> str:
    """The model's own list numbering ("1.", "2)" at the start of a line) becomes "•", but
    only when it is one plain sequence 1, 2, 3 … Anything else is left for the check to
    refuse: "1. … 3." or "2. … 3." could be numbers about the page."""
    found = [int(m.group(2)) for m in _LIST_NUMBER.finditer(answer)]
    if not found or found != list(range(1, len(found) + 1)):
        return answer
    return _LIST_NUMBER.sub(lambda m: f"{m.group(1)}•", answer)


def check_answer(raw: str, page: "placeholders.Masked", asked: "placeholders.Masked | None",
                 lang: str, allow_left_out: bool = True) -> tuple[str, list]:
    """(the answer with the page's exact text put back, its problems). Each marker may appear
    at most once. Markers left out are not a problem when [allow_left_out]: nothing numeric
    was added (left_out() tells the caller to point to the page)."""
    raw = bullets(raw)
    n_page = len(page.slots)
    n_asked = len(asked.slots) if asked else 0
    problems = placeholders.check(raw, page.text + "\n" + (asked.text if asked else ""),
                                  required=range(1, n_page + 1),
                                  optional=range(n_page + 1, n_page + n_asked + 1), lang=lang)
    if allow_left_out:
        problems = [p for p in problems if p.code != "placeholder_missing"]
    if (other := language.wrong_language(raw, lang)) is not None:
        problems.append(placeholders.Problem("wrong_language", other))
    if problems:
        return raw, problems
    return placeholders.unmask(raw, page.slots + (asked.slots if asked else [])), []


def left_out(raw: str, page: "placeholders.Masked") -> bool:
    """Some of the page's markers are not in the answer."""
    used = {int(m.group(1)) for m in placeholders.PLACEHOLDER.finditer(raw)}
    return any(n not in used for n in range(1, len(page.slots) + 1))
