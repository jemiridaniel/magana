#!/usr/bin/env python3
"""Dr. Amos's English recording pack: the ~50 highest-priority phrases, not the full 577.

    backend/.venv/bin/python scripts/export_priority_phrases.py

Reads app/lib/l10n/app_en.arb (the single source of truth for English app text -- the same
file scripts/export_phrases.py reads for the full set) and writes, to docs/recording/priority-en/:
  - priority-phrases.csv / .xlsx: ID, file name, text to record, category, notes -- same column
    convention as docs/recording/phrases-en.csv, so scripts/import_clips.py needs no changes.
  - priority-phrases.docx: the same list as a simple numbered document, to read from a phone.
File names follow the existing convention (en-<ID>.m4a), so these recordings drop straight into
scripts/import_clips.py like any other language's.

PRIORITY picks the specific IDs per docs/recording/RECORDING_PACK_AMOS.md's six categories
(home/capture cues, "Picture taken. Reading...", reader controls, unclear-number/word warnings,
health-worker and medicine-safety lines, the tour opening). Every ID is checked against the ARB
file at run time -- a renamed or removed key fails loudly here rather than silently vanishing
from the pack.

HEALTH is the subset of PRIORITY whose wording must be recorded exactly, word for word (medical
safety text) -- see scripts/check_health_phrases.py, run after import_clips.py.
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Order matters: this is also the order in the printed pack and the spreadsheet.
PRIORITY: list[tuple[str, list[str]]] = [
    ("Tour opening", [
        "welcome", "tourTitle", "touchIntroTitle", "touchIntroBody", "tourScript",
    ]),
    ("Home screen", [
        "appTitle", "greeting", "chooseLanguage", "settings", "readPage", "readPageSubtitle",
        "practiceQuiz", "myLibrary", "backToHome",
    ]),
    ("Capture cues", [
        "takePhoto", "cameraView", "autoCapture", "cameraFailed", "cameraUnavailable",
        "pictureTaken", "readingPage", "privacyNote",
    ]),
    ("Reader controls", [
        "play", "pause", "playLabel", "pauseLabel", "repeat", "repeatLine",
        # 9 Nov 2026: "Still reading…" is no longer said; this new wait reminder replaces it
        # (second session, not yet recorded).
        "stillReadingPleaseWait",
        # speed/speedLabel have a {value} placeholder -- the device's own TTS reads the number
        # live, in every language including English, so there's nothing fixed to record.
    ]),
    ("Unclear number / word warnings", [
        "unclearNumber", "unclearLetter", "whatsUnclear", "whatsUnclearNone", "summaryAsk",
        "amountUnclear", "currencyUnclear",
        # msg_line_end_unclear, msg_line_part_unclear, msg_currency_unclear ({where}) and
        # summaryNumbers ({count, plural, ...}) all have placeholders -- same reason as above.
    ]),
    # HEALTH: recorded last, read most carefully -- see the module docstring and
    # scripts/check_health_phrases.py. Must match the ARB text exactly, word for word.
    ("Health worker & medicine safety (HEALTH -- exact wording required)", [
        "msg_go_to_clinic_now", "noteMedicine", "askPharmacistOrNurse", "healthWorkerTitle",
        "healthWorkerSubtitle", "missedDose", "msg_cant_translate_line_health",
        "msg_offline_health_numbers", "doseTaken", "doseDue",
    ]),
]

# IDs in the HEALTH category above (scripts/check_health_phrases.py imports this).
HEALTH_IDS: set[str] = {pid for cat, ids in PRIORITY if cat.startswith("Health") for pid in ids}


def load_arb() -> dict[str, str]:
    import json

    data = json.loads((ROOT / "app/lib/l10n/app_en.arb").read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}


def build_rows() -> list[list[str]]:
    english = load_arb()
    missing = [pid for _, ids in PRIORITY for pid in ids if pid not in english]
    if missing:
        raise SystemExit(
            "These phrase IDs are in PRIORITY but not in app_en.arb (renamed or removed?): "
            + ", ".join(missing)
        )
    # A phrase with a {placeholder} (a number, or an ICU plural/select) is always read live by
    # the device's own TTS -- in every language, English included (export_phrases.py skips these
    # the same way for the full set). There is nothing fixed to record; catch one here rather
    # than print the raw template text into Dr. Amos's pack (as summaryNumbers' literal
    # "{count, plural, ...}" once did).
    templated = [pid for _, ids in PRIORITY for pid in ids if "{" in english[pid]]
    if templated:
        raise SystemExit(
            "These PRIORITY ids have a {placeholder} in their English text and can't be "
            "recorded as-is -- remove them from PRIORITY: " + ", ".join(templated)
        )
    seen_text: dict[str, str] = {}
    rows: list[list[str]] = []
    n = 0
    for category, ids in PRIORITY:
        for pid in ids:
            text = english[pid]
            if text in seen_text:
                # Same words as an earlier ID in the pack: one recording covers both (the app's
                # own export_phrases.py does the same dedupe for the full set).
                for row in rows:
                    if row[0] == seen_text[text]:
                        row[4] += f" (also used as {pid})"
                        break
                continue
            n += 1
            seen_text[text] = pid
            rows.append([pid, f"en-{pid}.m4a", text, category, "", str(n)])
    return rows


def write_csv(rows: list[list[str]], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["No.", "Phrase ID", "File name", "Text to record", "Category", "Notes",
                    "Recorded? (yes/no)"])
        for pid, fname, text, category, notes, no in rows:
            w.writerow([no, pid, fname, text, category, notes, ""])


def write_xlsx(rows: list[list[str]], out: Path) -> None:
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.worksheet.datavalidation import DataValidation
    except ImportError:
        print("openpyxl isn't installed: CSV only (pip install openpyxl)", file=sys.stderr)
        return
    wb = Workbook()
    ws = wb.active
    ws.title = "Dr. Amos - priority phrases"
    header = ["No.", "Phrase ID", "File name", "Text to record", "Category", "Notes",
              "Recorded? (yes/no)"]
    ws.append(header)
    for pid, fname, text, category, notes, no in rows:
        ws.append([int(no), pid, fname, text, category, notes, ""])
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="0A6B4B")
    ws.freeze_panes = "A2"
    for col, width in zip("ABCDEFG", [5, 30, 30, 70, 38, 30, 18]):
        ws.column_dimensions[col].width = width
    for row in ws.iter_rows(min_row=2):
        for cell in row:
            cell.alignment = Alignment(wrap_text=True, vertical="top")
    dv = DataValidation(type="list", formula1='"yes,no"', allow_blank=True)
    ws.add_data_validation(dv)
    dv.add(f"G2:G{len(rows) + 1}")
    wb.save(out)


def write_docx(rows: list[list[str]], out: Path) -> None:
    try:
        from docx import Document
        from docx.shared import Pt
    except ImportError:
        print("python-docx isn't installed: .docx skipped (pip install python-docx)",
              file=sys.stderr)
        return
    doc = Document()
    doc.add_heading("Magana: priority phrases to record (English)", level=1)
    p = doc.add_paragraph(
        "Thank you for lending Magana your voice. Record each numbered line below exactly as "
        "written, in order -- see the one-page guide for how. The last section (marked HEALTH) "
        "is medicine and health-worker safety text: please read those extra carefully, word for "
        "word, with no paraphrasing."
    )
    p.runs[0].font.size = Pt(11)
    last_category = None
    for pid, fname, text, category, notes, no in rows:
        if category != last_category:
            doc.add_heading(category, level=2)
            last_category = category
        para = doc.add_paragraph()
        run = para.add_run(f"{no}. ")
        run.bold = True
        para.add_run(text)
        file_run = para.add_run(f"   [{fname}]")
        file_run.font.size = Pt(8)
        file_run.italic = True
    doc.save(out)


def main() -> int:
    rows = build_rows()
    out_dir = ROOT / "docs/recording/priority-en"
    write_csv(rows, out_dir / "priority-phrases.csv")
    write_xlsx(rows, out_dir / "priority-phrases.xlsx")
    write_docx(rows, out_dir / "priority-phrases.docx")
    print(f"{len(rows)} priority phrases -> {out_dir}")
    print(f"  of which {sum(1 for r in rows if r[0] in HEALTH_IDS)} are HEALTH (exact wording)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
