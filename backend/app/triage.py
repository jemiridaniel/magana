"""Ibà quick health check: sets how soon a nurse calls back. It never diagnoses.

The questions and danger signs below are a starting draft and MUST be reviewed
and signed off by the team's clinical members (Dr. Oluba Amos, Nurse Oluremi
Balogun) before any real use.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Priority(str, Enum):
    EMERGENCY = "emergency"   # go to a clinic now / call 112
    URGENT = "urgent"         # nurse calls back within 2 hours
    ROUTINE = "routine"       # nurse calls back the same or next working day


# Question wording is in messages.ENGLISH under "q_<id>"; the app says it in the user's language.
QUESTIONS = [
    {"id": "fever", "message": "q_fever", "type": "yes_no"},
    {"id": "fever_days", "message": "q_fever_days", "type": "number", "ask_if": "fever"},
    {"id": "danger_vomit_weak", "message": "q_danger_vomit_weak", "type": "yes_no"},
    {"id": "danger_breathing", "message": "q_danger_breathing", "type": "yes_no"},
    {"id": "danger_confused", "message": "q_danger_confused", "type": "yes_no"},
]

DANGER_SIGNS = ("danger_vomit_weak", "danger_breathing", "danger_confused")


@dataclass
class TriageResult:
    priority: Priority
    message: str  # a code from messages.ENGLISH


def assess(answers: dict) -> TriageResult:
    if any(answers.get(k) is True for k in DANGER_SIGNS):
        return TriageResult(Priority.EMERGENCY, "go_to_clinic_now")
    if answers.get("fever") is True and (answers.get("fever_days") or 0) >= 2:
        return TriageResult(Priority.URGENT, "nurse_call_within_2_hours")
    return TriageResult(Priority.ROUTINE, "nurse_call_working_hours")
