"""A digit inside a word on a Hausa, Yorùbá or Igbo page is an unclear letter, never a number
(letters.digit_in_word, safety.letters_not_numbers). The cases: the 37 places where Tesseract
`eng` read Igbo ọ as "9" on the 10 phone-like Igbo benchmark pages, plus the 16 on the clean ones
(fixtures/letters/ig_digit_cases.json, from scripts/digit_letter_cases.py)."""
import json
from pathlib import Path

import pytest

from app import letters, safety, spoken, wa_flow
from app.main import checked

CASES = json.loads((Path(__file__).parent / "fixtures" / "letters" / "ig_digit_cases.json").read_text(encoding="utf-8"))
PHOTO = [c for c in CASES if c["kind"] == "photo"]


def is_number(token: str) -> bool:
    core = token.strip(",.;:")
    return core.replace(",", "").replace(".", "").isdigit()


def page(words: list[str], conf: float = 0.99) -> dict:
    """One line as the reader returns it, read twice the same way (the crop re-read agrees)."""
    ws = [{"text": w, "confidence": conf, "reread_text": w, "reread_confidence": conf} for w in words]
    lines = [{"text": " ".join(words), "confidence": conf, "words": ws}]
    return {"lines": lines, "tables": [], "tips": ["letters_ig"], "page_language": "ig",
            "letter_marks": letters.marks(lines, "ig")}


def test_the_37_phone_like_cases_are_all_here():
    assert len(PHOTO) == 37 and len(CASES) == 53
    assert all("ọ" in c["printed"] or "Ọ" in c["printed"] for c in CASES)
    # 30 of the 37 are the word "ọ" (he, she, it) read as a lone "9"; 2 are "ọzọ" read "929".
    assert sum(c["read"] == "9" for c in PHOTO) == 30
    assert sum(is_number(c["read"]) for c in PHOTO) == 32


@pytest.mark.parametrize("case", CASES, ids=[f"{c['kind']}-p{c['page']}-{c['read']}" for c in CASES])
def test_each_case(case):
    words = case["context"].split()
    j = words.index(case["read"])
    for conf in (0.99, 0.5):  # a confident reading, and an unsure one
        out = checked(page(words, conf))
        marks = {m["word_index"]: m["kind"] for m in out["letter_marks"]}
        on_word = [w["code"] for w in out["warnings"] if w.get("word_index") == j]
        if is_number(case["read"]):
            # A number standing alone keeps the verbatim rule and every number check.
            assert marks.get(j) != "unclear_letter"
            assert ("low_confidence_number" in on_word) is (conf < safety.CRITICAL_WORD_THRESHOLD)
        else:
            # A digit inside a word: an unclear letter for Spell word, never a number warning.
            assert marks.get(j) == "unclear_letter", case
            assert not set(on_word) & safety.NUMBER_CODES, case


def test_the_in_word_cases():
    inside = sorted({c["read"] for c in CASES if not is_number(c["read"])})
    assert inside == ["9z0", "9z9,", "9z90,", "9zo", "uz9"]
    assert all(letters.digit_in_word(w) for w in inside)


@pytest.mark.parametrize("word", ["n9", "ak9", "n'9", "9kwa", "Uz9", "ndi-9z9"])
def test_digits_in_letter_words(word):
    assert letters.digit_in_word(word)


@pytest.mark.parametrize("word", ["9", "929.", "90", "₦500", "N500", "500mg", "5ml", "2nd", "10am", "SS2", "JSS3",
                                  "B12", "COVID-19", "12/10/2026", "(9)", "38.5"])
def test_numbers_codes_and_units_stay_numbers(word):
    assert not letters.digit_in_word(word)


def test_an_english_page_is_never_touched():
    # The rule only runs where the page language is Hausa, Yorùbá or Igbo (letter_marks).
    lines = [{"text": "take 1 tab x3 daily", "confidence": 0.5,
              "words": [{"text": w, "confidence": 0.5} for w in "take 1 tab x3 daily".split()]}]
    out = checked({"lines": lines, "tables": [], "tips": []})
    assert {w["word_index"] for w in out["warnings"] if w["code"] in safety.NUMBER_CODES} >= {1, 3}


def test_whatsapp_says_unclear_letter_never_the_number():
    words = "9 buruhaala na uz9 osuso".split()
    p = page(words)
    out = {"lines": p["lines"], "warnings": [], "letter_marks": p["letter_marks"]}
    shown, voice = wa_flow.reading_messages("ig", out)
    assert "uz9 [mkpụrụedemede edoghị anya]" in "\n".join(shown)
    said = voice[0][0]
    assert "[unclear letter]" in said and "uz9" not in said
    assert "nine" not in spoken.spell_numbers(said.replace("9 buruhaala", "")) and "unclear letter" in spoken.spell_numbers(said)


def test_the_phone_has_the_same_language_words():
    import importlib.util
    root = Path(__file__).parents[2]
    spec = importlib.util.spec_from_file_location("gen", root / "scripts" / "gen_offline_language.py")
    gen = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gen)
    def squash(t): return "".join(t.split()).replace(",}", "}")  # dart format may reflow it
    assert squash(gen.OUT.read_text(encoding="utf-8")) == squash(gen.dart()), "run scripts/gen_offline_language.py"
