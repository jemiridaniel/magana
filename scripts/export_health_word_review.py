#!/usr/bin/env python3
"""Explain's health, medicine and dose word lists as a review workbook for Dr. Amos (English) and
native speakers (Hausa, Yorùbá, Igbo): docs/review/amos-health-words.xlsx.

    backend/.venv/bin/python scripts/export_health_word_review.py

Reads content/llm_safety/topics.json (health only) and answer_checks.json; re-run after changing
either. Each row has a Keep / Remove / Add column and a notes column; blank rows at the end of each
tab are for words to add. See docs/LLM_SAFETY.md.
"""
from __future__ import annotations

import json
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.worksheet.datavalidation import DataValidation

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/review/amos-health-words.xlsx"
GREEN, AMBER = "0A6B4B", "FFF1C7"
NAMES = {"ha": "Hausa", "yo": "Yorùbá", "ig": "Igbo"}
USE = {
    "strong": "Health topic, strong: one on a page is enough to stop the explanation (\"Please ask your teacher\").",
    "words": "Health topic, ordinary: two different ones on a page stop the explanation.",
    "medicine": "Medicine name: an explanation that names it is never spoken (the page is read instead).",
    "dose": "Dose word: an explanation that uses it is never spoken (the page is read instead).",
}
N_NOTE = ("N stands for any number: digits (6, 0.5), a number word (six) or a range (4 to 6, 4-6). "
          "Examples it catches: {examples}.")
EXAMPLES = {
    "every N hours": "every 6 hours, every six hours, every 4 to 6 hours",
    "every N hour": "every 1 hour, every one hour",
    "every N hrs": "every 8 hrs, every 4-6 hrs",
    "every N hr": "every 1 hr",
    "N-hourly": "8-hourly, 8 hourly, eight-hourly",
    "N times a day": "3 times a day, three times a day, 2 or 3 times a day",
}

THIN = Side(style="thin", color="BBBBBB")
BOX = Border(top=THIN, bottom=THIN, left=THIN, right=THIN)
WRAP = Alignment(wrap_text=True, vertical="top")


def note(term: str) -> str:
    if " N " in f" {term} " or term.startswith("N-"):
        return N_NOTE.format(examples=EXAMPLES.get(term, term.replace("N", "6")))
    return ""


def sheet(ws, title: str, rows: list[list[str]], lang_col: bool, blank_rows: int = 15) -> None:
    ws.title = title
    cols = (["Language"] if lang_col else []) + [
        "List", "Word or phrase", "How Magana uses it", "Keep / Remove / Add", "Notes or suggested change"]
    ws.append(cols)
    for c in ws[1]:
        c.font = Font(bold=True, color="FFFFFF", size=12)
        c.fill = PatternFill("solid", fgColor=GREEN)
        c.alignment = Alignment(vertical="center", wrap_text=True)
        c.border = BOX
    for r in rows:
        ws.append(r)
    langs = list(NAMES.values())
    for i in range(blank_rows):
        ws.append(([langs[i % 3]] if lang_col else []) +
                  ["(new)", "", "Add a word or phrase that should be on a list.", "Add", ""])
    decision = len(cols) - 1
    dv = DataValidation(type="list", formula1='"Keep,Remove,Add"', allow_blank=True)
    ws.add_data_validation(dv)
    letter = ws.cell(row=1, column=decision).column_letter
    dv.add(f"{letter}2:{letter}{ws.max_row}")
    for i, w in enumerate(([10] if lang_col else []) + [18, 30, 52, 18, 48], 1):
        ws.column_dimensions[ws.cell(row=1, column=i).column_letter].width = w
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.alignment, c.border = WRAP, BOX
        row[decision - 1].fill = PatternFill("solid", fgColor=AMBER)
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions
    ws.print_title_rows = "1:1"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth, ws.page_setup.fitToHeight = 1, 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True


def main() -> None:
    topics = json.loads((ROOT / "content/llm_safety/topics.json").read_text(encoding="utf-8"))
    checks = json.loads((ROOT / "content/llm_safety/answer_checks.json").read_text(encoding="utf-8"))
    wb = Workbook()
    about = wb.active
    about.title = "Read me"
    for text, bold in [
        ("Explain safety word lists: review for Dr. Amos (English) and native speakers (Hausa, Yorùbá, Igbo)", True),
        ("Draft, made by scripts/export_health_word_review.py from content/llm_safety/topics.json and "
         "content/llm_safety/answer_checks.json.", False),
        ("", False),
        ("What these lists do", True),
        ("Explain uses an AI model (N-ATLaS) to explain school pages. It must never explain health or medicine "
         "pages, or put medicine names or doses into an explanation.", False),
        ("1. Before the model: if a page is about health, it isn't sent to the model. The learner hears \"Please ask "
         "your teacher\". One 'strong' word is enough; otherwise two different 'ordinary' words.", False),
        ("2. After the model: an explanation that names a medicine or uses a dose word is never spoken. Magana reads "
         "the page as printed instead.", False),
        ("Matching ignores capitals, tone marks and hooked letters (ɓ ɗ ƙ ƴ), and only matches whole words. In a dose "
         "word, N stands for any number: digits, a number word or a range (\"every N hours\" catches \"every 6 hours\", "
         "\"every six hours\" and \"every 4 to 6 hours\").", False),
        ("Blocking too much is the safe side, but a list that blocks ordinary school words (e.g. a biology page about "
         "the body) makes Explain useless for that page.", False),
        ("", False),
        ("How to review", True),
        ("In the amber column choose Keep, Remove or Add. Put any change or reason in Notes. Add new words in the "
         "'(new)' rows at the bottom of each tab.", False),
        ("Tab 'English (Dr. Amos)': health topic words, medicine names (used in every language) and English dose "
         "words.", False),
        ("Tab 'Hausa, Yorùbá, Igbo': the same lists in each language, for native speakers. Please also check the "
         "spelling and tone marks.", False),
        ("Money and harm word lists exist too; they are not in this pack.", False),
    ]:
        about.append([text])
        cell = about.cell(row=about.max_row, column=1)
        cell.font = Font(bold=bold, size=13 if bold else 12)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
    about.column_dimensions["A"].width = 120

    health = topics["en"]["health"]
    en = [["Health: strong", w, USE["strong"], "", ""] for w in health["strong"]]
    en += [["Health: ordinary", w, USE["words"], "", ""] for w in health["words"]]
    en += [["Medicine name", w, USE["medicine"], "", ""] for w in checks["medicines"]]
    en += [["Dose word", w, USE["dose"], "", note(w)] for w in checks["dose_words"]["en"]]
    sheet(wb.create_sheet(), "English (Dr. Amos)", en, lang_col=False)

    other = []
    for code, name in NAMES.items():
        other += [[name, "Health: strong", w, USE["strong"], "", ""] for w in topics[code]["health"]["strong"]]
        other += [[name, "Health: ordinary", w, USE["words"], "", ""] for w in topics[code]["health"]["words"]]
        other += [[name, "Dose word", w, USE["dose"], "", note(w)] for w in checks["dose_words"][code]]
    sheet(wb.create_sheet(), "Hausa, Yorùbá, Igbo", other, lang_col=True)
    wb.save(OUT)
    print(f"{OUT.relative_to(ROOT)}: {len(en)} English rows, {len(other)} Hausa/Yorùbá/Igbo rows")


if __name__ == "__main__":
    main()
