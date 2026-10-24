"""Message codes.

The API never returns sentences to speak: it returns these codes and the app
says each one in the user's language (app/lib/l10n, key `msg_<code>`).

ENGLISH is the reference wording for translators and the API docs only. The
health and triage wording is a draft until Dr. Amos and Nurse Balogun sign it off.
"""
from __future__ import annotations

ENGLISH = {
    # Capture tips, before reading
    "too_dark": "It's quite dark. Turn on the torch or move to more light.",
    "blurry": "The photo looks blurry. Hold the phone still and try again.",
    # Reading warnings
    "low_confidence": "I'm not sure about {where}. Please check it or retake the photo.",
    "low_confidence_number": "I can't read a number on {where} clearly. Please check it or retake the photo.",
    "unreadable_number": "I can't read a number on {where} clearly. Please check it or retake the photo.",
    "number_mismatch": "I can't read a number on {where} clearly. Please check it or retake the photo.",
    "faint_region": "There is faint print {where} that I can't read. Try more light, or retake the photo.",
    # Request errors (HTTP detail)
    "unknown_mode": "Choose schoolwork, health or money.",
    "not_allowed_for_tier": "This isn't available on this account.",
    "consent_required": "Learners aged 13 to 17 need a parent's or guardian's consent first.",
    "teacher_session_required": "Learners under 13 can only use Magana in a teacher-run session.",
    "unreadable_image": "I couldn't open that photo. Please try again.",
    # Explanations
    "numbers_unconfirmed": "I can't confirm some numbers in this explanation, so I'll read the page exactly instead.",
    # Ibà quick check (draft, clinical sign-off required)
    "q_fever": "Do you have a fever or feel very hot?",
    "q_fever_days": "For how many days?",
    "q_danger_vomit_weak": "Have you been vomiting everything, or are you too weak to stand?",
    "q_danger_breathing": "Are you having trouble breathing?",
    "q_danger_confused": "Have you had a fit, fainted, or felt confused?",
    "go_to_clinic_now": "This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.",
    "nurse_call_within_2_hours": "Thank you. A nurse will call you within 2 hours.",
    "nurse_call_working_hours": "Thank you. A nurse will call you back during working hours.",
}

CODES = frozenset(ENGLISH)


class CodedError(PermissionError):
    """A refusal the app explains in the user's language."""

    def __init__(self, code: str):
        assert code in CODES, code
        super().__init__(code)
        self.code = code
