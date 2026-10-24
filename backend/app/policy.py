"""Age tiers and what each tier may use.

Standard  (18+)    own account, all features including WhatsApp, health and money papers
Guided    (13-17)  account created by a school or guardian after consent; curriculum only
Classroom (<13)    no personal account; only teacher-run sessions
"""
from __future__ import annotations

from enum import Enum

from .messages import CodedError


class Tier(str, Enum):
    STANDARD = "standard"
    GUIDED = "guided"
    CLASSROOM = "classroom"


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
        raise CodedError("not_allowed_for_tier")


def check_request(tier: Tier, guardian_consent: bool, teacher_session: bool) -> Tier:
    """What a request may claim: a Guided tier needs a guardian's consent and a Classroom
    tier a teacher-run session, or it is refused.

    The app sends these with every request. Until accounts exist (consent recorded by the
    school in the teacher portal), this is the app's word for it; the rule is still enforced
    on both sides so a buggy or modified client can't open health or money features to a
    child.
    """
    if tier is Tier.GUIDED and not guardian_consent:
        raise CodedError("consent_required")
    if tier is Tier.CLASSROOM and not teacher_session:
        raise CodedError("teacher_session_required")
    return tier
