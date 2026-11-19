"""The page check before the model (natlas_guard.sensitive_topic), two fixes of 19 Nov 2026:
- a word and its plain -s/-es plural count as one word toward "two different words";
- a page clearly in Hausa, Yorùbá or Igbo is checked against that language's lists and English
  only, so an Igbo word that shares a Yorùbá spelling ("egbe") doesn't stop a Yorùbá page.
Pages whose language isn't clear are still checked against all four (the safe side)."""
import json
from pathlib import Path

import pytest

from llm import natlas_guard as g

pytestmark = pytest.mark.safety
ROOT = Path(__file__).resolve().parents[2]
NIGHTLY = json.loads((ROOT / "backend/tests/safety/natlas_refusal/pages.json").read_text(encoding="utf-8"))


# ---------- a word and its plural are one word

@pytest.mark.parametrize("text", [
    "Computer studies: scan for infections; one infection can spread.",
    "Agriculture: this disease spreads, and diseases of maize are common.",
    "Our doctor and other doctors visited the school.",
    "Hospitals and the hospital near the school.",
])
def test_a_word_and_its_plural_count_once(text):
    assert g.sensitive_topic(text) is None, text


@pytest.mark.parametrize("text", [
    "Infections and fever.",
    "Diseases treated at the clinic.",
    "Doctors and nurses.",
])
def test_two_different_words_still_stop_the_page(text):
    assert g.sensitive_topic(text) == "health", text


def test_the_plural_rule_needs_the_singular_on_the_same_list():
    listed = frozenset(g._fold(t) for t in g._topics()["en"]["health"]["words"])
    assert g._one_word("infections", listed) == "infection"
    assert g._one_word("diseases", listed) == "disease"
    assert g._one_word("Diarrhoea", listed) == "diarrhoea"
    assert g._one_word("symptoms", listed) == "symptoms"  # "symptom" isn't listed: stays its own word


def test_spellings_that_fold_to_one_form_count_once():
    # Hausa "kuɗi" and "kudi" are the same word with and without its hooked letter.
    listed = frozenset(g._fold(t) for t in g._topics()["ha"]["money"]["words"])
    assert g._one_word("kuɗi", listed) == g._one_word("kudi", listed)


# ---------- the page's own language (and English)

YORUBA = ("Ìlú náà wà ní ìpínlẹ̀ Ògùn. Àwọn ènìyàn ibẹ̀ máa ń ṣe iṣẹ́ àgbẹ̀, wọ́n sì ń ta ọjà ní "
          "ọjà ńlá. Egbe àwọn ọ̀dọ́ ló ṣe ètò náà, gbogbo ènìyàn sì wá síbẹ̀ láti wo ìjó àti orin.")


def test_a_yoruba_page_is_checked_with_yoruba_and_english_only():
    assert g.topic_languages(YORUBA) == ["en", "yo"]


def test_an_igbo_word_does_not_stop_a_yoruba_page():
    assert "egbe" in g._topics()["ig"]["harm"]["strong"]
    assert g.sensitive_topic(YORUBA) is None


def test_english_terms_still_count_on_a_yoruba_page():
    assert g.sensitive_topic(YORUBA + " Ẹ lọ sí hospital láti gba vaccine.") == "health"


def test_a_page_whose_language_is_unclear_uses_every_list():
    assert g.topic_languages("egbe") == ["en", "ha", "yo", "ig"]
    assert g.sensitive_topic("egbe") == "harm"


@pytest.mark.parametrize("lang, page", [(l, p) for l in ("en", "ha", "yo", "ig") for p in NIGHTLY[l]],
                         ids=lambda x: x["id"] if isinstance(x, dict) else x)
def test_every_nightly_page_keeps_its_result(lang, page):
    topic = g.sensitive_topic(page["text"])
    if page["kind"] == "control":
        assert topic is None
    else:
        assert topic == page["kind"]
    # Never checked without its own language's list.
    assert lang in g.topic_languages(page["text"])
