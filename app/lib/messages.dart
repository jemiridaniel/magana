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
      'unreachable' => l.cannotReach,
      _ => l.readFailed,
    };

/// "near the top of the page" for a faint region's backend `where` code.
String pagePosition(AppLocalizations l, String where) => switch (where) {
  'top' => l.whereTop,
  'bottom' => l.whereBottom,
  _ => l.whereMiddle,
};
