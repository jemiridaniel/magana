"""Draft quizzes made from teachers' lesson notes (scripts/lesson_notes.py) are checked against the
notes, and none reaches the app before a teacher approves it. Notes and drafts stay outside the
repository; these tests use made-up text."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend" / "scripts"))
import lesson_notes as ln  # noqa: E402

NOTES = ("Plants make their own food in their leaves. This is called photosynthesis. "
         "Leaves need sunlight, water and air. A plant has three main parts: roots, stem and leaves.")


def q(**over):
    base = {"question": "Where do plants make their food?", "A": "In their leaves", "B": "In the soil",
            "C": "In the rain", "D": "In the sky", "answer": "A",
            "quote": "Plants make their own food in their leaves."}
    return {**base, **over}


def test_a_question_grounded_in_the_notes_is_kept():
    assert ln.check_question(q(), NOTES) is None


def test_a_quote_that_is_not_in_the_notes_is_refused():
    assert ln.check_question(q(quote="Plants eat insects at night."), NOTES) == "quote not in the notes"


def test_an_answer_the_quote_does_not_support_is_refused():
    assert ln.check_question(q(answer="B"), NOTES) == "answer not in the quote"


def test_a_number_the_notes_do_not_have_is_refused():
    bad = q(question="How many main parts does a plant have?", A="Four", B="Three", C="Two", D="Five",
            answer="B", quote="A plant has three main parts: roots, stem and leaves.")
    assert ln.check_question(bad, NOTES) == "number not in the notes"
    good = {**bad, "A": "Three", "B": "Roots", "C": "Leaves", "D": "Stem", "answer": "A"}
    assert ln.check_question(good, NOTES) is None


def test_repeated_options_are_refused():
    assert ln.check_question(q(B="In their leaves"), NOTES) == "options"


def test_no_draft_quiz_is_bundled_with_the_app_or_the_server():
    for pack in [*(ROOT / "app" / "assets" / "quiz").glob("*.json"), *(ROOT / "content").rglob("*.json")]:
        text = pack.read_text(encoding="utf-8")
        assert ln.DRAFT not in text, pack
        data = json.loads(text)
        assert not (isinstance(data, dict) and data.get("approved") is False), pack


def test_answers_are_spread_over_a_to_d_and_still_right():
    qs = [q(question=f"Where do plants make their food? ({n})") for n in range(12)]
    out = [ln.shuffled(x) for x in qs]
    assert all(o[o["answer"]] == "In their leaves" for o in out)
    assert len({o["answer"] for o in out}) >= 3
    assert out == [ln.shuffled(x) for x in qs]  # the same each run
