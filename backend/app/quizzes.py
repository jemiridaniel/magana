"""Teacher-made quizzes: saved by the teacher portal and assigned to one class session.
A teacher's quiz reaches only that session: the teacher opens it on a learner's phone with
the session's code (shown in the portal when assigning). Never everyone at a class level. Bundled sample packs use the same question shape
(app/assets/quiz/).

Quizzes are teacher content, never learner data: no names, answers or scores are stored
here. Each quiz is one JSON file in MAGANA_DATA_DIR/quizzes/.
"""
from __future__ import annotations

import json
import os
import re
import secrets
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from . import curriculum

LANGUAGES = ("en", "ha", "yo", "ig")


class Picture(BaseModel):
    # The picture file isn't stored yet; the description is what Magana reads aloud.
    name: str = Field("", max_length=200)
    description: str = Field("", max_length=600)


class Translation(BaseModel):
    question: str = Field("", max_length=500)
    # Unchecked until a teacher who speaks the language marks it checked. The app only
    # reads a checked translation.
    checked: bool = False


class Question(BaseModel):
    id: str = Field(default_factory=lambda: secrets.token_hex(4), pattern=r"^[A-Za-z0-9_-]{1,40}$")
    question: str = Field("", max_length=500)
    options: list[str] = Field(default_factory=list, max_length=6)
    answer: int | None = None  # index into options; None until marked
    praise: str = Field("", max_length=300)  # said after a right answer
    picture: Picture | None = None
    translations: dict[str, Translation] = Field(default_factory=dict)

    @field_validator("options")
    @classmethod
    def _short_options(cls, v: list[str]) -> list[str]:
        if any(len(o) > 200 for o in v):
            raise ValueError("an option is longer than 200 characters")
        return v

    @field_validator("translations")
    @classmethod
    def _known_languages(cls, v: dict[str, Translation]) -> dict[str, Translation]:
        unknown = set(v) - set(LANGUAGES)
        if unknown:
            raise ValueError(f"unknown languages {sorted(unknown)}")
        return v


class QuizIn(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    class_id: str = Field(..., pattern=r"^[A-Za-z0-9_-]{1,40}$")
    level: str
    subject: str
    languages: list[str] = Field(default_factory=lambda: ["en"])
    questions: list[Question] = Field(default_factory=list, max_length=50)

    @model_validator(mode="after")
    def _curriculum(self) -> "QuizIn":
        if not curriculum.is_level(self.level):
            raise ValueError(f"unknown class level {self.level!r}")
        if self.subject not in curriculum.subjects_for(self.level):
            raise ValueError(f"{self.subject!r} is not a subject for {self.level}")
        if not self.languages or "en" not in self.languages or set(self.languages) - set(LANGUAGES):
            raise ValueError("languages must include en and be from en, ha, yo, ig")
        return self


class Quiz(QuizIn):
    id: str
    status: Literal["draft", "assigned"] = "draft"
    session: str | None = None
    session_code: str | None = None  # the code that opens this class session in the app
    updated_at: str


# Session codes: 6 characters without look-alikes (no 0/O, 1/I/L), easy to read aloud.
CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_RE = re.compile(rf"^[{CODE_ALPHABET}]{{6}}$")


def new_code() -> str:
    return "".join(secrets.choice(CODE_ALPHABET) for _ in range(6))


class Problem(BaseModel):
    code: str
    question: int | None = None  # 1-based
    blocking: bool  # blocks assigning; others are warnings


def _words(text: str) -> int:
    return len(re.findall(r"\S+", text))


def check(quiz: QuizIn) -> list[Problem]:
    """The portal's "Before you assign" list. Blocking problems stop assigning."""
    out: list[Problem] = []
    if not quiz.questions:
        out.append(Problem(code="quiz_no_questions", blocking=True))
    most = curriculum.max_options(quiz.level)
    primary = curriculum.is_primary(quiz.level)
    for n, q in enumerate(quiz.questions, 1):
        def add(code: str, blocking: bool = True) -> None:
            out.append(Problem(code=code, question=n, blocking=blocking))

        if not q.question.strip():
            add("quiz_empty_question")
        if len(q.options) < curriculum.MIN_OPTIONS:
            add("quiz_too_few_options")
        if len(q.options) > most:
            add("quiz_too_many_options")
        if any(not o.strip() for o in q.options):
            add("quiz_empty_option")
        if q.answer is None or not 0 <= q.answer < len(q.options):
            add("quiz_no_right_answer")
        if q.picture is not None and not q.picture.description.strip():
            add("quiz_picture_needs_description")
        if primary and _words(q.question) > curriculum.PRIMARY_WORD_HINT:
            add("quiz_question_long", blocking=False)
        for lang in quiz.languages:
            if lang == "en":
                continue
            t = q.translations.get(lang)
            if t is not None and t.question.strip() and not t.checked:
                add("quiz_translation_unchecked", blocking=False)
    return out


def ready(quiz: QuizIn) -> bool:
    return not any(p.blocking for p in check(quiz))


def for_learner(quiz: Quiz) -> dict:
    """What the learner app gets: the questions and checked translations only."""
    return {
        "id": quiz.id,
        "title": quiz.title,
        "level": quiz.level,
        "subject": quiz.subject,
        "sample": False,
        "teacher_made": True,
        "questions": [
            {
                "id": q.id,
                "question": q.question,
                "options": q.options,
                "answer": q.answer,
                "explanation": q.praise,
                "picture": q.picture.description if q.picture else None,
                "translations": {
                    lang: t.question for lang, t in q.translations.items()
                    if lang in quiz.languages and t.checked and t.question.strip()
                },
            }
            for q in quiz.questions
        ],
    }


class QuizStore:
    """One JSON file per quiz. Writes are atomic (temp file, then rename)."""

    def __init__(self, root: Path):
        self.root = root
        self._lock = threading.Lock()

    def _path(self, quiz_id: str) -> Path:
        if not re.fullmatch(r"[a-f0-9]{12}", quiz_id):
            raise KeyError(quiz_id)
        return self.root / f"{quiz_id}.json"

    def _write(self, quiz: Quiz) -> Quiz:
        self.root.mkdir(parents=True, exist_ok=True)
        path = self._path(quiz.id)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(quiz.model_dump_json(indent=2), encoding="utf-8")
        tmp.replace(path)
        return quiz

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat(timespec="seconds")

    def create(self, data: QuizIn) -> Quiz:
        with self._lock:
            return self._write(Quiz(**data.model_dump(), id=secrets.token_hex(6), updated_at=self._now()))

    def get(self, quiz_id: str) -> Quiz:
        try:
            return Quiz.model_validate_json(self._path(quiz_id).read_text(encoding="utf-8"))
        except FileNotFoundError:
            raise KeyError(quiz_id) from None

    def update(self, quiz_id: str, data: QuizIn) -> Quiz:
        with self._lock:
            old = self.get(quiz_id)
            quiz = Quiz(**data.model_dump(), id=quiz_id, updated_at=self._now(), status=old.status, session=old.session)
            quiz.session_code = old.session_code
            if quiz.status == "assigned" and not ready(quiz):
                # An assigned quiz must stay ready: a broken edit takes it out of the session.
                quiz.status, quiz.session, quiz.session_code = "draft", None, None
            return self._write(quiz)

    def _codes(self) -> dict[str, str]:
        path = self.root / "session_codes.json"
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return {}

    def session_code(self, class_id: str, session: str) -> str:
        """One code per class session, the same for every quiz assigned to it."""
        codes = self._codes()
        key = f"{class_id}|{session}"
        if key not in codes:
            taken = set(codes.values())
            code = new_code()
            while code in taken:
                code = new_code()
            codes[key] = code
            self.root.mkdir(parents=True, exist_ok=True)
            tmp = self.root / "session_codes.tmp"
            tmp.write_text(json.dumps(codes, indent=2), encoding="utf-8")
            tmp.replace(self.root / "session_codes.json")
        return codes[key]

    def assign(self, quiz_id: str, session: str) -> Quiz:
        with self._lock:
            quiz = self.get(quiz_id)
            quiz.status, quiz.session, quiz.updated_at = "assigned", session, self._now()
            quiz.session_code = self.session_code(quiz.class_id, session)
            return self._write(quiz)

    def all(self) -> list[Quiz]:
        if not self.root.exists():
            return []
        quizzes = []
        for p in self.root.glob("*.json"):
            if p.name == "session_codes.json":
                continue
            try:
                quizzes.append(Quiz.model_validate_json(p.read_text(encoding="utf-8")))
            except (ValueError, OSError):
                continue
        return sorted(quizzes, key=lambda q: q.updated_at, reverse=True)


def default_store() -> QuizStore:
    return QuizStore(Path(os.environ.get("MAGANA_DATA_DIR", Path(__file__).parents[1] / "data")) / "quizzes")
