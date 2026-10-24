"""Class levels and subjects, after the Nigerian national curriculum's subject names.

The app (app/assets/curriculum.json) and the teacher portal (portal/lib/curriculum.json)
carry copies of `as_json()`; tests/test_curriculum.py fails if either drifts.
"""
from __future__ import annotations

# Primary 1-6, Junior Secondary 1-3, Senior Secondary 1-3.
LEVELS: list[dict] = (
    [{"id": f"p{n}", "name": f"Primary {n}", "band": "primary_1_3" if n <= 3 else "primary_4_6"}
     for n in range(1, 7)]
    + [{"id": f"jss{n}", "name": f"JSS {n}", "band": "jss"} for n in range(1, 4)]
    + [{"id": f"sss{n}", "name": f"SSS {n}", "band": "sss"} for n in range(1, 4)]
)

BANDS: dict[str, str] = {
    "primary_1_3": "Primary 1–3",
    "primary_4_6": "Primary 4–6",
    "jss": "JSS 1–3",
    "sss": "SSS 1–3",
}

SUBJECTS: dict[str, str] = {
    "english": "English",
    "mathematics": "Mathematics",
    "basic_science": "Basic Science",
    "social_studies": "Social Studies",
    "hausa": "Hausa",
    "yoruba": "Yorùbá",
    "igbo": "Igbo",
    "biology": "Biology",
    "chemistry": "Chemistry",
    "physics": "Physics",
}

_LANGUAGES = ["hausa", "yoruba", "igbo"]
BAND_SUBJECTS: dict[str, list[str]] = {
    "primary_1_3": ["english", "mathematics", "basic_science", "social_studies", *_LANGUAGES],
    "primary_4_6": ["english", "mathematics", "basic_science", "social_studies", *_LANGUAGES],
    "jss": ["english", "mathematics", "basic_science", "social_studies", *_LANGUAGES],
    "sss": ["english", "mathematics", "biology", "chemistry", "physics", *_LANGUAGES],
}

# Primary mode: short spoken questions, two or three options.
PRIMARY_WORD_HINT = 15
PRIMARY_MAX_OPTIONS = 3
MAX_OPTIONS = 4
MIN_OPTIONS = 2

_BY_ID = {lv["id"]: lv for lv in LEVELS}


def band(level: str) -> str:
    return _BY_ID[level]["band"]


def is_level(level: str) -> bool:
    return level in _BY_ID


def is_primary(level: str) -> bool:
    return band(level).startswith("primary")


def max_options(level: str) -> int:
    return PRIMARY_MAX_OPTIONS if is_primary(level) else MAX_OPTIONS


def subjects_for(level: str) -> list[str]:
    return BAND_SUBJECTS[band(level)]


def as_json() -> dict:
    return {
        "levels": LEVELS,
        "bands": BANDS,
        "subjects": SUBJECTS,
        "band_subjects": BAND_SUBJECTS,
        "primary_word_hint": PRIMARY_WORD_HINT,
        "primary_max_options": PRIMARY_MAX_OPTIONS,
        "max_options": MAX_OPTIONS,
        "min_options": MIN_OPTIONS,
    }
