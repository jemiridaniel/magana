"""PaddleOCR PP-StructureV3 engine: tables come back as rows and cells."""
import io
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import safety
from app.main import app, get_engine
from app.reader import Cell, Line, Page, PaddleStructureEngine, Table, page_from_structure, parse_table_html

FIXTURE = Path(__file__).parent / "fixtures" / "ppstructurev3_lab_report.json"


# ---------- HTML → grid
def test_parse_simple_table_with_header():
    rows, header = parse_table_html(
        "<table><tr><th>Test</th><th>Result</th></tr><tr><td>WBC</td><td> 6.4 </td></tr></table>"
    )
    assert header
    assert [[c.text for c in r] for r in rows] == [["Test", "Result"], ["WBC", "6.4"]]
    assert (rows[1][1].row, rows[1][1].col) == (1, 1)


def test_header_guessed_without_th():
    # PP-StructureV3 emits only <td>: a wordy first row over numeric rows is the header.
    rows, header = parse_table_html("<table><tr><td>Test</td><td>Result</td></tr><tr><td>WBC</td><td>6.4</td></tr></table>")
    assert header
    _, header = parse_table_html("<table><tr><td>Maths</td><td>English</td></tr><tr><td>Art</td><td>Music</td></tr></table>")
    assert not header


def test_parse_rowspan_keeps_true_columns():
    html = (
        "<table><tr><td rowspan=2>Day 1</td><td>Maths</td><td>9am</td></tr>"
        "<tr><td>English</td><td>11am</td></tr></table>"
    )
    rows, header = parse_table_html(html)
    assert not header
    assert rows[0][0].rowspan == 2
    # Row 2 has no cell in column 0: the spanned cell is read once, where it starts.
    assert [(c.text, c.col) for c in rows[1]] == [("English", 1), ("11am", 2)]


def test_parse_colspan():
    rows, _ = parse_table_html(
        "<table><tr><td colspan='2'>Total</td><td>₦6,450.00</td></tr></table>"
    )
    assert [(c.text, c.col, c.colspan) for c in rows[0]] == [("Total", 0, 2), ("₦6,450.00", 2, 1)]


def test_parse_ignores_garbage_span_and_text_outside_cells():
    rows, _ = parse_table_html("<html><body>junk<table><tr><td rowspan='x'>A</td></tr></table></body></html>")
    assert rows[0][0].text == "A" and rows[0][0].rowspan == 1


# ---------- recorded real PP-StructureV3 output → Page
def test_fixture_becomes_lines_and_table():
    page = page_from_structure(json.loads(FIXTURE.read_text()))
    assert len(page.tables) == 1
    t = page.tables[0]
    grid = [[c.text for c in r] for r in t.rows]
    assert grid[0] == ["Test", "Result", "Range"]
    assert ["Haemoglobin", "11.2 g/dL", "12.0 - 16.0"] in grid
    assert t.label == "table 1" and t.header
    # Text inside the table is not also read as page lines.
    line_text = " ".join(l.text for l in page.lines)
    assert "Full Blood Count" in line_text and "Haemoglobin" not in line_text
    assert [l.top for l in page.lines] == sorted(l.top for l in page.lines)
    assert all(0 <= c.confidence <= 1 for r in t.rows for c in r)


def test_page_lines_after_table_are_kept():
    page = page_from_structure(json.loads(FIXTURE.read_text()))
    below = [l for l in page.lines if l.top > page.tables[0].top]
    assert any("Reviewed" in l.text for l in below)


def test_engine_uses_injected_pipeline():
    class FakePipeline:
        def predict(self, arr):
            assert arr.shape[2] == 3
            return [json.loads(FIXTURE.read_text())]

    page = PaddleStructureEngine(pipeline=FakePipeline()).read(Image.new("RGB", (40, 40), "white"))
    assert page.tables and page.tables[0].rows[0][0].text == "Test"


def test_empty_result_is_empty_page():
    assert page_from_structure({}) == Page()


# ---------- cell warnings
def test_low_confidence_cell_is_named_by_row_and_column():
    tables = [{"label": "table 1", "rows": [
        [{"text": "Result", "confidence": 0.99, "row": 0, "col": 1}],
        [{"text": "11.2 g/dL", "confidence": 0.41, "row": 1, "col": 1}],
    ]}]
    w = safety.table_warnings(tables)
    assert len(w) == 1
    assert "row 2, column 2 of table 1" in w[0].spoken


def test_empty_cells_are_not_warned():
    assert safety.table_warnings([{"rows": [[{"text": "", "confidence": 0.0, "row": 0, "col": 0}]]}]) == []


# ---------- /read with the paddle engine swapped in
class FakeEngine:
    def read(self, image):
        return Page(
            lines=[Line("Full Blood Count", 0.98, 10, "line 1")],
            tables=[Table([[Cell("Test", 0.99, 0, 0), Cell("Result", 0.99, 0, 1)],
                           [Cell("Haemoglobin", 0.97, 1, 0), Cell("11.2 g/dL", 0.52, 1, 1)]],
                          top=80, label="table 1", header=True)],
        )


@pytest.fixture
def paddle_client():
    app.dependency_overrides[get_engine] = FakeEngine
    yield TestClient(app)
    app.dependency_overrides.clear()


def _png():
    buf = io.BytesIO()
    Image.new("RGB", (200, 200), "white").save(buf, "PNG")
    return buf.getvalue()


def test_read_endpoint_returns_tables_and_cell_warnings(paddle_client):
    r = paddle_client.post("/read", files={"file": ("p.png", _png(), "image/png")}, data={"mode": "health"})
    assert r.status_code == 200
    body = r.json()
    assert body["lines"][0]["text"] == "Full Blood Count"
    assert body["tables"][0]["header"] is True
    assert body["tables"][0]["rows"][1][1]["text"] == "11.2 g/dL"
    assert body["cell_warnings"][0]["spoken"].startswith("I'm not sure about row 2, column 2 of table 1")


# ---------- real engine, only where paddleocr is installed (requirements-paddle.txt)
def test_real_ppstructurev3_reads_a_table():
    pytest.importorskip("paddleocr")
    from PIL import ImageDraw, ImageFont

    font = ImageFont.truetype("Arial.ttf", 34) if Path("/System/Library/Fonts").exists() else ImageFont.load_default(size=34)
    img = Image.new("RGB", (900, 400), "white")
    d = ImageDraw.Draw(img)
    for r, row in enumerate([["Test", "Result"], ["WBC", "6.4"], ["Platelets", "250"]]):
        for c, text in enumerate(row):
            box = [60 + 380 * c, 60 + 80 * r, 440 + 380 * c, 140 + 80 * r]
            d.rectangle(box, outline="black", width=2)
            d.text((box[0] + 20, box[1] + 20), text, fill="black", font=font)
    page = PaddleStructureEngine().read(img)
    assert page.tables, "expected PP-StructureV3 to find the table"
    cells = [c.text for r in page.tables[0].rows for c in r]
    assert "Platelets" in cells and "250" in cells
