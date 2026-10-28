"""Teacher-made quizzes: saved by the teacher portal and assigned to one class session.
A teacher's quiz reaches only that session: the teacher opens it on a learner's phone with
the session's code (shown in the portal when assigning). Never everyone at a class level.
Each quiz belongs to the teacher who wrote it (and their school); a teacher sees only their
own, a school admin the school's. Session codes are 6 digits (codes.py), stored as a keyed
hash plus a sealed copy for their teacher. Bundled sample packs use the same question shape
(app/assets/quiz/).

Quizzes are teacher content, never learner data: no names, answers or scores are stored
here. Each quiz is one record in the database (blobs.py).
"""
from __future__ import annotations

import json
import re
import secrets
import threading
from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from . import blobs, codes, curriculum

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
    owner: str | None = None       # the teacher (staff id) who wrote it
    school_id: str | None = None
    status: Literal["draft", "assigned"] = "draft"
    session: str | None = None
    session_lookup: str | None = None  # keyed hash of the session's code (codes.lookup)
    session_sealed: str | None = None  # the code itself, sealed, for its teacher only
    updated_at: str

    def for_teacher(self) -> dict:
        out = self.model_dump(exclude={"session_lookup", "session_sealed"})
        out["session_code"] = codes.unseal(self.session_sealed) if self.session_sealed else None
        return out


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
    """One database record per quiz (blobs.py, kind "quiz"), and the classes' session codes in
    one more ("quiz_codes"). Never on the server's disk, which the test-phase host loses."""

    def __init__(self, kind: str = "quiz"):
        self.kind = kind
        self._lock = threading.Lock()

    @staticmethod
    def _check(quiz_id: str) -> str:
        if not re.fullmatch(r"[a-f0-9]{12}", quiz_id):
            raise KeyError(quiz_id)
        return quiz_id

    def _write(self, quiz: Quiz) -> Quiz:
        blobs.put_text(self.kind, self._check(quiz.id), quiz.model_dump_json(indent=2))
        return quiz

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat(timespec="seconds")

    def create(self, data: QuizIn, owner: str | None = None, school_id: str | None = None) -> Quiz:
        with self._lock:
            return self._write(Quiz(**data.model_dump(), id=secrets.token_hex(6), updated_at=self._now(),
                                    owner=owner, school_id=school_id))

    def get(self, quiz_id: str) -> Quiz:
        text = blobs.get_text(self.kind, self._check(quiz_id))
        if text is None:
            raise KeyError(quiz_id)
        return Quiz.model_validate_json(text)

    def update(self, quiz_id: str, data: QuizIn) -> Quiz:
        with self._lock:
            old = self.get(quiz_id)
            quiz = Quiz(**data.model_dump(), id=quiz_id, updated_at=self._now(), status=old.status, session=old.session,
                        owner=old.owner, school_id=old.school_id, session_lookup=old.session_lookup,
                        session_sealed=old.session_sealed)
            if quiz.status == "assigned" and not ready(quiz):
                # An assigned quiz must stay ready: a broken edit takes it out of the session.
                quiz.status, quiz.session, quiz.session_lookup, quiz.session_sealed = "draft", None, None, None
            return self._write(quiz)

    def _codes(self) -> dict[str, str]:
        text = blobs.get_text(f"{self.kind}_codes", "session_codes")
        return json.loads(text) if text else {}

    def _save_codes(self, known: dict) -> None:
        blobs.put_text(f"{self.kind}_codes", "session_codes", json.dumps(known, indent=2))

    def session_code(self, class_id: str, session: str) -> tuple[str, str]:
        """One code per class session, the same for every quiz assigned to it: (lookup, sealed)."""
        known = self._codes()
        key = f"{class_id}|{session}"
        if not isinstance(known.get(key), dict):  # new, or an old letters code: make a digits one
            taken = {v["lookup"] for v in known.values() if isinstance(v, dict)}
            code = codes.new_code(lambda lk: lk in taken)
            known[key] = {"lookup": codes.lookup(code), "sealed": codes.seal(code)}
            self._save_codes(known)
        return known[key]["lookup"], known[key]["sealed"]

    def rotate_session_code(self, class_id: str, session: str) -> None:
        """A new code for the session; every quiz in it moves to the new one."""
        with self._lock:
            known = self._codes()
            known.pop(f"{class_id}|{session}", None)
            self._save_codes(known)
            lookup, sealed = self.session_code(class_id, session)
            for q in self.all():
                if q.class_id == class_id and q.session == session:
                    q.session_lookup, q.session_sealed = lookup, sealed
                    self._write(q)

    def assign(self, quiz_id: str, session: str) -> Quiz:
        with self._lock:
            quiz = self.get(quiz_id)
            quiz.status, quiz.session, quiz.updated_at = "assigned", session, self._now()
            quiz.session_lookup, quiz.session_sealed = self.session_code(quiz.class_id, session)
            return self._write(quiz)

    def all(self) -> list[Quiz]:
        quizzes = []
        for name in blobs.names(self.kind):
            try:
                quizzes.append(Quiz.model_validate_json(blobs.get_text(self.kind, name) or ""))
            except ValueError:
                continue
        return sorted(quizzes, key=lambda q: q.updated_at, reverse=True)


def default_store() -> QuizStore:
    return QuizStore()
