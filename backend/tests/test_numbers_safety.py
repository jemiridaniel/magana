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
from app.explain import bullets, check_answer
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
    by_source = {l["source"].lower(): l["text"] for l in body["lines"]}
    dose = by_source["take 1 to 2 tablets every 4 to 6 hours as needed."]
    if mode == "health":
        # The clinically approved Hausa template, with the label's own numbers in its slots.
        assert dose == "Sha ƙwaya 1 zuwa 2 duk bayan sa'o'i 4 zuwa 6 gwargwadon bukata."
    else:
        assert dose is None  # money and letters don't use health templates: English as printed
    # Lines without an approved template are read in English as printed, with the warning.
    assert any(text is None for text in by_source.values())
    assert body["fallback"] == ("cant_translate_line_health" if mode == "health" else "cant_translate_line_money")


def test_health_papers_need_an_adult_account(engine):
    r = client.post("/explain", json={"source_text": LABEL, "mode": "health"},
                    headers={"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"})
    assert r.json()["detail"] == {"code": "not_allowed_for_tier"}


def test_outside_development_papers_still_get_their_approved_templates(engine, monkeypatch):
    """Explain (the model) is off outside development, but health papers never use a model:
    the approved templates work in tester and production builds too."""
    monkeypatch.setenv("MAGANA_ENV", "production")
    body = client.post("/explain", json={"source_text": LABEL, "mode": "health", "lang": "yo"},
                       headers={"X-Magana-Tier": "standard"}).json()
    assert engine.calls == [] and body["code"] == "paper_lines"
    assert any(l["template"] for l in body["lines"])
    school = client.post("/explain", json={"source_text": "Plants make food.", "mode": "school", "lang": "yo"},
                         headers={"X-Magana-Tier": "standard"}).json()
    assert school["code"] == "explain_not_available"


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


def test_each_placeholder_at_most_once_and_no_others_left_out_is_allowed():
    source = "Take 2 tablets every 4 to 6 hours."  # ⟦N1⟧ every ⟦N2⟧ to ⟦N3⟧
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧.", source, "ha") == set()
    # Left out: allowed, nothing numeric was added (the app points to the page).
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧.", source, "ha") == set()
    # Left out and a number added instead: refused.
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧ zuwa 8.", source, "ha") == {"digit"}
    assert problems_with("Sha ⟦N1⟧ ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧.", source, "ha") == {"placeholder_repeated"}
    assert problems_with("Sha ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧ ⟦N9⟧.", source, "ha") == {"placeholder_unknown"}


def test_an_answer_that_leaves_numbers_out_is_given_and_points_to_the_page(engine):
    engine.answer = "Sha magani kamar yadda aka rubuta a takardar."  # no markers at all
    body = client.post("/explain", json={"source_text": "Take 2 tablets every 4 to 6 hours.", "lang": "ha"},
                       headers={"X-Magana-Tier": "standard"}).json()
    assert (body["code"], body["followup"]) == ("explained", "numbers_left_out")
    assert body["explanation"] == "Sha magani kamar yadda aka rubuta a takardar."


def test_an_answer_with_every_marker_needs_no_followup(engine):
    engine.answer = "Sha ⟦N1⟧ kowane ⟦N2⟧ zuwa ⟦N3⟧."
    body = client.post("/explain", json={"source_text": "Take 2 tablets every 4 to 6 hours.", "lang": "ha"},
                       headers={"X-Magana-Tier": "standard"}).json()
    assert body["code"] == "explained" and "followup" not in body


def test_an_answer_that_adds_a_number_is_still_refused(engine):
    engine.answer = "Sha ⟦N1⟧ sau 3 a rana."  # "3 times a day" is not on the page
    body = client.post("/explain", json={"source_text": "Take 2 tablets every 4 to 6 hours.", "lang": "ha"},
                       headers={"X-Magana-Tier": "standard"}).json()
    assert body["code"] == "numbers_unconfirmed" and "followup" not in body


def test_the_pages_exact_text_comes_back():
    source = "Pay N2,500 before 30 November 2026. VAT 7.5%: N951.39. Store below 30 °C."
    masked = P.mask(source)
    assert masked.slots == ["N2,500", "30 November 2026", "7.5%", "N951.39", "30 °C"]
    answer = "Biya ⟦N1⟧ kafin ⟦N2⟧. VAT ⟦N3⟧: ⟦N4⟧. Ajiye ƙasa da ⟦N5⟧."
    text, problems = check_answer(answer, masked, None, "ha")
    assert problems == []
    assert text == "Biya N2,500 kafin 30 November 2026. VAT 7.5%: N951.39. Ajiye ƙasa da 30 °C."


@pytest.mark.parametrize("answer, lang, refused", [
    ("Kowane minti ⟦N1⟧.", "ha", True),       # every ⟦N1⟧ MINUTES: a unit next to a number
    ("A bar shi na ⟦N1⟧ days.", "ha", True),  # English unit added after the number
    ("Ewe ti o wa ni ⟦N1⟧ wákàtí.", "yo", True),
    ("Shekara tana da ⟦N1⟧.", "ha", False),    # "a year has …": shekara as an ordinary noun
    ("Fọ ọwọ́ rẹ pẹ̀lú ọṣẹ fún ⟦N1⟧.", "yo", False),  # ọṣẹ (soap), not ọ̀sẹ̀ (week)
    ("Afọ nwere ⟦N1⟧.", "ig", False),          # "a year has …" in Igbo
    ("Ṅụọ ya kwa awa ⟦N1⟧.", "ig", True),       # every ⟦N1⟧ HOURS
])
def test_unit_words_are_refused_only_next_to_a_number(answer, lang, refused):
    found = problems_with(answer, "A year has 12 months.", lang)
    assert ("unit_word" in found) is refused, found


def test_a_degree_sign_belongs_to_its_number():
    masked = P.mask("The angles in a triangle add up to 180°. One angle is 90°.")
    assert masked.slots == ["180°", "One", "90°"]


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

HELD_IGBO = {"swallow_whole_with_water", "shake_well", "store_cool_dry", "expiry_date"}  # #7, #9, #12, #13


def test_the_15_medicine_label_templates_are_approved_with_matching_slots():
    """First clinical sign-off (25/10/2026): Hausa and Yorùbá all 15; Igbo 11, with #7, #9,
    #12 and #13 held in English until the Igbo reviewer adds tone marks (and fixes #9)."""
    doc = json.loads((P.content_dir() / "templates" / "medicine_label.json").read_text())
    assert doc["domain"] == "health" and len(doc["templates"]) == 15
    assert len({t["id"] for t in doc["templates"]}) == 15
    for t in doc["templates"]:
        slots = {frozenset(T.SLOT.findall(f)) for f in t["en"]}
        assert len(slots) == 1, t["id"]  # every English form has the same slots
        for lang in ("ha", "yo", "ig"):
            tr = t["translations"][lang]
            assert tr["status"] in T.STATUSES
            held = lang == "ig" and t["id"] in HELD_IGBO
            assert tr["status"] == ("native_reviewed" if held else "clinically_approved"), (t["id"], lang)
            if not held:
                assert (tr["approved_by"], tr["approved_on"]) == ("clinical lead", "2026-10-25")
            # Every placeholder survives, once each, in every translation.
            assert sorted(T.SLOT.findall(tr["text"])) == sorted(next(iter(slots))), (t["id"], lang)
    # No reviewer's name in the public repo until they agree to be credited.
    text = (P.content_dir() / "templates" / "medicine_label.json").read_text()
    assert not any(n in text for n in ("Amos", "Samanja", "Anyanwu"))


def test_the_reviewers_fixes_are_in():
    by = {t.id: t.translations for t in T.load()}
    assert by["before_meals"]["ha"]["text"] == "A sha kafin a ci abinci."
    assert by["external_use_only"]["yo"]["text"] == "Fún lílò sára nìkan."
    assert by["expiry_date"]["ha"]["text"] == "Ranar lalacewa: {a}"
    assert by["expiry_date"]["yo"]["text"] == "Ọjọ́ ìbàjẹ́: {a}"
    assert "kwa awa {c} ruo {d}" in by["take_range_every_range_hours_as_needed"]["ig"]["text"]


def test_an_approved_label_is_read_in_hausa_and_a_held_igbo_line_in_english():
    r = T.translate("Take 2 tablets 3 times a day. Expiry date: 08/2027.", "ha", "health")
    assert [l["text"] for l in r["lines"]] == ["Sha ƙwaya 2 sau 3 a rana.", "Ranar lalacewa: 08/2027"]
    r = T.translate("Take 2 tablets 3 times a day. Shake well before use.", "ig", "health")
    assert r["lines"][0]["text"] == "Ṅụọ mkpụrụ ọgwụ 2 ugboro 3 n'ụbọchị."
    assert r["lines"][1]["text"] is None and r["fallback"] == "cant_translate_line_health"


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
    r = T.translate("Shake well before use. Batch: PCM2291.", "ig", "health", statuses={"native_reviewed"})
    assert [l["template"] for l in r["lines"]] == ["shake_well", None, None]
    assert r["fallback"] == "cant_translate_line_health"


# ---------- the model's own list numbering

@pytest.mark.parametrize("answer, expected", [
    ("Steps:\n1. Starch\n2. Sugar\n3. Fat", "Steps:\n• Starch\n• Sugar\n• Fat"),
    ("1) Starch\n2) Sugar", "• Starch\n• Sugar"),
    ("  1. indented\n  2. too", "  • indented\n  • too"),
    # Not a plain sequence from 1: left alone, so the check refuses the digits.
    ("1. Starch\n3. Fat", "1. Starch\n3. Fat"),
    ("2. Sugar\n3. Fat", "2. Sugar\n3. Fat"),
    ("1. Starch\n2. Sugar\n1. Again", "1. Starch\n2. Sugar\n1. Again"),
    # Not at the start of a line, or not followed by a space: not list numbering.
    ("Heat for 5. Then wait.", "Heat for 5. Then wait."),
    ("1.5 litres", "1.5 litres"),
])
def test_list_numbering_becomes_bullets_only_as_a_plain_sequence(answer, expected):
    assert bullets(answer) == expected


def test_bullets_then_the_check_still_refuses_numbers_inside_the_items():
    page = P.mask("Starch | Iodine\nSugar | Benedict, heat for 5 minutes")
    text, problems = check_answer("1. Starch: iodine.\n2. Sugar: heat for ⟦N1⟧.", page, None, "en")
    assert problems == [] and text == "• Starch: iodine.\n• Sugar: heat for 5 minutes."
    _, problems = check_answer("1. Starch: iodine.\n2. Sugar: heat for 5 minutes.", page, None, "en")
    assert {p.code for p in problems} == {"digit", "unit_word"}  # the 5 the model wrote


# ---------- A number read entirely as letters (bank statement, docs/FINDINGS.md)

def _line(*words):
    return {"text": " ".join(t for t, _ in words), "confidence": 0.8,
            "words": [{"text": t, "confidence": c} for t, c in words]}


def test_a_date_read_as_letters_is_unreadable_never_repaired():
    from app import safety

    warned = safety.number_warnings([_line(("OZ", 0.5), ("Sep", 0.95), ("2026", 0.96))])
    assert [(w.code, w.word_index) for w in warned] == [("unreadable_number", 0)]
    warned = safety.number_warnings([_line(("Balance", 0.96), ("lO", 0.6), ("500", 0.97))])
    assert ("unreadable_number", 1) in [(w.code, w.word_index) for w in warned]


def test_real_words_beside_numbers_are_not_flagged():
    from app import safety

    for line in [_line(("I", 0.6), ("take", 0.95), ("2", 0.97), ("tablets", 0.95)),
                 _line(("2", 0.97), ("oz", 0.6)),
                 _line(("Do", 0.6), ("2", 0.97), ("sums", 0.95)),
                 _line(("OZ", 0.97), ("Sep", 0.95), ("2026", 0.96))]:  # confident: not a half-read
        assert [w for w in safety.number_warnings([line]) if w.code == "unreadable_number"] == []


def test_two_readings_agree_only_with_the_decimal_point_in_the_same_place():
    from app import safety

    line = {"text": "Debit 999", "confidence": 0.85, "words": [
        {"text": "Debit", "confidence": 0.95},
        {"text": "999", "confidence": 0.85, "reread_text": "9.99", "reread_confidence": 0.9}]}
    assert [(w.code, w.word_index) for w in safety.number_warnings([line])] == [("number_mismatch", 1)]
    line["words"][1]["reread_text"] = "999"
    assert safety.number_warnings([line]) == []  # both readings 999 and both ≥ 0.80
    commas = {"text": "45,250.50", "confidence": 0.85, "words": [
        {"text": "45,250.50", "confidence": 0.85, "reread_text": "45250.50", "reread_confidence": 0.9}]}
    assert safety.number_warnings([commas]) == []  # the same amount


def test_an_unsure_day_before_a_month_is_unreadable():
    from app import safety

    warned = safety.number_warnings([_line(("oe", 0.6), ("Sep", 0.95), ("2026", 0.96))])
    assert [(w.code, w.word_index) for w in warned] == [("unreadable_number", 0)]
