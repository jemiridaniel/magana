"""The redesigned number safety (docs/FINDINGS.md, N-ATLaS run of 24 Oct 2026).

The cases that got through the old guard, and the ones it caught, are kept here as answers a
model actually gave. Each must now be refused: on a health or money page the model is never
asked; on schoolwork the placeholder check rejects the answer.
"""
import json

import pytest
from fastapi.testclient import TestClient

from app import placeholders as P
from app import templates as T
from app.explain import check_answer
from app.main import app, get_explain_engine

client = TestClient(app)


@pytest.fixture(autouse=True)
def development(monkeypatch):
    monkeypatch.setenv("MAGANA_ENV", "development")


class Recording:
    preview = False

    def __init__(self, answer="ok"):
        self.answer, self.calls = answer, []

    def complete(self, system, user, timeout):
        self.calls.append(user)
        return self.answer


@pytest.fixture
def engine():
    e = Recording()
    app.dependency_overrides[get_explain_engine] = lambda: e
    yield e
    app.dependency_overrides.clear()


def page(name: str) -> str:
    return (P.content_dir().parent / "benchmark" / "explain" / "pages" / name).read_text().strip()


def problems_with(answer: str, source: str, lang: str) -> set[str]:
    masked = P.mask(source)
    _, problems = check_answer(answer, masked, None, lang)
    return {p.code for p in problems}


# ---------- what got through before: health papers never reach the model now

LABEL = page("04_medicine_label.txt")


@pytest.mark.parametrize("mode", ["health", "money", "letter"])
def test_health_and_money_papers_never_reach_the_model(engine, mode):
    # The Hausa answer that passed the old guard: "every 4 to 6 MINUTES".
    engine.answer = "Sha guda daya zuwa biyu kowane minti 4 zuwa 6 a matsayin bukata."
    body = client.post("/explain", json={"source_text": LABEL, "lang": "ha", "mode": mode},
                       headers={"X-Magana-Tier": "standard"}).json()
    assert engine.calls == []
    assert body["code"] == "paper_lines" and body["explanation"] is None
    assert "minti" not in json.dumps(body, ensure_ascii=False)
    # No template is approved yet: every line is read in English as printed, with the warning.
    assert all(line["text"] is None for line in body["lines"])
    assert "take 1 to 2 tablets every 4 to 6 hours as needed." in [l["source"] for l in body["lines"]]
    assert body["fallback"] == ("cant_translate_line_health" if mode == "health" else "cant_translate_line_money")


def test_health_papers_need_an_adult_account(engine):
    r = client.post("/explain", json={"source_text": LABEL, "mode": "health"},
                    headers={"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"})
    assert r.json()["detail"] == {"code": "not_allowed_for_tier"}


def test_outside_development_explain_stays_off_for_papers_too(engine, monkeypatch):
    monkeypatch.setenv("MAGANA_ENV", "production")
    body = client.post("/explain", json={"source_text": LABEL, "mode": "health", "lang": "yo"},
                       headers={"X-Magana-Tier": "standard"}).json()
    assert body["code"] == "explain_not_available"


# ---------- schoolwork: the answers the old guard missed or caught, now all refused

@pytest.mark.parametrize("answer, source, lang, expect", [
    # "Every 4 to 6 MINUTES" (Hausa), if it were schoolwork: digits and a unit word.
    ("Sha guda daya zuwa biyu kowane minti 4 zuwa 6.", LABEL, "ha", {"digit", "unit_word"}),
    # The 120-litre tank became "20 litres" in Igbo words.
    ("Otu tanki mmiri juputara lita iri abụọ.", page("03_fractions.txt"), "ig", {"number_word", "unit_word"}),
    # "over 12 years" became "ogbon odun mejila" (thirty, years, twelve) in Yorùbá.
    ("Fun awon omo ti o ju ogbon odun mejila lo.", LABEL, "yo", {"number_word", "unit_word"}),
    # Arithmetic the prompt forbids (English, Igbo, Yorùbá rainfall).
    ("The difference is ⟦N6⟧ − ⟦N7⟧ = 180 mm.", page("10_rainfall.txt"), "en", {"arithmetic", "digit"}),
    ("Ihe dị iche bụ ⟦N6⟧-⟦N7⟧.", page("10_rainfall.txt"), "ig", {"arithmetic"}),
    # The wrong difference: "80 mm (460 - 280)" (Hausa).
    ("Bambancin shine 80 mm (460 - 280).", page("10_rainfall.txt"), "ha", {"digit"}),
    # "120 × 2/5 = 48" (Hausa, Yorùbá fractions).
    ("120 * (2/5) = 48 lita.", page("03_fractions.txt"), "ha", {"digit", "unit_word"}),
    # Wrong months on the bank statement: "Oṣu Kẹta 3" (March 3) for October 3.
    ("Owo jade ni Oṣu Kẹta 3 fun Ada.", page("06_bank_statement.txt"), "yo", {"digit", "number_word"}),
    # N2,500 garbled to "puku naira abụọ,500" (Igbo).
    ("A na-arịọ ezinụlọ ka ha kwụọ ego PTA nke puku naira abụọ,500.", page("07_school_notice.txt"), "ig",
     {"digit", "number_word", "unit_word"}),
    # "from birth to 40 weeks" (Yorùbá vaccination card): "ogoji (40)".
    ("Láti ìbímọ sí ogójì (40) ọ̀sẹ̀.", page("09_vaccination_card.txt"), "yo", {"digit", "number_word", "unit_word"}),
])
def test_the_old_benchmark_problems_are_all_refused(answer, source, lang, expect):
    found = problems_with(answer, source, lang)
    assert expect <= found, found


def test_every_placeholder_exactly_once_and_no_others():
    source = "Take 2 tablets every 4 to 6 hours."  # ⟦N1⟧ every ⟦N2⟧ to ⟦N3⟧
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧.", source, "ha") == set()
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧.", source, "ha") == {"placeholder_missing"}
    assert problems_with("Sha ⟦N1⟧ ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧.", source, "ha") == {"placeholder_repeated"}
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧ ⟦N9⟧.", source, "ha") == {"placeholder_unknown"}


def test_the_pages_exact_text_comes_back():
    source = "Pay N2,500 before 30 November 2026. VAT 7.5%: N951.39. Store below 30 °C."
    masked = P.mask(source)
    assert masked.slots == ["N2,500", "30 November 2026", "7.5%", "N951.39", "30 °C"]
    answer = "Biya ⟦N1⟧ kafin ⟦N2⟧. VAT ⟦N3⟧: ⟦N4⟧. Ajiye ƙasa da ⟦N5⟧."
    text, problems = check_answer(answer, masked, None, "ha")
    assert problems == []
    assert text == "Biya N2,500 kafin 30 November 2026. VAT 7.5%: N951.39. Ajiye ƙasa da 30 °C."


def test_a_range_is_one_placeholder_so_a_dash_between_two_is_arithmetic():
    masked = P.mask("Normal range: 12.0 – 16.0 g/dL")
    assert masked.slots == ["12.0 – 16.0 g/dL"]


def test_words_printed_on_the_page_may_be_repeated():
    # "mm" is on the rainfall page outside any number.
    assert "unit_word" not in problems_with(
        "Rainfall in mm: " + " ".join(f"⟦N{k}⟧" for k in range(1, 13)), page("10_rainfall.txt"), "en")


def test_tone_marks_dropped_by_the_model_still_count_and_exact_only_words_need_them():
    src = "Read the page."
    assert "number_word" in problems_with("O ni meji.", src, "yo")  # méjì without marks
    assert "number_word" in problems_with("Ka sha ɗari.", src, "ha")
    assert "number_word" in problems_with("Ka sha dari.", src, "ha")  # hook dropped
    assert "number_word" in problems_with("Ogún ọmọ.", src, "yo")  # twenty
    assert "number_word" not in problems_with("Ogun ni.", src, "yo")  # war, not twenty


def test_the_question_may_have_its_own_numbers():
    masked = P.mask("Amina has 3/4 of a loaf.")
    asked = P.mask("Why 3/4?", start=2)
    text, problems = check_answer("⟦N1⟧ ni rabon ⟦N2⟧.", masked, asked, "ha")
    assert problems == [] and text == "3/4 ni rabon 3/4."


def test_number_word_lists_are_drafts_needing_native_review():
    for lang in P.LANGUAGES:
        d = json.loads((P.content_dir() / "number_words" / f"{lang}.json").read_text())
        assert d["status"] == "draft" and d["review"].startswith("NEEDS NATIVE REVIEW")
        assert d["words"] and d["units"]


# ---------- templates

def test_the_15_medicine_label_templates_are_drafts_with_matching_slots():
    doc = json.loads((P.content_dir() / "templates" / "medicine_label.json").read_text())
    assert doc["domain"] == "health" and len(doc["templates"]) == 15
    assert len({t["id"] for t in doc["templates"]}) == 15
    for t in doc["templates"]:
        slots = {frozenset(T.SLOT.findall(f)) for f in t["en"]}
        assert len(slots) == 1, t["id"]  # every English form has the same slots
        for lang in ("ha", "yo", "ig"):
            tr = t["translations"][lang]
            assert tr["status"] in T.STATUSES
            assert tr["status"] == "draft"  # none reviewed yet
            assert frozenset(T.SLOT.findall(tr["text"])) == next(iter(slots)), (t["id"], lang)


def test_only_clinically_approved_health_templates_are_used(monkeypatch):
    t = next(x for x in T.load() if x.id == "not_more_than_in_hours")
    line = "Do not take more than 8 tablets in 24 hours."
    for status, used in [("draft", False), ("native_reviewed", False), ("clinically_approved", True)]:
        monkeypatch.setitem(t.translations, "ha", {"text": "Kada ka sha fiye da ƙwaya {a} cikin sa'o'i {b}.",
                                                   "status": status})
        got = T.translate(line, "ha", "health")["lines"][0]
        assert (got["text"] is not None) is used, status
    # The slots take the page's exact text.
    assert got["text"] == "Kada ka sha fiye da ƙwaya 8 cikin sa'o'i 24."


def test_english_needs_no_template_and_unmatched_lines_keep_their_english():
    r = T.translate(LABEL, "en", "health")
    assert r["fallback"] is None and all(l["text"] == l["source"] for l in r["lines"])
    r = T.translate("Shake well before use. Batch: PCM2291.", "ig", "health", statuses={"draft"})
    assert [l["template"] for l in r["lines"]] == ["shake_well", None, None]
    assert r["fallback"] == "cant_translate_line_health"
