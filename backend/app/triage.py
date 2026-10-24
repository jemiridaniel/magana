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

# DRAFT, pending clinical sign-off (Dr. Amos): "I can't tell".
# Every quick-check question can be answered "I can't tell" (CANT_TELL). It never counts as
# "no": it is sent to the rules as unanswered (null), and Magana sets a floor afterwards:
# - on a danger-sign question: at least urgent, with "Please ask someone near you to check,
#   or go to a clinic" (ask_someone_to_check);
# - on any other question: at least urgent, because the rule that needed the answer could
#   not be applied.
# A danger sign answered "yes" is still always an emergency.
CANT_TELL = "cant_tell"

# Danger signs normally checked by looking. Magana words them so a blind user can answer
# ("q_<id>_no_sight"); Ibà's own wording assumes sight. DRAFT, pending Dr. Amos.
SIGHT_BASED = ("bleeding", "yellow_eyes", "very_pale", "dark_urine")


def _as_magana_asks(q: dict) -> dict:
    """A question as Magana asks it: every question offers "I can't tell"; danger signs are
    marked; sight-based ones get wording a blind user can answer."""
    q = {**q, "cant_tell": True}
    if q["id"] in DANGER_SIGNS:
        q["danger_sign"] = True
    if q["id"] in SIGHT_BASED:
        q = {k: v for k, v in q.items() if k != "text"}  # Ibà's wording assumes sight
        q["message"] = f"q_{q['id']}_no_sight"
    return q


# Asked when Ibà is unreachable: the danger signs only. Wording: messages.ENGLISH "q_<id>".
FALLBACK_QUESTIONS = [
    _as_magana_asks({"id": q, "type": "yes_no", "message": f"q_{q}"}) for q in DANGER_SIGNS
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
    # "I can't tell" is never "no": the rules get it as unanswered, then the floor below.
    unknown = [k for k, v in answers.items() if v == CANT_TELL]
    answers = {k: (None if v == CANT_TELL else v) for k, v in answers.items()}
    result = await _assess(answers, client, monitor)
    if not unknown or result.priority is Priority.EMERGENCY:
        return result
    if any(k in DANGER_SIGNS for k in unknown):
        return TriageResult(Priority.URGENT, "ask_someone_to_check", result.rule_version,
                            f"{result.source}+cant_tell_floor")
    if result.priority is Priority.ROUTINE:
        return TriageResult(Priority.URGENT, "nurse_call_within_2_hours", result.rule_version,
                            f"{result.source}+cant_tell_floor")
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
            return [_as_magana_asks({**q, "message": f"q_{q['id']}"}) for q in qs], "iba"
        except IbaUnavailable as e:
            monitor.failure(str(e))
            log.warning("triage questions source=fallback reason=%s", e)
    return FALLBACK_QUESTIONS, "fallback"
