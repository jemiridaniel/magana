"""Hausa pages (Brydl's review of the Hausa pack, 13 Nov 2026): Tesseract reads the hooked ƙ as a
capital K and sometimes writes ɗ as đ. letters.restore_hausa puts these back where it is safe,
and every word it changes stays marked for a person to check."""
import json
from pathlib import Path

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


CASES = json.loads((Path(__file__).parent / "fixtures" / "letters" / "hausa_restore_cases.json")
                   .read_text(encoding="utf-8"))["cases"]


@pytest.mark.parametrize("with_words", [True, False])
@pytest.mark.parametrize("case", CASES, ids=[c["why"] for c in CASES])
def test_shared_cases_the_phone_passes_too(case, with_words):
    """The same cases as app/test/hausa_restore_test.dart."""
    assert restored(case["line"], with_words) == (case["restored"], case["marked"])


def test_the_words_list_entry_changes_too():
    lines = [line("Ita ce Kungiyar mafi girma.")]
    letters.restore_hausa(lines)
    assert [w["text"] for w in lines[0]["words"]] == ["Ita", "ce", "ƙungiyar", "mafi", "girma."]
    assert lines[0]["restored_words"] == [2]


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


def test_the_word_list_has_a_plain_then_hooked_word_so_none_are_merged():
    """Brydl's review, 22 Nov 2026: "hadđaka" (haɗaka) has a plain d before its own hooked one.
    Merging the pair would be safe only if Hausa never writes one; our word list has "habɓakar"
    (from Wikipedia, likely haɓakar misspelt), so such words are left as read and marked. If
    this list changes, decide again (docs/FINDINGS.md, 22 Nov 2026). 23 Nov 2026: habɓakar is
    6 uses in the 1 Oct dump (haɓakar 1,690), above the bar for removing it; and 8 of the
    dump's 36 pair words are a doubled letter ("sharudɗan": sharuɗɗan), so a merge into one
    hooked letter would misspell them."""
    words = (Path(__file__).parents[2] / "content/word_lists/ha.txt").read_text(encoding="utf-8").split()
    assert sorted({w for w in words if letters._PAIR.search(w)}) == ["habɓakar"]


def test_a_held_word_is_listed_and_unchanged():
    lines = [line("Ana kiran ta hadđaka a nan.")]
    letters.restore_hausa(lines)
    assert lines[0]["held_words"] == [3]
    assert "restored_words" not in lines[0]
    assert lines[0]["text"] == "Ana kiran ta hadđaka a nan."
