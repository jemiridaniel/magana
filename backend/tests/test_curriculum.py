"""The app and the teacher portal carry copies of the curriculum; they must match."""
import json
from pathlib import Path

import pytest

from app import curriculum, messages

ROOT = Path(__file__).parents[2]


@pytest.mark.parametrize("copy", ["app/assets/curriculum.json", "portal/lib/curriculum.json"])
def test_copies_match_the_backend(copy):
    path = ROOT / copy
    assert json.loads(path.read_text()) == curriculum.as_json(), (
        f"regenerate {copy}: python -c 'import json; from app import curriculum; "
        "print(json.dumps(curriculum.as_json(), ensure_ascii=False, indent=2))'")


def test_levels_and_subjects():
    assert [lv["name"] for lv in curriculum.LEVELS][:1] == ["Primary 1"]
    assert len(curriculum.LEVELS) == 12
    assert curriculum.is_primary("p6") and not curriculum.is_primary("jss1")
    assert "biology" in curriculum.subjects_for("sss2")
    assert "basic_science" in curriculum.subjects_for("p1")
    assert "biology" not in curriculum.subjects_for("jss3")
    assert curriculum.max_options("p2") == 3 and curriculum.max_options("sss1") == 4


def test_the_portal_words_every_portal_code():
    text = (ROOT / "portal/lib/messages.ts").read_text()
    missing = sorted(c for c in messages.PORTAL_CODES if f"{c}:" not in text)
    assert not missing, f"add these to portal/lib/messages.ts: {missing}"
