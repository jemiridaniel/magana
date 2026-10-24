"""Health and money papers: no model explanations, only approved phrase templates.

Each line (split into sentences) is matched against the English forms of the templates in
content/templates/. A match is said with the template's translation, its number slots
filled with the page's exact text: no model ever writes a number, dose or unit here.
Only approved translations are used: clinically_approved for health; native_reviewed or
clinically_approved for money and letters. Anything else is read in English as printed,
followed by "I can't translate this line safely…" (the app words the code).
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from functools import lru_cache

from .placeholders import content_dir

STATUSES = ("draft", "native_reviewed", "clinically_approved")
USABLE = {
    "health": {"clinically_approved"},
    "money": {"native_reviewed", "clinically_approved"},
}
# Which templates and fallback line each paper mode uses (letters may hold amounts).
MODE_DOMAIN = {"health": "health", "money": "money", "letter": "money"}
FALLBACK = {"health": "cant_translate_line_health", "money": "cant_translate_line_money"}

SLOT = re.compile(r"\{([a-z])\}")
# A slot takes one number token exactly as printed: 1, 500, 12.5, 1,000, 08/2027.
_SLOT_VALUE = r"(\d+(?:,\d{3})*(?:\.\d+)?(?:/\d+)?)"


@dataclass(frozen=True)
class Template:
    id: str
    domain: str
    patterns: tuple[re.Pattern, ...]
    translations: dict  # lang -> {"text", "status"}


def _pattern(form: str) -> re.Pattern:
    r"""'Store below {a}°C' -> Store\s+below\s+(?P<a>…)\s?°C, whole-sentence, any case."""
    out = []
    for i, part in enumerate(SLOT.split(form)):
        if i % 2:
            out.append(f"(?P<{part}>{_SLOT_VALUE[1:-1]})")
        else:
            lit = re.escape(part)
            out.append(lit.replace("\\ ", r"\s+").replace("°", r"\s?°"))
    return re.compile("".join(out), re.IGNORECASE)


@lru_cache(maxsize=1)
def load() -> tuple[Template, ...]:
    out = []
    for path in sorted((content_dir() / "templates").glob("*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        for t in doc["templates"]:
            out.append(Template(t["id"], doc["domain"], tuple(_pattern(f) for f in t["en"]), t["translations"]))
    return tuple(out)


def _sentences(line: str) -> list[str]:
    return [s for s in re.split(r"(?<=[.;!?])\s+", line.strip()) if s]


def _bare(sentence: str) -> str:
    return re.sub(r"\s+", " ", sentence.strip()).rstrip(".:;!? ")


def match(sentence: str, lang: str, domain: str, statuses: set[str]) -> tuple[str, str] | None:
    """(template id, translated text) if an approved template matches the whole sentence."""
    bare = _bare(sentence)
    for t in load():
        if t.domain != domain:
            continue
        tr = t.translations.get(lang)
        if not tr or tr["status"] not in statuses:
            continue
        for p in t.patterns:
            m = p.fullmatch(bare)
            if m:
                return t.id, SLOT.sub(lambda s: m.group(s.group(1)), tr["text"])
    return None


def translate(text: str, lang: str, mode: str, statuses: set[str] | None = None) -> dict:
    """The paper, sentence by sentence: a translation from an approved template, or the
    English as printed with the fallback code. [statuses] is for benchmarks only."""
    domain = MODE_DOMAIN[mode]
    usable = USABLE[domain] if statuses is None else statuses
    lines = []
    for line in text.splitlines():
        for sentence in _sentences(line):
            if lang == "en":
                lines.append({"source": sentence, "text": sentence, "template": None})
                continue
            # The whole sentence first ("Expiry date: 08/2027"), then its parts around a
            # colon ("Adults and children over 12 years: take 1 to 2 tablets …").
            found = match(sentence, lang, domain, usable)
            parts = [sentence] if found or ":" not in sentence else re.split(r"(?<=:)\s+", sentence)
            for part in parts:
                hit = found if part is sentence else match(part, lang, domain, usable)
                lines.append({"source": part, "text": hit[1] if hit else None,
                              "template": hit[0] if hit else None})
    return {"lines": lines, "fallback": None if lang == "en" else FALLBACK[domain]}
