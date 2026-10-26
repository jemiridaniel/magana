"""Money pages from a photo (safety.money_photo_check): no partial amounts. A statement photo
lost amounts with no warning (docs/FINDINGS.md); now zero amounts may go missing silently,
and no wrong amount is ever read out. The statement here is made by the test."""
import io
import re
import sys
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

from app import safety
from app.main import app
from pagefont import font

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import bank_benchmark as bb  # noqa: E402

client = TestClient(app)
ADULT = {"X-Magana-Tier": "standard"}
ROWS = [(f"{d:02d} Sep 2026", desc, debit, bal) for d, desc, debit, bal in [
    (2, "POS purchase", "5,000.00", "45,250.50"), (3, "Transfer in", "20,000.00", "65,250.50"),
    (5, "Airtime", "1,000.00", "64,250.50"), (6, "SMS alert", "52.50", "64,198.00"),
    (8, "ATM withdrawal", "10,000.00", "54,198.00"), (9, "Stamp duty", "50.00", "54,148.00"),
    (11, "POS purchase", "3,450.00", "50,698.00"), (12, "Transfer out", "15,000.00", "35,698.00"),
    (14, "Card fee", "7.50", "35,690.50"), (15, "Salary", "150,000.00", "185,690.50"),
    (17, "Electricity", "12,685.20", "173,005.30"), (19, "POS purchase", "2,300.00", "170,705.30")]]
AMOUNTS = [a for r in ROWS for a in r[2:]]


def statement(size=34) -> Image.Image:
    img = Image.new("RGB", (2480, 300 + 70 * len(ROWS)), "white")
    d, f = ImageDraw.Draw(img), font(size)
    for x, h in [(120, "Date"), (560, "Description"), (1350, "Debit"), (1850, "Balance")]:
        d.text((x, 120), h, fill="black", font=f)
    for i, (date, desc, debit, bal) in enumerate(ROWS):
        y = 200 + i * 70
        d.text((120, y), date, fill="black", font=f)
        d.text((560, y), desc, fill="black", font=f)
        d.text((1550, y), debit, fill="black", font=f, anchor="ra")
        d.text((2100, y), bal, fill="black", font=f, anchor="ra")
    return img


def read(img: Image.Image) -> dict:
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85)
    r = client.post("/read", files={"file": ("p.jpg", buf.getvalue())}, data={"mode": "money"}, headers=ADULT)
    assert r.status_code == 200, r.text
    return r.json()


def said(body: dict) -> list[str]:
    text = " ".join([l["text"] for l in body["lines"]] + [c["text"] for t in body["tables"] for row in t["rows"] for c in row])
    return [bb.value(a) for a in safety._AMOUNT.findall(text)]


def check_no_silent_loss(body: dict) -> None:
    out = said(body)
    truth = {bb.value(a) for a in AMOUNTS}
    # No wrong amount is ever read out.
    assert [a for a in out if a not in truth] == []
    # Every amount is read, or the page says it can't read the amounts reliably.
    missing = [a for a in AMOUNTS if bb.value(a) not in out]
    if missing:
        assert "money_amounts_unreliable" in body["tips"], missing
        assert body["incomplete"] and body["tips"][:2] == ["money_amounts_unreliable", "reading_incomplete"]


def test_a_simulated_statement_photo_loses_no_amount_without_a_warning():
    body = read(bb.photo_like(statement()))
    check_no_silent_loss(body)
    assert body["incomplete"] is True  # this photo isn't readable in full
    assert body["warnings"] == [] and body["cell_warnings"] == []  # only lines that passed every check


def test_the_same_statement_scanned_cleanly_is_read_in_full():
    body = read(statement(size=40))
    check_no_silent_loss(body)
    assert not body.get("incomplete") and len(said(body)) == len(AMOUNTS)  # not held back when it's all readable


def test_rows_split_into_column_blocks_are_one_row():
    # OCR often gives a statement row as separate blocks: the date, then each amount.
    parts = [dict(line(t), top=500, left=x) for t, x in [("21 Sep 2026", 0), ("5,000.00", 900), ("45,250.50", 1400)]]
    result = {"tips": [], "faint_regions": [], "warnings": [], "cell_warnings": [], "tables": [], "lines": parts}
    assert safety.money_photo_check(result) is result


_tops = iter(range(0, 100000, 60))


def line(text):
    return {"text": text, "words": [{"text": w, "confidence": 0.97} for w in text.split()], "top": next(_tops),
            "height": 40}


def test_a_dated_row_short_of_an_amount_holds_the_page_back():
    result = {"tips": [], "faint_regions": [], "warnings": [], "cell_warnings": [], "tables": [], "lines": [
        line("02 Sep 2026 POS purchase 5,000.00 45,250.50"),
        line("03 Sep 2026 Transfer in 65,250.50"),  # the amount itself was dropped
        line("05 Sep 2026 Airtime 1,000.00 64,250.50")]}
    out = safety.money_photo_check(result)
    assert out["tips"][:2] == ["money_amounts_unreliable", "reading_incomplete"]
    assert [l["text"] for l in out["lines"]] == [result["lines"][0]["text"], result["lines"][2]["text"]]
    assert out["left_out"] == 1


def test_a_clean_money_page_is_read_as_it_is():
    result = {"tips": [], "faint_regions": [], "warnings": [], "cell_warnings": [], "tables": [], "lines": [
        line("Opening balance 50,250.50"), line("02 Sep 2026 POS 5,000.00 45,250.50"),
        line("03 Sep 2026 Transfer 20,000.00 65,250.50")]}
    assert safety.money_photo_check(result) is result


def test_health_papers_are_not_held_back_by_the_money_rule():
    from app.main import checked
    result = {"tips": ["small_print"], "faint_regions": [], "lines": [line("Take 2 tablets 3 times a day")], "tables": []}
    assert "money_amounts_unreliable" not in checked(result, "health")["tips"]
