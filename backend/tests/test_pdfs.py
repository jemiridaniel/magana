"""Read a PDF (pdfs.py, POST /read-pdf): text-layer pages read exactly, statement tables row
by row, scans through OCR and the safety checks, locked PDFs, limits and tiers.
Every PDF here is made by the test: no real statement is ever used."""
import io

import pypdf
import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from app import pdfs
from app.main import app, get_engine
from app.reader import Line, Page, Word

from pagefont import font

client = TestClient(app)
ADULT = {"X-Magana-Tier": "standard"}
TEEN = {"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"}

# A made-up statement: column x positions as banks lay them out (amounts right-aligned).
COLS = [("Date", 40, "l"), ("Description", 110, "l"), ("Debit", 400, "r"), ("Credit", 470, "r"),
        ("Balance", 550, "r")]
ROWS = [
    ("02 Sep 2026", ["POS purchase SHOPRITE", "IKEJA CITY MALL"], "5,000.00", "", "45,250.50"),
    ("03 Sep 2026", ["Transfer from ADA OKEKE"], "", "20,000.00", "65,250.50"),
    ("05 Sep 2026", ["Airtime MTN 08031234567"], "1,000.00", "", "64,250.50"),
    ("06 Sep 2026", ["SMS alert charges"], "52.50", "", "64,198.00"),
]


def _cell(c, x, align, y, text):
    (c.drawRightString if align == "r" else c.drawString)(x, y, text)


def statement(pages=1, password=None, rows=ROWS) -> bytes:
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    for p in range(pages):
        c.setFont("Helvetica", 10)
        c.drawString(40, 800, "Bank A  Statement of account")
        c.drawString(40, 785, "Opening balance 50,250.50")
        y = 750
        for name, x, align in COLS:
            _cell(c, x, align, y, name)
        for date, desc, debit, credit, bal in rows:
            y -= 18
            for (_, x, align), text in zip(COLS, [date, desc[0], debit, credit, bal]):
                if text:
                    _cell(c, x, align, y, text)
            for more in desc[1:]:
                y -= 12
                c.drawString(110, y, more)
        c.drawString(40, y - 40, f"Closing balance 64,198.00  Page {p + 1}")
        c.showPage()
    c.save()
    data = buf.getvalue()
    if password:
        w = pypdf.PdfWriter()
        w.append(pypdf.PdfReader(io.BytesIO(data)))
        w.encrypt(password, algorithm="AES-256")
        out = io.BytesIO()
        w.write(out)
        data = out.getvalue()
    return data


def scanned(text_lines: list[str], pages=1) -> bytes:
    """An image-only PDF, like a phone scanner app makes: no text layer at all."""
    images = []
    for _ in range(pages):
        img = Image.new("RGB", (1240, 1754), "white")
        d = ImageDraw.Draw(img)
        for i, t in enumerate(text_lines):
            d.text((100, 150 + i * 90), t, fill="black", font=font(48))
        images.append(img)
    buf = io.BytesIO()
    images[0].save(buf, "PDF", resolution=150, save_all=True, append_images=images[1:])
    return buf.getvalue()


def post(data, headers=ADULT, **form):
    return client.post("/read-pdf", files={"file": ("s.pdf", data, "application/pdf")},
                       data={"mode": "money", **form}, headers=headers)


def test_a_statement_with_a_text_layer_is_read_row_by_row_exactly():
    r = post(statement())
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["pages"] == [{"number": 1, "source": "text"}]
    [table] = body["tables"]
    assert table["header"] is True
    rows = [[c["text"] for c in row] for row in table["rows"]]
    assert rows[0] == ["Date", "Description", "Debit", "Credit", "Balance"]
    assert rows[1] == ["02 Sep 2026", "POS purchase SHOPRITE IKEJA CITY MALL", "5,000.00", "", "45,250.50"]
    assert rows[2] == ["03 Sep 2026", "Transfer from ADA OKEKE", "", "20,000.00", "65,250.50"]
    assert rows[4] == ["06 Sep 2026", "SMS alert charges", "52.50", "", "64,198.00"]
    assert len(rows) == 1 + len(ROWS)
    lines = [l["text"] for l in body["lines"]]
    assert "Opening balance 50,250.50" in lines
    assert any(l.startswith("Closing balance 64,198.00") for l in lines)
    # The file's own characters: nothing to warn about, every number as printed.
    assert body["warnings"] == [] and body["cell_warnings"] == []
    # The closing line sorts after the table.
    closing = next(l for l in body["lines"] if l["text"].startswith("Closing"))
    assert closing["top"] > table["top"]


def test_every_amount_and_date_in_the_file_comes_back_verbatim():
    body = post(statement()).json()
    said = " ".join([l["text"] for l in body["lines"]]
                    + [c["text"] for t in body["tables"] for row in t["rows"] for c in row])
    for date, _, debit, credit, bal in ROWS:
        for v in (date, debit, credit, bal):
            assert v in said


def test_pages_join_in_order_with_their_numbers():
    body = post(statement(pages=3)).json()
    assert [p["number"] for p in body["pages"]] == [1, 2, 3]
    assert body["page_count"] == 3
    assert [t["page"] for t in body["tables"]] == [1, 2, 3]
    tops = [t["top"] for t in body["tables"]]
    assert tops == sorted(tops) and tops[1] - tops[0] >= pdfs.PAGE_SPAN - 2000


def test_a_locked_pdf_asks_for_its_password_and_never_returns_it():
    locked = statement(password="482915")
    r = post(locked)
    assert (r.status_code, r.json()["detail"]["code"]) == (401, "pdf_password_needed")
    r = post(locked, password="111111")
    assert (r.status_code, r.json()["detail"]["code"]) == (401, "pdf_password_wrong")
    r = post(locked, password="482915")
    assert r.status_code == 200
    assert r.json()["tables"][0]["rows"][1][4]["text"] == "45,250.50"
    assert "482915" not in r.text


def test_not_a_pdf_too_long_and_too_big():
    assert post(b"not a pdf at all").json()["detail"]["code"] == "unreadable_pdf"
    r = post(statement(pages=pdfs.MAX_PAGES + 1))
    assert (r.status_code, r.json()["detail"]["code"]) == (413, "pdf_too_long")
    r = post(b"%PDF-1.4" + b"0" * (pdfs.MAX_BYTES + 10))
    assert (r.status_code, r.json()["detail"]["code"]) == (413, "pdf_too_long")


def test_the_tier_rules_apply_to_pdfs_too():
    assert post(statement(), headers=TEEN).status_code == 403  # money papers are 18+
    assert post(statement(), headers=TEEN, mode="school").status_code == 200
    assert post(statement(), mode="nonsense").status_code == 400


def test_a_scanned_pdf_goes_through_ocr_and_the_number_checks():
    r = post(scanned(["Opening balance 12,500.00", "Transfer 3,000.00"]))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["pages"] == [{"number": 1, "source": "scan"}]
    text = " ".join(l["text"] for l in body["lines"])
    assert "12,500.00" in text and "3,000.00" in text
    # Each number was re-read from its own crop, as for a photo.
    nums = [w for l in body["lines"] for w in l["words"] if any(ch.isdigit() for ch in w["text"])]
    assert nums and all(w["reread_text"] is not None for w in nums)


def test_warnings_point_at_the_right_line_after_pages_are_joined(monkeypatch):
    from dataclasses import asdict

    shaky = Line("Balance 4,250.00", 0.95, 100, words=[
        Word("Balance", 0.97, 100, 100, 200, 40),
        Word("4,250.00", 0.6, 320, 100, 200, 40, reread_text="4,250.00", reread_confidence=0.6)])
    sure = Line("Statement", 0.97, 40, words=[Word("Statement", 0.97, 100, 40, 200, 40)])
    monkeypatch.setattr(pdfs, "read_page", lambda image, engine, second_pass: {
        "tips": [], "lines": [asdict(sure), asdict(shaky)], "tables": [], "faint_regions": []})
    body = post(scanned(["x"], pages=2), mode="health").json()  # money pages would hold back flagged lines
    flagged = [(w["block_index"], w["word_index"]) for w in body["warnings"]]
    assert flagged == [(1, 1), (3, 1)]  # the amount on page 1, then on page 2
    assert [body["lines"][i]["page"] for i, _ in flagged] == [1, 2]


def test_a_table_header_needs_known_column_names():
    words = [pdfs._W(t, x, x + 30, 10, 20) for t, x in [("Date", 0), ("Balance", 200), ("Debit", 100)]]
    assert [c.kind for c in pdfs.find_header(sorted(words, key=lambda w: w.x0))] == ["date", "debit", "balance"]
    words = [pdfs._W(t, x, x + 30, 10, 20) for t, x in [("Name", 0), ("Class", 100), ("Score", 200)]]
    assert pdfs.find_header(words) is None


def centred_statement() -> bytes:
    """The other common layout: the header's Balance name split over three lines, each
    description centred in a tall row (wrapped text above and below the date line), "--"
    for no amount, the header on page 1 only, and a second account's summary and header
    starting halfway down page 2."""
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    import pagefont

    pdfmetrics.registerFont(TTFont("DejaVu", str(pagefont.PATH)))  # has ₦; Helvetica doesn't
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    c.setFont("DejaVu", 7)
    cols = [("Trans. Time", 40, "l"), ("Value Date", 140, "l"), ("Description", 195, "l"),
            ("Debit(₦)", 360, "r"), ("Credit(₦)", 415, "r"), ("Balance After(₦)", 480, "r"), ("Channel", 500, "l")]

    def header(y):
        for name, x, align in cols:
            if name.startswith("Balance"):
                c.drawRightString(x, y + 6, "Balance After(")
                c.drawRightString(x, y - 6, "₦)")
            else:
                _cell(c, x, align, y, name)

    def row(y, date, desc, debit, credit, bal):
        c.drawString(195, y + 8, desc[0])
        for (_, x, align), t in zip(cols, [f"{date} 10:15:01", date, desc[1], debit, credit, bal, "POS"]):
            _cell(c, x, align, y, t)
        c.drawString(195, y - 8, desc[2])

    c.drawString(40, 800, "Opening Balance 50,000.00")
    header(760)
    y = 760
    for i in range(3):
        y -= 34
        row(y, f"0{i + 2} Sep 2026", [f"Transfer from shop {i}", "to ACME LTD", "| ref 77"], "--", f"1,00{i}.00",
            f"5{i},000.00")
    c.showPage()
    c.setFont("DejaVu", 7)
    y = 790
    for i in range(2):
        row(y, f"1{i} Sep 2026", ["POS purchase", "SHOPRITE", "IKEJA"], f"2{i}0.50", "--", f"4{i},500.00")
        y -= 34
    c.drawString(40, y - 10, "Opening Balance")
    c.drawString(40, y - 22, "₦9,999.99")
    header(y - 60)
    row(y - 100, "01 Oct 2026", ["Airtime", "MTN", "self"], "100.00", "--", "9,899.99")
    c.showPage()
    c.save()
    return buf.getvalue()


def test_centred_rows_split_header_carried_columns_and_a_second_table():
    body = post(centred_statement()).json()
    assert body["warnings"] == [] and body["cell_warnings"] == []
    tables = body["tables"]
    assert [t["page"] for t in tables] == [1, 2, 2]
    names = [c["text"] for c in tables[0]["rows"][0]]
    assert names == ["Trans. Time", "Value Date", "Description", "Debit(₦)", "Credit(₦)", "Balance After(₦)",
                     "Channel"]
    rows = [[c["text"] for c in r] for t in tables for r in t["rows"][1:]]
    assert len(rows) == 6  # 3 + 2 + 1: the summary above the second header is not a row
    assert rows[0] == ["02 Sep 2026 10:15:01", "02 Sep 2026", "Transfer from shop 0 to ACME LTD | ref 77", "--",
                       "1,000.00", "50,000.00", "POS"]
    assert rows[3][2:6] == ["POS purchase SHOPRITE IKEJA", "200.50", "--", "40,500.00"]  # page 2, page 1's columns
    assert rows[5][0].startswith("01 Oct 2026") and rows[5][5] == "9,899.99"
    lines = [l["text"] for l in body["lines"]]
    assert "Opening Balance 50,000.00" in lines and "₦9,999.99" in lines


def test_a_scanner_apps_hidden_text_layer_is_not_trusted():
    """A photo of the page with invisible OCR text on top: Magana reads the photo itself."""
    from reportlab.lib.utils import ImageReader

    img = Image.new("RGB", (1240, 1754), "white")
    ImageDraw.Draw(img).text((100, 150), "Balance 12,500.00", fill="black", font=font(48))
    png = io.BytesIO()
    img.save(png, "PNG")
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    c.drawImage(ImageReader(io.BytesIO(png.getvalue())), 0, 0, *A4)
    t = c.beginText(60, 760)
    t.setTextRenderMode(3)  # invisible
    t.textLine("Balance 12,800.00 (the scanner's own guess)")
    c.drawText(t)
    c.showPage()
    c.save()
    body = post(buf.getvalue()).json()
    assert body["pages"] == [{"number": 1, "source": "scan"}]
    text = " ".join(l["text"] for l in body["lines"])
    assert "12,500.00" in text and "12,800.00" not in text
