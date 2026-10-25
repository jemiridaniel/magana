"""docs/DATA_SOURCES.md mirrors the team's spreadsheet, docs/data_sources_tracker.xlsx."""
import re
from pathlib import Path

import pytest

DOCS = Path(__file__).parents[2] / "docs"


def test_the_markdown_and_the_spreadsheet_list_the_same_sources():
    openpyxl = pytest.importorskip("openpyxl")
    ws = openpyxl.load_workbook(DOCS / "data_sources_tracker.xlsx")["Sources"]
    in_sheet = {str(r[0]) for r in ws.iter_rows(min_row=2, values_only=True) if r[0] and re.match(r"S\d+$", str(r[0]))}
    in_md = set(re.findall(r"^\| (S\d+) \|", (DOCS / "DATA_SOURCES.md").read_text(), re.M))
    assert in_sheet == in_md, f"only in the spreadsheet: {sorted(in_sheet - in_md)}; only in the .md: {sorted(in_md - in_sheet)}"
