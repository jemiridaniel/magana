#!/usr/bin/env python3
"""Apply a reviewed copy of docs/review/amos-health-words.xlsx (made by export_health_word_review.py)
to content/llm_safety/topics.json and answer_checks.json.

    backend/.venv/bin/python -I scripts/import_health_word_review.py <reviewed.xlsx> [--reviewer "Dr. Amos"] [--date 2026-11-17]

The reviewed file is read, never changed; docs/review/ is not touched (re-run the export after).
English tab only: Add rows go on their list, Remove rows come off it, and each row's note is kept in
the file's "_notes" (list -> word -> note; the guard ignores keys starting with "_"). Hausa,
Yorùbá and Igbo rows are applied the same way when a reviewer changed them.

Where a row goes:
- "Health: strong" / "Health: ordinary" -> topics.json <lang>.health.strong / .words
- "Medicine name" -> answer_checks.json medicines
- "Dose word" -> dose_words.<lang>; but short shorthand (SHORTHAND, e.g. "sos", "iu") goes to
  dose_abbreviations, where it counts only next to a number or a dose form, as the reviewer's
  note asks ("only next to a number/form"). A shorthand is never also on the plain list.
- "Dose shorthand" -> dose_abbreviations.en; "Dose form" -> dose_forms.en
A word already on its list is not added twice. The same word on two lists is kept when the lists
do different jobs (e.g. "pill" as a health topic word and as a dose form).
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[1]
TOPICS = ROOT / "content/llm_safety/topics.json"
CHECKS = ROOT / "content/llm_safety/answer_checks.json"
LANGS = {"English": "en", "Hausa": "ha", "Yorùbá": "yo", "Igbo": "ig"}
# Short dose words that are also ordinary words, letters or Roman numerals: matched only next to a
# number or a dose form (natlas_guard._dose_patterns), never on their own.
SHORTHAND = re.compile(r"^(?:[a-z]\.){1,4}$|^(?:iv|im|sc|po|ac|pc|hs|qhs|sos|iu|q\d+h)$")


def where(kind: str, word: str, lang: str) -> tuple[str, str]:
    """(file, list path) for a row: e.g. ("topics", "en.health.strong")."""
    if kind == "Health: strong":
        return "topics", f"{lang}.health.strong"
    if kind == "Health: ordinary":
        return "topics", f"{lang}.health.words"
    if kind == "Medicine name":
        return "checks", "medicines"
    if kind == "Dose word":
        return ("checks", f"dose_abbreviations.{lang}") if SHORTHAND.match(word) else ("checks", f"dose_words.{lang}")
    if kind == "Dose shorthand":
        return "checks", f"dose_abbreviations.{lang}"
    if kind == "Dose form":
        return "checks", f"dose_forms.{lang}"
    raise ValueError(f"unknown list {kind!r}")


def _list(doc: dict, path: str) -> list:
    node = doc
    *parents, last = path.split(".")
    for p in parents:
        node = node.setdefault(p, {})
    return node.setdefault(last, [])


def rows(path: Path):
    wb = load_workbook(path, read_only=True)
    for title, lang_col in (("English (Dr. Amos)", False), ("Hausa, Yorùbá, Igbo", True)):
        for r in wb[title].iter_rows(min_row=2, values_only=True):
            if not any(r):
                continue
            lang = LANGS[r[0]] if lang_col else "en"
            kind, word, _use, decision, note = r[1:6] if lang_col else r[0:5]
            if kind == "(new)" or not word:
                continue
            yield lang, kind, str(word).strip(), (decision or "").strip(), (note or "").strip()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("reviewed", type=Path)
    ap.add_argument("--reviewer", default="Dr. Amos")
    ap.add_argument("--date", required=True)
    a = ap.parse_args()
    docs = {"topics": json.loads(TOPICS.read_text(encoding="utf-8")),
            "checks": json.loads(CHECKS.read_text(encoding="utf-8"))}
    added, removed, already, moved = [], [], [], []
    for lang, kind, word, decision, note in rows(a.reviewed):
        if decision not in ("Add", "Remove"):
            continue
        f, path = where(kind, word, lang)
        target = _list(docs[f], path)
        if decision == "Remove":
            if word in target:
                target.remove(word)
                removed.append((path, word))
            continue
        if word in target:
            already.append((path, word))
        else:
            target.append(word)
            added.append((path, word))
            if kind == "Dose word" and path.startswith("dose_abbreviations"):
                moved.append(word)
        if note:
            notes = docs[f].setdefault("_notes", {}).setdefault(path, {})
            text = note + (" (Listed as a dose word; put on the shorthand list: counts only next to a "
                           "number or a dose form.)" if kind == "Dose word" and path.startswith("dose_abbreviations") else "")
            notes[word] = f"{notes[word]} / {text}" if word in notes else f"{a.reviewer}, {a.date}: {text}"
    for f, path in (("topics", TOPICS), ("checks", CHECKS)):
        path.write_text(json.dumps(docs[f], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"added {len(added)}, removed {len(removed)}, already on their list {len(already)}: {already}")
    print(f"dose words put on the shorthand list: {moved}")


if __name__ == "__main__":
    main()
