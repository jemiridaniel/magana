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


QUESTIONS = [
    {"id": "fever", "text": "Do you have a fever or feel very hot?", "type": "yes_no"},
    {"id": "fever_days", "text": "For how many days?", "type": "number", "ask_if": "fever"},
    {"id": "danger_vomit_weak", "text": "Have you been vomiting everything, or are you too weak to stand?", "type": "yes_no"},
    {"id": "danger_breathing", "text": "Are you having trouble breathing?", "type": "yes_no"},
    {"id": "danger_confused", "text": "Have you had a fit, fainted, or felt confused?", "type": "yes_no"},
]

DANGER_SIGNS = ("danger_vomit_weak", "danger_breathing", "danger_confused")


@dataclass
class TriageResult:
    priority: Priority
    spoken: str


def assess(answers: dict) -> TriageResult:
    if any(answers.get(k) is True for k in DANGER_SIGNS):
        return TriageResult(
            Priority.EMERGENCY,
            "This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.",
        )
    if answers.get("fever") is True and (answers.get("fever_days") or 0) >= 2:
        return TriageResult(Priority.URGENT, "Thank you. A nurse will call you within 2 hours.")
    return TriageResult(Priority.ROUTINE, "Thank you. A nurse will call you back during working hours.")
