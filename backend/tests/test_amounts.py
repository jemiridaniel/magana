"""Money amounts on WhatsApp: said only when a second server engine agrees (amounts.py, the app's
rule in app/lib/amount_check.dart). The digits agree but not the sign: the digits, then "I can't
read the currency sign clearly". Naira is never guessed."""
import io
import re

import pytest
from PIL import Image, ImageDraw

import capture_fixtures as cf
import pagefont
from app import amounts, second_ocr, wa_flow
from test_whatsapp import FakeClient, adult, fake_voice_note, flow, photo, say  # noqa: F401


def lines(*texts):
    return [{"text": t, "words": [{"text": w} for w in t.split()]} for t in texts]


def codes(first, second):
    return [(w["block_index"], w["word_index"], w["code"]) for w in amounts.confirm(lines(*first), second)]


# ---------- the rule

def test_what_counts_as_an_amount():
    assert amounts.amount_in("₦8,000.00") == ("₦", "8,000.00")
    assert amounts.amount_in("#8,000.00,") == ("#", "8,000.00")
    assert amounts.amount_in("8,000.00", sign="NGN") == ("NGN", "8,000.00")
    assert amounts.amount_in("₩8,000.00") == ("₩", "8,000.00")
    for w in ["2026", "0123456789", "N5", "11:47", "A500", "27/10/2026"]:
        assert amounts.amount_in(w) is None, w


def test_agreed_exactly_is_said():
    assert codes(["Amount: ₦8,000.00"], ["Amount: ₦8,000.00"]) == []
    assert codes(["Amount: #8,000.00"], ["Amount #8,000.00"]) == []


def test_same_digits_another_sign_or_none_or_an_unlikely_one_is_currency_unclear():
    assert codes(["Amount: #8,000.00"], ["Amount: N8,000.00"]) == [(0, 1, "currency_unclear")]
    assert codes(["Amount: 8,000.00"], ["₦8,000.00"]) == [(0, 1, "currency_unclear")]
    assert codes(["Amount: ₩8,000.00"], ["Amount: ₩8,000.00"]) == [(0, 1, "currency_unclear")]


def test_other_digits_or_no_second_reading_is_held_back():
    assert codes(["Amount: 48,000.00"], ["Amount: ₦8,000.00"]) == [(0, 1, "amount_unconfirmed")]
    for other in ["8000.00", "8,000", "8,000.50"]:
        assert codes(["Amount: #8,000.00"], [f"₦{other}"]) == [(0, 1, "amount_unconfirmed")], other
    assert codes(["Fee ₦10.75"], None) == [(0, 1, "amount_unconfirmed")]


def test_each_second_amount_confirms_one_exact_matches_first():
    assert codes(["#500.00 ₦500.00"], ["₦500.00 ₦500.00"]) == [(0, 0, "currency_unclear")]
    assert codes(["₦500.00 ₦500.00"], ["₦500.00"]) == [(0, 1, "amount_unconfirmed")]


def test_plain_numbers_are_left_to_the_number_rules():
    assert amounts.confirm(lines("Account number: 0123456789", "Date: 27 Oct 2026"), None) == []


# ---------- WhatsApp wording

def result(text, code):
    words = text.split()
    j = next(i for i, w in enumerate(words) if re.search(r"\d", w))
    return {"lines": lines(text), "warnings": [{"block_index": 0, "word_index": j, "code": code}]}


def test_whatsapp_currency_unclear_gives_the_digits_and_says_so():
    shown, voice = wa_flow.reading_messages("en", result("Amount: NGN 8,000.00", "currency_unclear"))
    assert "1. Amount: 8,000.00 [I can't read the currency sign clearly]" in shown[0]
    assert "NGN" not in shown[0] and "naira" not in shown[0]
    assert any("not its currency sign" in m for m in shown)
    assert voice == [("Amount: 8,000.00", "currency")]


def test_whatsapp_held_amount_is_never_given():
    shown, voice = wa_flow.reading_messages("en", result("Amount: #8,000.00", "amount_unconfirmed"))
    assert "1. Amount: [I can't read the amount clearly]" in shown[0]
    assert "8,000" not in " ".join(shown)
    assert voice == [("Amount: [unclear number]", "amount")]


@pytest.mark.parametrize("lang", ["en", "ha", "yo", "ig"])
def test_every_language_has_the_amount_words(lang):
    for key in ["unclear_amount", "unclear_currency", "warn_amount", "warn_currency",
                "voice_warn_amount", "voice_warn_currency"]:
        assert wa_flow.t(lang, key, line=1).strip(), (lang, key)


# ---------- the photo, end to end, with the second engine faked

def total_photo() -> bytes:
    img = Image.new("RGB", (1200, 500), "white")
    ImageDraw.Draw(img).text((80, 180), "Total paid 8,000.00", fill="black", font=pagefont.font(72))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


@pytest.mark.parametrize("second, shown", [
    (["Total paid 8,000.00"], "Total paid 8,000.00"),
    (["Total paid N8,000.00"], "Total paid 8,000.00 [I can't read the currency sign clearly]"),
    (["Total paid 6,000.00"], "Total paid [I can't read the amount clearly]"),
    (None, "Total paid [I can't read the amount clearly]"),
])
def test_a_whatsapp_photo_follows_agree_or_hold(monkeypatch, fake_voice_note, second, shown):  # noqa: F811
    monkeypatch.setattr(second_ocr, "read_lines", lambda data: second)
    c = FakeClient(total_photo())
    f = flow(c)
    adult(f)
    say(f, photo())
    page = next(b for b in c.bodies() if b.startswith("*Your page*"))
    assert f"1. {shown}" in page, page
    said = " ".join(text for _, text in fake_voice_note[0])
    assert "naira" not in said
    if "[I can't read the amount" in shown:
        assert "eight thousand" not in said and "six thousand" not in said


def test_the_second_engine_is_asked_only_when_there_is_an_amount(monkeypatch):
    asked = []
    monkeypatch.setattr(second_ocr, "read_lines", lambda data: asked.append(1) or [])
    img = Image.new("RGB", (1200, 300), "white")
    ImageDraw.Draw(img).text((80, 100), "Take 2 tablets daily", fill="black", font=pagefont.font(64))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    from app.reader import TesseractEngine
    wa_flow.read_photo(buf.getvalue(), TesseractEngine())
    assert asked == []


# ---------- the real second engine (RapidOCR), when installed

@pytest.mark.skipif(not second_ocr.available(), reason="RapidOCR not installed")
def test_rapidocr_reads_the_receipt_amount_in_a_child_process():
    buf = io.BytesIO()
    cf.receipt().save(buf, "PNG")
    got = second_ocr.read_lines(buf.getvalue())
    assert got is not None and any(l.endswith("8,000.00") for l in got), got
    assert "Ada Okonkwo" in got


def test_a_failed_second_engine_means_no_second_reading(monkeypatch, caplog):
    monkeypatch.setattr(second_ocr, "available", lambda: True)
    monkeypatch.setattr(second_ocr, "TIMEOUT_S", 20)
    assert second_ocr.read_lines(b"not a picture") is None
    assert "not a picture" not in caplog.text
