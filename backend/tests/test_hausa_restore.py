"""Hausa pages (Brydl's review of the Hausa pack, 13 Nov 2026): Tesseract reads the hooked ƙ as a
capital K and sometimes writes ɗ as đ. letters.restore_hausa puts these back where it is safe,
and every word it changes stays marked for a person to check."""
import pytest

from app import letters

pytestmark = pytest.mark.safety


def line(text: str, with_words: bool = True) -> dict:
    out = {"text": text}
    if with_words:
        out["words"] = [{"text": w} for w in text.split()]
    return out


def restored(text: str, with_words: bool = True) -> tuple[str, list[int]]:
    lines = [line(text, with_words)]
    letters.restore_hausa(lines)
    marked = [m["word_index"] for m in letters.marks(lines, "ha") if m["kind"] == "special_letter"]
    return lines[0]["text"], marked


@pytest.mark.parametrize("with_words", [True, False])
def test_a_capital_k_mid_sentence_is_hooked_k_and_the_word_stays_marked(with_words):
    text, marked = restored("Ita ce Kungiyar mafi girma.", with_words)
    assert text == "Ita ce ƙungiyar mafi girma."
    assert 2 in marked


def test_the_words_list_entry_changes_too():
    lines = [line("Ita ce Kungiyar mafi girma.")]
    letters.restore_hausa(lines)
    assert [w["text"] for w in lines[0]["words"]] == ["Ita", "ce", "ƙungiyar", "mafi", "girma."]
    assert lines[0]["restored_words"] == [2]


@pytest.mark.parametrize("text", [
    "Kungiyar ta kafa makaranta.",           # the line's first word: may start a sentence
    "Ya tafi. Kungiyar ta kafa makaranta.",  # after a full stop
    "Me ya faru? Kungiyar ta zo.",           # after a question mark
    "Ya ce \"Ka zo!\" Kungiyar ta zo.",      # after ! and a closing quote
    "Ya je Kano jiya.",                      # a name: "ƙano" is not in the word list
    "Ya ga KUNGIYAR jiya.",                  # capitals: a heading or a shout, left alone
])
def test_a_capital_k_that_may_be_a_capital_stays_as_read(text):
    assert restored(text)[0] == text


def test_a_small_k_is_never_changed_only_marked():
    text, marked = restored("Ita ce kungiyar mafi girma.")
    assert text == "Ita ce kungiyar mafi girma."
    assert 2 in marked  # marked as before (may_miss_letter)


def test_punctuation_around_the_word_is_kept():
    assert restored("Wannan ta (Kungiyar) ce.")[0] == "Wannan ta (ƙungiyar) ce."
    assert restored("Wannan ta Kungiyar, ce.")[0] == "Wannan ta ƙungiyar, ce."


@pytest.mark.parametrize("before, after", [
    ("Yana da đalibai da yawa.", "Yana da ɗalibai da yawa."),
    ("Đan Adam yana nan.", "Ɗan Adam yana nan."),
    ("Ya ga đan uwansa.", "Ya ga ɗan uwansa."),
])
def test_d_with_stroke_is_hooked_d_on_hausa_pages_and_marked(before, after):
    text, marked = restored(before)
    assert text == after
    changed = [i for i, (a, b) in enumerate(zip(before.split(), after.split())) if a != b]
    assert set(changed) <= set(marked)


def test_spacing_in_the_line_text_is_kept():
    lines = [{"text": "Ita ce  Kungiyar   mafi", "words": [{"text": w} for w in ["Ita", "ce", "Kungiyar", "mafi"]]}]
    letters.restore_hausa(lines)
    assert lines[0]["text"] == "Ita ce  ƙungiyar   mafi"


def test_only_hausa_pages_are_restored(monkeypatch):
    """reader.read_page calls restore_hausa for page_language "ha" only."""
    import inspect

    from app import reader
    src = inspect.getsource(reader.read_page)
    assert 'if language == "ha":\n        letters.restore_hausa(result["lines"])' in src
