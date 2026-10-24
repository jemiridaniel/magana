"""Ibà quick check: sets how soon a nurse calls back. It never diagnoses.

The questions and rules live in the Ibà service (iba-natlas, POST /v1/assess with
mode=self_report), where Dr. Amos signs them off. Magana keeps only the danger signs, as:
  * the fallback when Ibà is not configured, fails, or takes more than 3 seconds; and
  * a floor: a danger sign is always an emergency, even if Ibà answers otherwise.

The danger-sign question ids below must match Ibà's self-report question ids.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from enum import Enum

from .iba_client import IbaClient, IbaUnavailable
from .iba_monitor import IbaMonitor, monitor as iba_monitor
from .messages import CODES

log = logging.getLogger("magana.triage")


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

# Signs a blind user can't check by looking. Magana asks about them in words that don't
# need sight ("has anyone told you ...", "q_<id>_no_sight") and accepts "I can't check".
# "I can't check" is never a yes, so never an emergency on its own, but it never leaves the
# result at routine either: the learner gets the faster call-back and is told to mention it.
# DRAFT wording and rule, pending clinical sign-off (Dr. Amos).
SIGHT_BASED = ("bleeding", "yellow_eyes", "very_pale", "dark_urine")
CANT_CHECK = "cant_check"


def _without_sight(q: dict) -> dict:
    """A question as Magana asks it: sight-based signs get wording a blind user can answer."""
    if q["id"] not in SIGHT_BASED:
        return q
    q = {k: v for k, v in q.items() if k != "text"}  # Ibà's wording assumes sight
    return {**q, "message": f"q_{q['id']}_no_sight", "cant_check": True}


# Asked when Ibà is unreachable: the danger signs only. Wording: messages.ENGLISH "q_<id>".
FALLBACK_QUESTIONS = [
    _without_sight({"id": q, "type": "yes_no", "message": f"q_{q}"}) for q in DANGER_SIGNS
]


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


def _fallback(answers: dict, reason: str, monitor: IbaMonitor) -> TriageResult:
    if reason != "not_configured":
        monitor.failure(reason)
    result = fallback_assess(answers)
    # Outage answers are marked in the logs (never the answers themselves).
    log.warning("triage source=fallback reason=%s priority=%s", reason, result.priority.value)
    return result


async def assess(answers: dict, client: IbaClient | None, monitor: IbaMonitor = iba_monitor) -> TriageResult:
    # "I can't check" goes to the rules as "not seen" (never a yes); see SIGHT_BASED.
    unchecked = [k for k, v in answers.items() if v == CANT_CHECK]
    answers = {k: (False if v == CANT_CHECK else v) for k, v in answers.items()}
    result = await _assess(answers, client, monitor)
    if unchecked and result.priority is Priority.ROUTINE:
        result = TriageResult(Priority.URGENT, "nurse_call_within_2_hours", result.rule_version,
                              f"{result.source}+unchecked_floor")
    return result


async def _assess(answers: dict, client: IbaClient | None, monitor: IbaMonitor) -> TriageResult:
    if client is None:
        return _fallback(answers, "not_configured", monitor)
    try:
        body = await client.assess(answers)
        priority = Priority(body["priority"])
        if body["message"] not in CODES:
            raise IbaUnavailable("bad_response")
    except IbaUnavailable as e:
        return _fallback(answers, str(e), monitor)
    except ValueError:
        return _fallback(answers, "bad_response", monitor)
    monitor.success()
    result = TriageResult(priority, body["message"], str(body["rule_version"]), "iba")
    if has_danger_sign(answers) and result.priority is not Priority.EMERGENCY:
        # Defence in depth: whatever Ibà says, a danger sign means go now.
        result = TriageResult(Priority.EMERGENCY, "go_to_clinic_now", result.rule_version, "iba+danger_floor")
    log.info("triage source=%s priority=%s", result.source, result.priority.value)
    return result


async def questions(lang: str, client: IbaClient | None, monitor: IbaMonitor = iba_monitor) -> tuple[list[dict], str]:
    """Ibà's questions in `lang` (its wording, signed off clinically), or the fallback set."""
    if client is not None:
        try:
            qs = await client.questions(lang)
            monitor.success()
            return [_without_sight({**q, "message": f"q_{q['id']}"}) for q in qs], "iba"
        except IbaUnavailable as e:
            monitor.failure(str(e))
            log.warning("triage questions source=fallback reason=%s", e)
    return FALLBACK_QUESTIONS, "fallback"
