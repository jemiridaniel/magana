import 'l10n/app_localizations.dart';

/// Says a backend message code in the app language. [where] fills codes that
/// name a place ("line 2", "near the top of the page").
String messageFor(AppLocalizations l, String code, {String where = ''}) =>
    switch (code) {
      'too_dark' => l.msg_too_dark,
      'blurry' => l.msg_blurry,
      'low_confidence' => l.msg_low_confidence(where),
      'low_confidence_number' => l.msg_low_confidence_number(where),
      'unreadable_number' => l.msg_unreadable_number(where),
      'number_mismatch' => l.msg_number_mismatch(where),
      'faint_region' => l.msg_faint_region(where),
      'line_end_unclear' => l.msg_line_end_unclear(where),
      'unknown_mode' => l.msg_unknown_mode,
      'not_allowed_for_tier' => l.msg_not_allowed_for_tier,
      'consent_required' => l.msg_consent_required,
      'teacher_session_required' => l.msg_teacher_session_required,
      'unreadable_image' => l.msg_unreadable_image,
      'numbers_unconfirmed' => l.msg_numbers_unconfirmed,
      'callback_booked' => l.msg_callback_booked,
      'callback_unavailable' => l.msg_callback_unavailable,
      'unknown_tier' => l.msg_unknown_tier,
      'go_to_clinic_now' => l.msg_go_to_clinic_now,
      'explain_preview' => l.msg_explain_preview,
      'explained' => l.msg_explained,
      'explain_bad_source' => l.msg_explain_bad_source,
      'ask_someone_to_check' => l.msg_ask_someone_to_check,
      'nurse_call_within_2_hours' => l.msg_nurse_call_within_2_hours,
      'nurse_call_working_hours' => l.msg_nurse_call_working_hours,
      'q_fever' => l.msg_q_fever,
      'q_fever_days' => l.msg_q_fever_days,
      'q_fits' => l.msg_q_fits,
      'q_cannot_drink' => l.msg_q_cannot_drink,
      'q_vomits_everything' => l.msg_q_vomits_everything,
      'q_very_sleepy' => l.msg_q_very_sleepy,
      'q_bleeding' => l.msg_q_bleeding,
      'q_yellow_eyes' => l.msg_q_yellow_eyes,
      'q_hard_breathing' => l.msg_q_hard_breathing,
      'q_very_pale' => l.msg_q_very_pale,
      'q_dark_urine' => l.msg_q_dark_urine,
      'q_too_weak' => l.msg_q_too_weak,
      'q_bleeding_no_sight' => l.msg_q_bleeding_no_sight,
      'q_yellow_eyes_no_sight' => l.msg_q_yellow_eyes_no_sight,
      'q_very_pale_no_sight' => l.msg_q_very_pale_no_sight,
      'q_dark_urine_no_sight' => l.msg_q_dark_urine_no_sight,
      'unreachable' => l.cannotReach,
      _ => l.readFailed,
    };

/// "near the top of the page" for a faint region's backend `where` code.
String pagePosition(AppLocalizations l, String where) => switch (where) {
  'top' => l.whereTop,
  'bottom' => l.whereBottom,
  _ => l.whereMiddle,
};
