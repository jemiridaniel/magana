"""Ibà quick check: sets how soon a nurse calls back. It never diagnoses.

The questions and rules live in the Ibà service (iba-natlas, POST /v1/assess with
mode=self_report), where Dr. Amos signs them off. Magana keeps only the danger signs, as:
  * the fallback when Ibà is not configured, fails, or takes more than 3 seconds; and
  * a floor: a danger sign is always an emergency, even if Ibà answers otherwise.

The danger-sign question ids below must match Ibà's self-report question ids.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum

from .iba_client import IbaClient, IbaUnavailable
from .messages import CODES


class Priority(str, Enum):
    EMERGENCY = "emergency"   # go to a clinic now / call 112
    URGENT = "urgent"         # nurse calls back within 2 hours
    ROUTINE = "routine"       # nurse calls back the same or next working day


# Ibà self-report danger-sign questions (plain-language versions of the WHO / IMCI signs).
DANGER_SIGNS = (
    "fits", "cannot_drink", "vomits_everything", "very_sleepy", "bleeding",
    "yellow_eyes", "hard_breathing", "very_pale", "dark_urine", "too_weak",
)

FALLBACK_RULE_VERSION = "magana-danger-signs-1"

# Asked when Ibà is unreachable: the danger signs only. Wording: messages.ENGLISH "q_<id>".
FALLBACK_QUESTIONS = [{"id": q, "type": "yes_no", "message": f"q_{q}"} for q in DANGER_SIGNS]


@dataclass
class TriageResult:
    priority: Priority
    message: str  # a code from messages.ENGLISH
    rule_version: str
    source: str  # "iba", "iba+danger_floor" or "fallback"


def has_danger_sign(answers: dict) -> bool:
    return any(answers.get(k) is True for k in DANGER_SIGNS)


def fallback_assess(answers: dict) -> TriageResult:
    """Built-in rules for when Ibà can't answer.

    A danger sign is an emergency. Without one, Magana can't apply Ibà's other rules, so it
    asks for the faster call-back rather than risk under-triage.
    """
    if has_danger_sign(answers):
        return TriageResult(Priority.EMERGENCY, "go_to_clinic_now", FALLBACK_RULE_VERSION, "fallback")
    return TriageResult(Priority.URGENT, "nurse_call_within_2_hours", FALLBACK_RULE_VERSION, "fallback")


async def assess(answers: dict, client: IbaClient | None) -> TriageResult:
    if client is None:
        return fallback_assess(answers)
    try:
        body = await client.assess(answers)
        priority = Priority(body["priority"])
        if body["message"] not in CODES:
            raise IbaUnavailable("unknown_message")
    except (IbaUnavailable, ValueError):
        return fallback_assess(answers)
    result = TriageResult(priority, body["message"], str(body["rule_version"]), "iba")
    if has_danger_sign(answers) and result.priority is not Priority.EMERGENCY:
        # Defence in depth: whatever Ibà says, a danger sign means go now.
        return TriageResult(Priority.EMERGENCY, "go_to_clinic_now", result.rule_version, "iba+danger_floor")
    return result


async def questions(lang: str, client: IbaClient | None) -> tuple[list[dict], str]:
    """Ibà's questions in `lang` (its wording, signed off clinically), or the fallback set."""
    if client is not None:
        try:
            qs = await client.questions(lang)
            return [{**q, "message": f"q_{q['id']}"} for q in qs], "iba"
        except IbaUnavailable:
            pass
    return FALLBACK_QUESTIONS, "fallback"
