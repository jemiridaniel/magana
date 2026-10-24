// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Magana';

  @override
  String get greeting => 'Hello';

  @override
  String languageButtonLabel(String language) {
    return 'App language: $language. Change language';
  }

  @override
  String get chooseLanguage => 'Choose app language';

  @override
  String languageChanged(String language) {
    return 'App language is now $language.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get readPage => 'Read a page';

  @override
  String get readPageSubtitle =>
      'Schoolwork, medical reports, bank statements, letters — anything printed';

  @override
  String get askQuestion => 'Ask a question';

  @override
  String get practiceQuiz => 'Practice quiz';

  @override
  String get myLibrary => 'My library';

  @override
  String get everydayPapers => 'Everyday papers';

  @override
  String get skills => 'Skills';

  @override
  String get myScore => 'My score';

  @override
  String get holdToSpeak => 'Hold to speak';

  @override
  String get holdToSpeakLabel => 'Hold to speak a command';

  @override
  String get voiceCommands => 'Voice commands';

  @override
  String get comingSoonHint => 'Coming soon';

  @override
  String comingSoon(String feature) {
    return '$feature is coming soon.';
  }

  @override
  String get backToHome => 'Back to home';

  @override
  String get framingGuidance =>
      'Lay the page flat in good light and hold the phone about one forearm above it. I\'ll tell you how to move, and take the photo when the whole page is steady. You can also tap Take photo.';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatInstructions => 'Hear the instructions again';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get gallery => 'Gallery';

  @override
  String get galleryLabel => 'Choose a photo from the gallery';

  @override
  String get cameraFailed =>
      'I couldn\'t open the camera. Try Gallery instead.';

  @override
  String get readingPage => 'Reading the page. Please wait.';

  @override
  String get noTextFound =>
      'I couldn\'t find any text. Check the page is face up and try again.';

  @override
  String get cannotReach =>
      'I couldn\'t reach Magana. Check the connection and try again.';

  @override
  String get readFailed =>
      'Something went wrong reading the page. Please try again.';

  @override
  String get yourPage => 'Your page';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String unclearCount(int count) {
    return '$count unclear';
  }

  @override
  String linePosition(int number, int total) {
    return 'Line $number of $total';
  }

  @override
  String rowPosition(int number, int total) {
    return 'Row $number of $total';
  }

  @override
  String rowPositionInTable(int number, int total, int table) {
    return 'Row $number of $total, table $table';
  }

  @override
  String get nowReading => 'now reading';

  @override
  String get previous => 'Prev';

  @override
  String get next => 'Next';

  @override
  String get previousLine => 'Previous line';

  @override
  String get previousRow => 'Previous row';

  @override
  String get nextLine => 'Next line';

  @override
  String get nextRow => 'Next row';

  @override
  String get repeatLine => 'Repeat this line';

  @override
  String get repeatRow => 'Repeat this row';

  @override
  String speed(String value) {
    return 'Speed $value';
  }

  @override
  String speedLabel(String value) {
    return 'Reading speed $value. Tap to change';
  }

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get pauseLabel => 'Pause reading';

  @override
  String get playLabel => 'Read from here';

  @override
  String get pageRead => 'Page read.';

  @override
  String unsureSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I\'m not sure about $count of them.',
      one: 'I\'m not sure about 1 of them.',
    );
    return '$_temp0 I\'ll tell you when we get there.';
  }

  @override
  String get firstLine => 'This is the first line.';

  @override
  String get firstRow => 'This is the first row.';

  @override
  String get endOfPage => 'End of page.';

  @override
  String get endOfPageHint =>
      'End of page. Tap Repeat, or go back to read another page.';

  @override
  String whereLine(int number) {
    return 'line $number';
  }

  @override
  String whereRow(int number) {
    return 'row $number';
  }

  @override
  String whereCell(int row, int col) {
    return 'row $row, column $col';
  }

  @override
  String get whereTop => 'near the top of the page';

  @override
  String get whereMiddle => 'in the middle of the page';

  @override
  String get whereBottom => 'near the bottom of the page';

  @override
  String get unclearNumber => 'unclear number';

  @override
  String get faintPrint => 'Faint print';

  @override
  String get msg_too_dark =>
      'It\'s quite dark. Turn on the torch or move to more light.';

  @override
  String get msg_blurry =>
      'The photo looks blurry. Hold the phone still and try again.';

  @override
  String msg_low_confidence(String where) {
    return 'I\'m not sure about $where. Please check it or retake the photo.';
  }

  @override
  String msg_low_confidence_number(String where) {
    return 'I can\'t read a number on $where clearly. Please check it or retake the photo.';
  }

  @override
  String msg_unreadable_number(String where) {
    return 'I can\'t read a number on $where clearly. Please check it or retake the photo.';
  }

  @override
  String msg_number_mismatch(String where) {
    return 'I can\'t read a number on $where clearly. Please check it or retake the photo.';
  }

  @override
  String msg_faint_region(String where) {
    return 'There is faint print $where that I can\'t read. Try more light, or retake the photo.';
  }

  @override
  String get msg_unknown_mode => 'Choose schoolwork, health or money.';

  @override
  String get msg_not_allowed_for_tier =>
      'This isn\'t available on this account.';

  @override
  String get msg_consent_required =>
      'Learners aged 13 to 17 need a parent\'s or guardian\'s consent first.';

  @override
  String get msg_teacher_session_required =>
      'Learners under 13 can only use Magana in a teacher-run session.';

  @override
  String get msg_unreadable_image =>
      'I couldn\'t open that photo. Please try again.';

  @override
  String get msg_numbers_unconfirmed =>
      'I can\'t confirm some numbers in this explanation, so I\'ll read the page exactly instead.';

  @override
  String get msg_go_to_clinic_now =>
      'This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.';

  @override
  String get msg_nurse_call_within_2_hours =>
      'Thank you. A nurse will call you within 2 hours.';

  @override
  String get msg_nurse_call_working_hours =>
      'Thank you. A nurse will call you back during working hours.';

  @override
  String get autoCapture => 'Auto-capture';

  @override
  String get torchOn => 'Turn on torch';

  @override
  String get torchOff => 'Turn off torch';

  @override
  String get cameraView => 'Camera view';

  @override
  String get cameraUnavailable =>
      'I can\'t use the camera. Allow camera access in Settings, or choose a photo from the gallery.';

  @override
  String get msg_q_fever =>
      'Do you have a fever, or does your body feel very hot?';

  @override
  String get msg_q_fever_days => 'For how many days have you had the fever?';

  @override
  String get msg_q_fits =>
      'Have you had fits, or shaking of the body you could not stop?';

  @override
  String get msg_q_cannot_drink =>
      'Are you unable to drink anything, or is the baby unable to breastfeed?';

  @override
  String get msg_q_vomits_everything =>
      'Are you vomiting everything you eat or drink?';

  @override
  String get msg_q_very_sleepy =>
      'Are you very sleepy, confused, or hard to wake?';

  @override
  String get msg_q_bleeding =>
      'Are you bleeding without a clear reason, from the nose or gums, or in vomit or stool?';

  @override
  String get msg_q_yellow_eyes => 'Have your eyes or skin turned yellow?';

  @override
  String get msg_q_hard_breathing =>
      'Are you breathing very fast, or struggling to breathe?';

  @override
  String get msg_q_very_pale =>
      'Are your palms, lips or inner eyelids very pale?';

  @override
  String get msg_q_dark_urine => 'Is your urine very dark, like cola or tea?';

  @override
  String get msg_q_too_weak =>
      'Are you too weak to sit up or stand without help?';

  @override
  String msg_line_end_unclear(String where) {
    return 'I can\'t read the end of $where. Please check it or retake the photo.';
  }

  @override
  String get cueHigher => 'Higher';

  @override
  String get cueLower => 'Lower';

  @override
  String get cueLeft => 'Left';

  @override
  String get cueRight => 'Right';

  @override
  String get cueHoldStill => 'Hold still';

  @override
  String get cueCloser => 'Closer';

  @override
  String get cueFurther => 'Further';

  @override
  String get cueMoreLight => 'More light';

  @override
  String get cueNoPage => 'No page';
}
