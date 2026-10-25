"""Age tiers and what each tier may use.

Standard  (18+)    own account, all features including WhatsApp, health and money papers
Guided    (13-17)  linked to a class; curriculum only, once a guardian has agreed
Classroom (<13)    no personal account; only teacher-run sessions

A Guided learner whose guardian hasn't agreed yet (the teacher records consent in the portal)
is "waiting": they may read schoolwork pages, and nothing else (no quiz, Explain, skills,
library or class link). DRAFT, for Nurse Balogun's review (docs/FINDINGS.md, 25 Oct 2026):
the design boards (A2) allow reading while waiting; before, nothing worked without consent.
"""
from __future__ import annotations

from enum import Enum

from .messages import CodedError


class Tier(str, Enum):
    STANDARD = "standard"
    GUIDED = "guided"
    CLASSROOM = "classroom"
    GUIDED_WAITING = "guided_waiting"  # never sent by the app: a Guided request without consent


class Feature(str, Enum):
    READ_SCHOOLWORK = "read_schoolwork"
    EXPLAIN = "explain"
    QUIZ = "quiz"
    SKILLS = "skills"
    EVERYDAY_HEALTH = "everyday_health"
    EVERYDAY_MONEY = "everyday_money"
    EVERYDAY_LETTERS = "everyday_letters"  # letters, forms and notices (18+)
    HEALTH_CALLBACK = "health_callback"
    WHATSAPP = "whatsapp"
    OPEN_CHAT = "open_chat"
    PEOPLE_DESCRIPTION = "people_description"


_ALLOWED = {
    Tier.STANDARD: set(Feature),
    Tier.GUIDED: {Feature.READ_SCHOOLWORK, Feature.EXPLAIN, Feature.QUIZ, Feature.SKILLS},
    Tier.CLASSROOM: {Feature.READ_SCHOOLWORK, Feature.QUIZ},
    Tier.GUIDED_WAITING: {Feature.READ_SCHOOLWORK},
}


def tier_for_age(age: int, guardian_consent: bool = False, teacher_session: bool = False) -> Tier:
    if age >= 18:
        return Tier.STANDARD
    if age >= 13:
        if not guardian_consent:
            raise CodedError("consent_required")
        return Tier.GUIDED
    if not teacher_session:
        raise CodedError("teacher_session_required")
    return Tier.CLASSROOM


def allowed(tier: Tier, feature: Feature) -> bool:
    return feature in _ALLOWED[tier]


def require(tier: Tier, feature: Feature) -> None:
    if not allowed(tier, feature):
        # Waiting for a guardian: say so, rather than "not for your account".
        raise CodedError("consent_required" if tier is Tier.GUIDED_WAITING else "not_allowed_for_tier")


def check_request(tier: Tier, guardian_consent: bool, teacher_session: bool) -> Tier:
    """What a request may claim: a Guided tier without a guardian's consent is "waiting"
    (schoolwork reading only), and a Classroom tier needs a teacher-run session.

    For a learner linked to a class, consent is what the teacher recorded in the portal: the
    caller (main.caller_tier) ignores the app's consent header when the link says otherwise.
    The rule is enforced on both sides so a buggy or modified client can't open health or
    money features to a child.
    """
    if tier is Tier.GUIDED and not guardian_consent:
        return Tier.GUIDED_WAITING
    if tier is Tier.CLASSROOM and not teacher_session:
        raise CodedError("teacher_session_required")
    return tier
