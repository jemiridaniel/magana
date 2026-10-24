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
    "line_end_unclear": "I can't read the end of {where}. Please check it or retake the photo.",
    "faint_region": "There is faint print {where} that I can't read. Try more light, or retake the photo.",
    # Request errors (HTTP detail)
    "unknown_mode": "Choose schoolwork, health or money.",
    "unknown_tier": "Please set up Magana again: your age group wasn't recognised.",
    "not_allowed_for_tier": "This isn't available on this account.",
    "consent_required": "Learners aged 13 to 17 need a parent's or guardian's consent first.",
    "teacher_session_required": "Learners under 13 can only use Magana in a teacher-run session.",
    "unreadable_image": "I couldn't open that photo. Please try again.",
    # Explanations
    "numbers_unconfirmed": "I can't confirm some numbers in this explanation, so I'll read the page exactly instead.",
    # Ibà quick check. The Ibà service owns this wording (iba-natlas, backend/app/questions.py,
    # pending clinical sign-off by Dr. Amos); these are the fallback copies, kept identical.
    "q_fever": "Do you have a fever, or does your body feel very hot?",
    "q_fever_days": "For how many days have you had the fever?",
    "q_fits": "Have you had fits, or shaking of the body you could not stop?",
    "q_cannot_drink": "Are you unable to drink anything, or is the baby unable to breastfeed?",
    "q_vomits_everything": "Are you vomiting everything you eat or drink?",
    "q_very_sleepy": "Are you very sleepy, confused, or hard to wake?",
    "q_bleeding": "Are you bleeding without a clear reason, from the nose or gums, or in vomit or stool?",
    "q_yellow_eyes": "Have your eyes or skin turned yellow?",
    "q_hard_breathing": "Are you breathing very fast, or struggling to breathe?",
    "q_very_pale": "Are your palms, lips or inner eyelids very pale?",
    "q_dark_urine": "Is your urine very dark, like cola or tea?",
    "q_too_weak": "Are you too weak to sit up or stand without help?",
    # Sight-based danger signs, asked so a blind user can answer (DRAFT, pending Dr. Amos).
    "q_bleeding_no_sight": "Are you bleeding without a clear reason? For example a nosebleed, blood you can taste from your gums, or has anyone told you there is blood in your vomit or stool?",
    "q_yellow_eyes_no_sight": "Has anyone told you that your eyes or skin look yellow?",
    "q_very_pale_no_sight": "Has anyone told you that your palms, lips or the inside of your eyelids look very pale?",
    "q_dark_urine_no_sight": "Has anyone told you that your urine is very dark, like cola or tea?",
    "go_to_clinic_now": "This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.",
    "nurse_call_within_2_hours": "Thank you. A nurse will call you within 2 hours.",
    "callback_booked": "Your call back is booked. A nurse or pharmacist will call you.",
    "callback_unavailable": "Call backs are not available yet. If you need help now, go to a clinic or call 112.",
    "nurse_call_working_hours": "Thank you. A nurse will call you back during working hours.",
}

CODES = frozenset(ENGLISH)


class CodedError(PermissionError):
    """A refusal the app explains in the user's language."""

    def __init__(self, code: str):
        assert code in CODES, code
        super().__init__(code)
        self.code = code
