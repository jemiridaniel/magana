"""Export every lesson and quiz in the app to a review sheet for a teacher and a
rehabilitation trainer: docs/review/content-review.xlsx, with a CSV copy next to it.

    backend/.venv/bin/python scripts/export_content_review.py

Needs openpyxl (pip install openpyxl). Re-run after any change to app/assets/lessons/ or
app/assets/quiz/. Reads only those files and app/assets/curriculum.json; writes nothing else.

Status: a lesson or quiz file may carry "status" (draft, teacher_reviewed or trainer_reviewed).
A file without one is a draft. Today none carries one, so everything is "draft".
The question-by-question check for quizzes is docs/review/sample_questions.xlsx
(scripts/build_review_pack.py).
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app" / "assets"
OUT = ROOT / "docs" / "review"
XLSX = OUT / "content-review.xlsx"
CSV = OUT / "content-review.csv"

STATUSES = ["draft", "teacher-reviewed", "trainer-reviewed"]
LANGS = {"en": "English", "ha": "Hausa", "yo": "Yorùbá", "ig": "Igbo"}
# A lesson's feature: what it teaches, and who can open it (app/lib/policy.dart).
FEATURE_SKILL = {"skills": "Phone and reading skills", "everydayMoney": "Money papers",
                 "everydayHealth": "Health papers"}
FEATURE_AUDIENCE = {
    "skills": "Skills: 13 and over (Standard and Guided accounts)",
    "everydayMoney": "Everyday papers, money: 18 and over only",
    "everydayHealth": "Everyday papers, health: 18 and over only",
}
HEADERS = ["ID", "Title", "Subject / skill", "Level / class", "Language(s)", "Items",
           "File", "Current status", "Reviewer name", "Review date", "Comments"]
WIDTHS = [26, 40, 22, 40, 14, 8, 36, 18, 22, 14, 50]
HEAD = PatternFill("solid", fgColor="0A6B4B")  # Magana green, white text: over 7:1


def status_of(doc: dict) -> str:
    s = str(doc.get("status", "draft")).strip().lower().replace("_", "-")
    return s if s in STATUSES else "draft"


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def lessons() -> list[list]:
    path = ASSETS / "lessons" / "lessons.json"
    doc = json.loads(path.read_text(encoding="utf-8"))
    rows = []
    for l in doc["lessons"]:
        rows.append([
            l["id"], l["title"], FEATURE_SKILL.get(l["feature"], l["feature"]),
            FEATURE_AUDIENCE.get(l["feature"], l["feature"]),
            LANGS.get(l.get("language", "en"), l.get("language", "en")),
            len(l["steps"]),
            rel(path),
            status_of(l) if "status" in l else status_of(doc),
            "", "", "",
        ])
    return rows


def lesson_steps() -> list[list]:
    doc = json.loads((ASSETS / "lessons" / "lessons.json").read_text(encoding="utf-8"))
    return [[l["id"], i, step, "", ""]
            for l in doc["lessons"] for i, step in enumerate(l["steps"], 1)]


def quizzes() -> list[list]:
    cur = json.loads((ASSETS / "curriculum.json").read_text(encoding="utf-8"))
    classes = {}
    for lv in cur["levels"]:
        name = lv["name"] + (f" ({lv['basic']})" if lv.get("basic") else "")
        classes.setdefault(lv["band"], []).append(name)
    rows = []
    for path in sorted((ASSETS / "quiz").glob("*.json")):
        q = json.loads(path.read_text(encoding="utf-8"))
        langs = {q.get("language", "en")}
        for item in q["questions"]:
            langs.update(item.get("translations", {}))
        band = q["band"]
        level = f"{cur['bands'][band]}: " + ", ".join(classes.get(band, []))
        rows.append([
            q["id"], q["title"], cur["subjects"].get(q["subject"], q["subject"]), level,
            ", ".join(LANGS.get(x, x) for x in sorted(langs, key=list(LANGS).index)),
            len(q["questions"]), rel(path), status_of(q), "", "", "",
        ])
    return rows


def table(wb: Workbook, title: str, headers: list[str], widths: list[int], rows: list[list],
          status_col: int | None) -> None:
    ws = wb.create_sheet(title)
    ws.append(headers)
    for i, w in enumerate(widths, 1):
        c = ws.cell(1, i)
        ws.column_dimensions[c.column_letter].width = w
        c.font = Font(bold=True, color="FFFFFF", size=12)
        c.fill = HEAD
        c.alignment = Alignment(wrap_text=True, vertical="top")
    for r in rows:
        ws.append(r)
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical="top")
            c.font = Font(size=12)
    ws.freeze_panes = "A2"
    if status_col is not None:
        col = ws.cell(1, status_col).column_letter
        dv = DataValidation(type="list", formula1='"' + ",".join(STATUSES) + '"', allow_blank=False,
                            showErrorMessage=True, errorTitle="Status",
                            error="Choose draft, teacher-reviewed or trainer-reviewed.")
        ws.add_data_validation(dv)
        dv.add(f"{col}2:{col}{max(ws.max_row, 2) + 50}")


def how_to(wb: Workbook, n_lessons: int, n_quizzes: int, n_questions: int) -> None:
    ws = wb.active
    ws.title = "How to review"
    ws.column_dimensions["A"].width = 100
    lines = [
        "Magana lessons and quizzes: content review",
        f"This file lists every lesson ({n_lessons}) and every quiz ({n_quizzes} quizzes, "
        f"{n_questions} questions) in the Magana app. All of it was written by the Magana team "
        "(CC BY 4.0). None of it has been reviewed yet, so every row starts as 'draft'.",
        "Who reviews what: a teacher reviews the Quizzes sheet. A rehabilitation trainer reviews "
        "the Lessons sheet and the Lesson steps sheet (phone skills, taking photos, reading a "
        "bank statement safely).",
        "Learners who are blind or have low vision hear every lesson step and every question "
        "read aloud. Please check that each one is clear when heard, not only when read; that "
        "it is right for the level; and that it is correct.",
        "For quizzes, the question-by-question sheet is docs/review/sample_questions.xlsx "
        "(question, options, right answer, and what Magana says after the answer).",
        "How to fill in a row: when you have checked it, set 'Current status' from the drop-down "
        "(teacher-reviewed or trainer-reviewed), write your name and the date, and put any "
        "changes in 'Comments'. Leave it as 'draft' if it needs changes.",
        "Please don't edit the ID or File columns: they are how we find the item in the app.",
        "Send the file back to the Magana team. We make the changes, then mark the file's status.",
        "Made by scripts/export_content_review.py from app/assets/lessons/ and app/assets/quiz/.",
    ]
    for i, line in enumerate(lines, 1):
        c = ws.cell(i, 1, line)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        c.font = Font(size=13, bold=i == 1)


def main() -> None:
    les, quiz, steps = lessons(), quizzes(), lesson_steps()
    wb = Workbook()
    how_to(wb, len(les), len(quiz), sum(r[5] for r in quiz))
    table(wb, "Lessons", HEADERS, WIDTHS, les, HEADERS.index("Current status") + 1)
    table(wb, "Quizzes", HEADERS, WIDTHS, quiz, HEADERS.index("Current status") + 1)
    table(wb, "Lesson steps", ["Lesson ID", "Step", "What Magana says", "OK? (yes / fix)", "Comments"],
          [22, 6, 90, 14, 50], steps, None)
    dv = DataValidation(type="list", formula1='"yes,fix"', allow_blank=True)
    wb["Lesson steps"].add_data_validation(dv)
    dv.add(f"D2:D{len(steps) + 1}")
    OUT.mkdir(parents=True, exist_ok=True)
    wb.save(XLSX)
    with CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Type"] + HEADERS)
        w.writerows([["lesson"] + r for r in les] + [["quiz"] + r for r in quiz])
    print(f"{rel(XLSX)}: {len(les)} lessons, {len(quiz)} quizzes; {rel(CSV)}")


if __name__ == "__main__":
    main()
