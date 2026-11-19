"""Dr. Amos's review of Explain's health word lists (17 Nov 2026): every word he added is caught
where it belongs, and harmless school sentences are not. His additions are the words with a note in
content/llm_safety/{topics,answer_checks}.json "_notes" (scripts/import_health_word_review.py).
docs/FINDINGS.md, 19 Nov 2026, has the over-blocking measured on our school pages."""
import json
from pathlib import Path

import pytest

from llm import natlas_guard as g

pytestmark = pytest.mark.safety
ROOT = Path(__file__).resolve().parents[2]
TOPICS = json.loads((ROOT / "content/llm_safety/topics.json").read_text(encoding="utf-8"))
CHECKS = json.loads((ROOT / "content/llm_safety/answer_checks.json").read_text(encoding="utf-8"))
PAGE = "This page is about plants: 1 2 3 5 6 8 12 500 numbers."


def added(notes: dict, path: str) -> list[str]:
    return sorted(notes.get(path, {}))


def test_his_additions_are_on_the_lists_with_his_notes():
    for notes, doc in ((TOPICS["_notes"], TOPICS), (CHECKS["_notes"], CHECKS)):
        for path, words in notes.items():
            node = doc
            for p in path.split("."):
                node = node[p]
            assert set(words) <= set(node), path
            assert all(n.startswith("Dr. Amos, 2026-11-17: ") for n in words.values()), path
    assert sum(len(v) for v in TOPICS["_notes"].values()) + sum(len(v) for v in CHECKS["_notes"].values()) == 219


@pytest.mark.parametrize("word", added(TOPICS["_notes"], "en.health.strong"))
def test_one_strong_health_word_stops_the_page(word):
    assert g.sensitive_topic(f"Notes for the class. {word.capitalize()}.") == "health", word


@pytest.mark.parametrize("word", added(TOPICS["_notes"], "en.health.words"))
def test_an_ordinary_health_word_counts_with_a_second_one(word):
    other = "fever" if word != "fever" else "clinic"
    assert g.sensitive_topic(f"Notes for the class: {word} and {other}.") == "health", word


@pytest.mark.parametrize("name", added(CHECKS["_notes"], "medicines"))
def test_an_answer_naming_his_medicines_is_never_spoken(name):
    assert g.answer_problem(f"The page talks about {name} here.", PAGE, "en") == "medicine_name", name


@pytest.mark.parametrize("word", added(CHECKS["_notes"], "dose_words.en"))
def test_an_answer_using_his_dose_words_is_never_spoken(word):
    text = word.replace("N", "5")  # "N days course": "5 days course"
    assert g.answer_problem(f"The page says {text} here.", PAGE, "en") == "dose_word", word


@pytest.mark.parametrize("short", added(CHECKS["_notes"], "dose_abbreviations.en"))
def test_his_shorthand_counts_next_to_a_number_or_a_dose_form(short):
    for answer in (f"Take 1 tab {short} now.", f"Give 500 mg {short}.", f"{short} 2 tabs.", f"{short} x 5 days."):
        assert g.answer_problem(answer, PAGE, "en") == "dose_word", answer


@pytest.mark.parametrize("short", added(CHECKS["_notes"], "dose_abbreviations.en"))
def test_his_shorthand_on_its_own_is_not_a_dose_word(short):
    assert g.answer_problem(f"The page says {short} and nothing else.", PAGE, "en") is None, short


def test_shorthand_is_never_also_a_plain_dose_word():
    short = set(CHECKS["dose_abbreviations"]["en"])
    assert {"iv", "im", "sc", "po", "ac", "pc", "hs", "qhs", "sos", "iu", "q6h", "q8h", "q12h",
            "b.d.", "t.d.s.", "o.d.", "q.d.s."} <= short
    assert not short & set(CHECKS["dose_words"]["en"])


@pytest.mark.parametrize("form", added(CHECKS["_notes"], "dose_forms.en"))
def test_his_dose_forms_make_shorthand_count(form):
    assert g.answer_problem(f"Use 2 {form} bd.", PAGE, "en") == "dose_word", form


@pytest.mark.parametrize("text", [
    "Chapter IV: The Water Cycle",
    "The school PC lab has 20 computers.",
    "Swimming: practise the breast stroke.",
    "Art: use a light brush stroke for the sky.",
    "Be patient with your classmates. A patient farmer waits for the rain.",
    "Mathematics: a packet of salt weighs 500 gram. How many packets make 2 kg?",
    "Home economics: sew a patch on the torn shirt.",
    "Home economics: herbal tea is made from leaves such as lemon grass.",
    "Physics: the mains supply is 230 V AC at 50 Hz.",
    "Write to the school at PO Box 15, Ibadan.",
    "Geography: the Tropic of Cancer is north of the equator.",
    "English: do not make a rash decision.",
    "Read Part IV and Part V. Use the PC in the lab. Practise the stroke.",
])
def test_harmless_school_sentences_are_not_caught(text):
    assert g.sensitive_topic(text) is None, text
    assert g.answer_problem(text, text, "en") is None, text


@pytest.mark.parametrize("text, before, after", [
    # Harmless school sentences his lists now stop. Kept as they are until Dr. Amos decides
    # (docs/FINDINGS.md, 19 Nov 2026); change a row only with his decision.
    ("Swimming: practise the breast stroke. Be patient: it takes time.", "health", None),
    ("Civic education: in an emergency, stay calm and be patient.", "health", None),
    ("Commerce: the shopkeeper sells goods over the counter.", "health", None),
    ("Biology: lipids include fats, oils, waxes and steroids.", "health", None),
    ("History of science: Fleming discovered penicillin, the first antibiotic.", "health", None),
    ("Computer studies: scan for infections; one infection can spread.", "health", None),
    ("The sun rises every morning.", None, "dose_word"),
    ("Wash your hands before meals.", None, "dose_word"),
    ("A car uses 5 litres of fuel per day.", None, "dose_word"),
    ("Chemistry: calcium carbonate reacts with dilute acid.", None, "medicine_name"),
    ("Physics: connect the AC 12 V supply to the coil.", None, "dose_word"),
])
def test_known_over_blocks_for_dr_amos(text, before, after):
    assert g.sensitive_topic(text) == before, text
    assert g.answer_problem(text, text, "en") == after, text
