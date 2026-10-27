"""Class levels and subjects, after the Nigerian national curriculum's subject names.

The app (app/assets/curriculum.json) and the teacher portal (portal/lib/curriculum.json)
carry copies of `as_json()`; tests/test_curriculum.py fails if either drifts.
"""
from __future__ import annotations

# Primary 1-6, Junior Secondary 1-3, Senior Secondary 1-3. Schools also say "Basic": the 9-year
# Basic Education names (Basic 1-6 is Primary 1-6, Basic 7-9 is JSS 1-3); one level, both names.
LEVELS: list[dict] = (
    [{"id": f"p{n}", "name": f"Primary {n}", "band": "primary_1_3" if n <= 3 else "primary_4_6",
      "basic": f"Basic {n}"} for n in range(1, 7)]
    + [{"id": f"jss{n}", "name": f"JSS {n}", "band": "jss", "basic": f"Basic {n + 6}"} for n in range(1, 4)]
    + [{"id": f"sss{n}", "name": f"SSS {n}", "band": "sss"} for n in range(1, 4)]
)


def label(level: dict) -> str:
    """"Primary 4 (Basic 4)": what a teacher or learner picks from."""
    return f"{level['name']} ({level['basic']})" if level.get("basic") else level["name"]

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

# Primary mode: short spoken questions. Primary 1–3 has two or three options; Primary 4–6
# may have four (A–D), like JSS and SSS.
PRIMARY_WORD_HINT = 15
PRIMARY_MAX_OPTIONS = 3  # Primary 1–3
MAX_OPTIONS = 4
MIN_OPTIONS = 2
BAND_MAX_OPTIONS = {"primary_1_3": PRIMARY_MAX_OPTIONS, "primary_4_6": MAX_OPTIONS,
                    "jss": MAX_OPTIONS, "sss": MAX_OPTIONS}

_BY_ID = {lv["id"]: lv for lv in LEVELS}


def band(level: str) -> str:
    return _BY_ID[level]["band"]


def is_level(level: str) -> bool:
    return level in _BY_ID


def is_primary(level: str) -> bool:
    return band(level).startswith("primary")


def max_options(level: str) -> int:
    return BAND_MAX_OPTIONS[band(level)]


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
        "band_max_options": BAND_MAX_OPTIONS,
        "min_options": MIN_OPTIONS,
    }
