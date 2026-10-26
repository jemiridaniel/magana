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
    "line_part_unclear": "Part of {where} wasn't read: there's print I couldn't make out. Please check it or retake the photo.",
    "faint_region": "There is faint print {where} that I can't read. Try more light, or retake the photo.",
    # Request errors (HTTP detail)
    "unknown_mode": "Choose schoolwork, health or money.",
    "bad_api_key": "This copy of Magana can't reach the reading service. Please update the app.",
    "asr_unavailable": "Speech recognition on the server is not set up; the phone's own is used.",
    "audio_too_long": "That recording is too long. Please say a short answer.",
    "unreadable_audio": "I couldn't hear that recording. Please try again.",
    "too_many_requests": "Magana is busy right now. Please wait a minute and try again.",
    "unknown_tier": "Please set up Magana again: your age group wasn't recognised.",
    "not_allowed_for_tier": "This isn't available on this account.",
    "consent_required": "Learners aged 13 to 17 need a parent's or guardian's consent first.",
    "teacher_session_required": "Learners under 13 can only use Magana in a teacher-run session.",
    "unreadable_image": "I couldn't open that photo. Please try again.",
    "money_amounts_unreliable": "I can't read the amounts on this page reliably. Please open the PDF from your bank's app or email, or ask someone you trust.",
    "reading_incomplete": "This reading is incomplete. I'll read only the parts I could check.",
    "handwritten_page": "This page looks handwritten. Handwriting is hard for me, so I may get words wrong. Numbers are only read when I'm sure.",
    "mixed_page": "Some of this page looks handwritten. I may get those parts wrong. Numbers there are only read when I'm sure.",
    "handwritten_prescription": "This looks like handwriting on a health paper. I won't read handwritten medicines or doses. Please ask the pharmacist or nurse to read it to you.",
    "handwritten_number": "On {where}, a handwritten number. I won't guess it: please ask the pharmacist or nurse.",
    "small_print": "The print is very small or faint in this photo, so I may miss some of it. Move the phone closer, or open the PDF itself if you have it.",
    "unreadable_pdf": "I couldn't open that PDF. Please try another file.",
    "pdf_password_needed": "This PDF is locked. Type its password: it is often in the email that came with it.",
    "pdf_password_wrong": "That password didn't open the PDF. Please check it and try again.",
    "pdf_too_long": "This PDF is too long. I can read up to 20 pages at a time.",
    # Class link (learner_api.py)
    "class_code_wrong": "That class code isn't right. Check it with your teacher.",
    "code_locked": "Too many wrong codes. Please wait 5 minutes, then try again.",
    "teacher_code_needed": "Only your teacher can move you to another class. Ask them to enter their teacher code.",
    "teacher_code_wrong": "That teacher code isn't right. Ask your teacher to check it.",
    "class_has_no_accounts": "This class only has lessons your teacher runs. Ask your teacher.",
    "not_linked": "This phone isn't in a class now. You can still read pages.",
    "class_joined": "You're in the class.",
    "class_changed": "Your class has changed.",
    "session_code_invalid": "That session code isn't right. Check it in the teacher portal.",
    # Explanations
    "numbers_unconfirmed": "I can't confirm some numbers in this explanation, so I'll read the page exactly instead.",
    "explain_wrong_language": "I couldn't explain this in your language, so I'll read the page exactly instead.",
    "explain_preview": "This is a preview. Explanations in your language come when N-ATLAS is connected. Here is the page, read exactly as printed.",
    "explained": "Here is the explanation.",
    "explain_not_available": "Explain isn't available yet. Here is the page, read exactly as printed.",
    "explain_unavailable": "Explanations aren't available right now. Here is the page, read exactly as printed.",
    "explain_bad_source": "There is no page text to explain. Please read a page first.",
    # Health and money papers are never explained by a model (templates.py).
    "numbers_left_out": "The exact numbers are on the page. Say ‘read again’ to hear them.",
    "paper_lines": "Health and money papers aren't explained by AI. Each line is read exactly, in your language only where a checked translation exists.",
    "cant_translate_line_health": "I can't translate this line safely. Please ask a pharmacist.",
    "cant_translate_line_money": "I can't translate this line safely. Please ask someone at your bank.",
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
    "q_bleeding_no_sight": "Have you felt or tasted blood, or has anyone told you that you are bleeding, from your nose, gums, vomit or stool?",
    "q_yellow_eyes_no_sight": "Has anyone told you that your eyes or skin look yellow?",
    "q_very_pale_no_sight": "Has anyone told you that you look very pale? Do you feel very weak, dizzy or out of breath when you stand?",
    "q_dark_urine_no_sight": "Has someone near you seen that your urine is very dark, like cola or tea?",
    "go_to_clinic_now": "This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.",
    "nurse_call_within_2_hours": "Thank you. A nurse will call you within 2 hours.",
    # A danger sign answered "I can't tell" (DRAFT, pending Dr. Amos).
    "ask_someone_to_check": "Please ask someone near you to check, or go to a clinic.",
    "callback_booked": "Your call back is booked. A nurse or pharmacist will call you.",
    "callback_unavailable": "Call backs are not available yet. If you need help now, go to a clinic or call 112.",
    "nurse_call_working_hours": "Thank you. A nurse will call you back during working hours.",
}

CODES = frozenset(ENGLISH)

# Codes only the teacher portal sees (portal/lib/messages.ts words each one; a test checks).
PORTAL = {
    "school_email_resent": "Email sent again to the principal.",
    "team_invite_cancelled": "Invitation cancelled.",
    "team_member_removed": "Removed. They’re signed out everywhere.",
    "team_role_changed": "Role changed.",
    "team_invite_sent": "Invitation sent. It works for 7 days.",
    "owners_minimum": "The Magana team must always have at least one owner.",
    "totp_wrong": "That authenticator code isn’t right. Check the time on your phone and try the new code.",
    "totp_setup": "Set up your authenticator app to finish signing in.",
    "totp_required": "Enter the code from your authenticator app.",
    "team_role_needed": "Your team role can’t do this. Ask a Magana team owner.",
    "email_is_teacher": "That email belongs to a teacher or school admin. A team member needs a different email.",
    "email_is_team": "That email belongs to a Magana team member. Use a different email.",
    "proof_too_big": "That file is too big. Please keep it under 5 MB.",
    "proof_wrong_type": "That file isn't a photo or PDF. Choose a JPG, PNG, WebP or PDF.",
    "school_decided": "Someone on the team has already decided about this school.",
    "notes_saved": "Call notes saved.",
    "checks_required": "Tick all three checks before approving.",
    "upload_saved": "Uploaded. Magana read it and kept only the text.",
    "upload_approved": "Approved. Learners can now use this text.",
    "upload_corrections_saved": "Corrections saved. It stays at Check until you approve it.",
    "upload_unreadable": "Magana couldn't read that file. Try a photo or a PDF.",
    "upload_locked": "That PDF is locked. Please upload a copy without a password.",
    "upload_no_text": "Magana found no text in that file.",
    "upload_too_big": "That file is too big. Please keep it under 15 MB.",
    "upload_lines_changed": "The lines changed while you were checking. Please reload and try again.",
    "quiz_not_assigned": "Assign the quiz to a class session first.",
    "quiz_not_found": "That quiz wasn't found. It may have been removed.",
    "quiz_not_ready": "Fix the problems in “Before you assign” first.",
    "quiz_no_questions": "Add at least one question.",
    "quiz_empty_question": "Type the question.",
    "quiz_too_few_options": "Give at least two options.",
    "quiz_too_many_options": "Too many options for this class.",
    "quiz_empty_option": "An option is empty.",
    "quiz_no_right_answer": "Mark the right answer.",
    "quiz_picture_needs_description": "Describe the picture in words. Magana reads the description.",
    "quiz_question_long": "Long for a primary class: 15 words or fewer is easier to hear.",
    "quiz_translation_unchecked": "The translation is not yet checked.",
}
PORTAL.update({
    # Sign-in, schools, staff, classes and learners (portal_api.py)
    "not_signed_in": "Please sign in.",
    "session_expired": "You were signed out after 30 minutes without activity. Please sign in again.",
    "not_for_team": "This page is for teachers. Magana team: use the admin page.",
    "school_pending": "Your school is waiting for the Magana team to confirm it. We’ll call you within 2 working days.",
    "not_admin": "Only a school admin can do this.",
    "not_team": "Only the Magana team can open this page.",
    "code_sent_recently": "We just sent a code. You can ask for a new one in a few seconds.",
    "too_many_codes": "Too many codes for this email. Please try again in an hour.",
    "sign_in_code_sent": "If this email is invited, we sent a 6-digit code to it.",
    "mail_unavailable": "We couldn’t send the email just now. Please try again in a few minutes.",
    "sign_in_code_wrong": "That code isn’t right. Check the latest email from Magana.",
    "sign_in_code_expired": "That code has expired. Ask for a new one.",
    "code_locked": "Too many wrong codes. Please wait 5 minutes, then try again.",
    "signed_in": "Signed in.",
    "signed_out": "You’re signed out.",
    "agree_required": "Tick the box to confirm you lead the school and agree to the privacy notice.",
    "place_unknown": "Choose the state, then a local government area from the list.",
    "email_taken": "This email is already used for a Magana teacher.",
    "school_registered": "Thank you. The Magana team will call you within 2 working days to confirm the school.",
    "school_approved": "School approved.",
    "school_rejected": "School not approved.",
    "invite_sent": "Invitation sent. It expires in 7 days.",
    "not_invited": "This person isn’t waiting on an invitation.",
    "invite_cancelled": "Invitation cancelled.",
    "staff_removed": "Removed. They are signed out everywhere.",
    "staff_changed": "Saved.",
    "last_admin": "This is the school’s last admin. Make someone else an admin first.",
    "admins_minimum": "Every school keeps at least two admins. Make another teacher an admin first.",
    "classes_need_new_teacher": "Choose a new teacher for each of their classes first.",
    "new_teacher_invalid": "Choose an active teacher from your school.",
    "not_found": "That wasn’t found. It may have been removed.",
    "class_code_rotated": "New class code made. The old one no longer works.",
    "teacher_code_rotated": "New teacher code made. The old one no longer works.",
    "consent_not_needed": "This learner is 18 or over: no guardian consent is needed.",
    "consent_recorded": "Consent recorded. The learner’s class is linked now.",
    "consent_not_pending": "Consent isn’t pending for this learner.",
    "reminder_ready": "Here is a message to send to the guardian.",
    "learner_removed": "Removed from the class. Their phone is unlinked.",
    "learner_moved": "Moved to the new class.",
    "learner_removed_already": "This learner was already removed from the class.",
    "reason_required": "Choose a reason.",
    "learner_data_deleted": "All of this learner’s data has been deleted.",
    "learner_not_in_class": "That learner isn’t in this class.",
    "learner_removed_cannot_move": "This learner was removed from the class.",
    "register_saved": "Register saved.",
    "class_has_no_accounts": "Classroom classes are teacher-led only: learners don’t join them with a code.",
    "staff_removed_already": "This person was already removed.",
})
PORTAL_CODES = frozenset(PORTAL)

# Codes only Meta's servers see, from the WhatsApp webhook (app/wa_flow.py): no app wording.
WEBHOOK = {
    "bad_signature": "The request isn't signed with the WhatsApp app secret.",
    "verify_token_wrong": "The webhook verify token doesn't match.",
    "whatsapp_not_configured": "WhatsApp isn't set up on this server.",
}
WEBHOOK_CODES = frozenset(WEBHOOK)


class CodedError(PermissionError):
    """A refusal the app explains in the user's language."""

    def __init__(self, code: str):
        assert code in CODES, code
        super().__init__(code)
        self.code = code
