// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Yoruba (`yo`).
class AppLocalizationsYo extends AppLocalizations {
  AppLocalizationsYo([String locale = 'yo']) : super(locale);

  @override
  String get appTitle => 'Magana';

  @override
  String get greeting => 'Ẹ n lẹ́ o';

  @override
  String languageButtonLabel(String language) {
    return 'Èdè áàpù: $language. Yí èdè padà';
  }

  @override
  String get chooseLanguage => 'Yan èdè áàpù';

  @override
  String languageChanged(String language) {
    return 'Èdè áàpù ti di $language báyìí.';
  }

  @override
  String get settings => 'Ètò';

  @override
  String get readPage => 'Ka ojú-ìwé kan';

  @override
  String get readPageSubtitle =>
      'Iṣẹ́ ilé-ìwé, àbájáde ìwòsàn, ìwé àkọsílẹ̀ báǹkì, lẹ́tà — ohunkóhun tí a tẹ̀ jáde';

  @override
  String get askQuestion => 'Béèrè ìbéèrè';

  @override
  String get practiceQuiz => 'Ìdánrawò ìbéèrè';

  @override
  String get myLibrary => 'Ilé-ìkàwé mi';

  @override
  String get everydayPapers => 'Ìwé ojoojúmọ́';

  @override
  String get skills => 'Ọgbọ́n iṣẹ́';

  @override
  String get myScore => 'Máàkì mi';

  @override
  String get holdToSpeak => 'Dì í mú kí o sọ̀rọ̀';

  @override
  String get holdToSpeakLabel => 'Dì í mú láti sọ àṣẹ';

  @override
  String get voiceCommands => 'Àṣẹ ohùn';

  @override
  String get comingSoonHint => 'Ó ń bọ̀ láìpẹ́';

  @override
  String comingSoon(String feature) {
    return '$feature ń bọ̀ láìpẹ́.';
  }

  @override
  String get backToHome => 'Padà sí ilé';

  @override
  String get framingGuidance =>
      'Tẹ́ ojú-ìwé náà sílẹ̀ níbi tí ìmọ́lẹ̀ dára. Gbé fóònù sókè lórí rẹ̀ tó ìwọ̀n apá kan, kí igun mẹ́rẹ̀ẹ̀rin lè wọlé. Lẹ́yìn náà tẹ Ya fọ́tò, ní ìsàlẹ̀ ojú fóònù.';

  @override
  String get repeat => 'Tún sọ';

  @override
  String get repeatInstructions => 'Tún gbọ́ ìtọ́sọ́nà';

  @override
  String get takePhoto => 'Ya fọ́tò';

  @override
  String get gallery => 'Àwọn fọ́tò';

  @override
  String get galleryLabel => 'Yan fọ́tò láti inú àwọn fọ́tò';

  @override
  String get cameraFailed => 'Mi ò lè ṣí kámẹ́rà. Gbìyànjú Àwọn fọ́tò dípò.';

  @override
  String get readingPage => 'Mo ń ka ojú-ìwé náà. Jọ̀wọ́ dúró.';

  @override
  String get noTextFound =>
      'Mi ò rí ọ̀rọ̀ kankan. Rí i dájú pé ojú-ìwé náà dojú kọ òkè, kí o tún gbìyànjú.';

  @override
  String get cannotReach =>
      'Mi ò lè dé ọ̀dọ̀ Magana. Ṣàyẹ̀wò ìsopọ̀ rẹ, kí o tún gbìyànjú.';

  @override
  String get readFailed =>
      'Ìṣòro kan wáyé nígbà tí mo ń ka ojú-ìwé náà. Jọ̀wọ́ tún gbìyànjú.';

  @override
  String get yourPage => 'Ojú-ìwé rẹ';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ìlà $count',
      one: 'ìlà 1',
    );
    return '$_temp0';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ọ̀wọ́ $count',
      one: 'ọ̀wọ́ 1',
    );
    return '$_temp0';
  }

  @override
  String unclearCount(int count) {
    return '$count kò ṣe kedere';
  }

  @override
  String linePosition(int number, int total) {
    return 'Ìlà $number nínú $total';
  }

  @override
  String rowPosition(int number, int total) {
    return 'Ọ̀wọ́ $number nínú $total';
  }

  @override
  String rowPositionInTable(int number, int total, int table) {
    return 'Ọ̀wọ́ $number nínú $total, tábìlì $table';
  }

  @override
  String get nowReading => 'à ń kà á báyìí';

  @override
  String get previous => 'Ẹ̀yìn';

  @override
  String get next => 'Iwájú';

  @override
  String get previousLine => 'Ìlà tó ṣáájú';

  @override
  String get previousRow => 'Ọ̀wọ́ tó ṣáájú';

  @override
  String get nextLine => 'Ìlà tó kàn';

  @override
  String get nextRow => 'Ọ̀wọ́ tó kàn';

  @override
  String get repeatLine => 'Tún ìlà yìí kà';

  @override
  String get repeatRow => 'Tún ọ̀wọ́ yìí kà';

  @override
  String speed(String value) {
    return 'Ìyára $value';
  }

  @override
  String speedLabel(String value) {
    return 'Ìyára kíkà $value. Tẹ̀ láti yí i padà';
  }

  @override
  String get pause => 'Dánudúró';

  @override
  String get play => 'Bẹ̀rẹ̀';

  @override
  String get pauseLabel => 'Dá kíkà dúró';

  @override
  String get playLabel => 'Kà láti ibí';

  @override
  String get pageRead => 'Mo ti ka ojú-ìwé náà.';

  @override
  String unsureSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nínú wọn kò dá mi lójú.',
      one: 'Ọ̀kan nínú wọn kò dá mi lójú.',
    );
    return '$_temp0 Màá sọ fún ọ nígbà tí a bá dé ibẹ̀.';
  }

  @override
  String get firstLine => 'Èyí ni ìlà àkọ́kọ́.';

  @override
  String get firstRow => 'Èyí ni ọ̀wọ́ àkọ́kọ́.';

  @override
  String get endOfPage => 'Òpin ojú-ìwé.';

  @override
  String get endOfPageHint =>
      'Òpin ojú-ìwé. Tẹ Tún sọ, tàbí padà láti ka ojú-ìwé mìíràn.';

  @override
  String whereLine(int number) {
    return 'ìlà $number';
  }

  @override
  String whereRow(int number) {
    return 'ọ̀wọ́ $number';
  }

  @override
  String whereCell(int row, int col) {
    return 'ọ̀wọ́ $row, òpó $col';
  }

  @override
  String get whereTop => 'ní òkè ojú-ìwé náà';

  @override
  String get whereMiddle => 'ní àárín ojú-ìwé náà';

  @override
  String get whereBottom => 'ní ìsàlẹ̀ ojú-ìwé náà';

  @override
  String get unclearNumber => 'nọ́ńbà tí kò ṣe kedere';

  @override
  String get faintPrint => 'Àkọsílẹ̀ tí kò hàn dáadáa';

  @override
  String get msg_too_dark =>
      'Ó ṣókùnkùn díẹ̀. Tan iná fóònù tàbí lọ síbi tí ìmọ́lẹ̀ wà.';

  @override
  String get msg_blurry =>
      'Fọ́tò náà kò mọ́ kedere. Di fóònù mú dáadáa kí o tún gbìyànjú.';

  @override
  String msg_low_confidence(String where) {
    return '$where kò dá mi lójú. Jọ̀wọ́ ṣàyẹ̀wò rẹ̀ tàbí kí o tún fọ́tò yà.';
  }

  @override
  String msg_low_confidence_number(String where) {
    return 'Mi ò lè ka nọ́ńbà kan ní $where kedere. Jọ̀wọ́ ṣàyẹ̀wò rẹ̀ tàbí kí o tún fọ́tò yà.';
  }

  @override
  String msg_unreadable_number(String where) {
    return 'Mi ò lè ka nọ́ńbà kan ní $where kedere. Jọ̀wọ́ ṣàyẹ̀wò rẹ̀ tàbí kí o tún fọ́tò yà.';
  }

  @override
  String msg_number_mismatch(String where) {
    return 'Mi ò lè ka nọ́ńbà kan ní $where kedere. Jọ̀wọ́ ṣàyẹ̀wò rẹ̀ tàbí kí o tún fọ́tò yà.';
  }

  @override
  String msg_faint_region(String where) {
    return 'Àkọsílẹ̀ kan wà $where tí kò hàn dáadáa, mi ò lè kà á. Wá ìmọ́lẹ̀ sí i, tàbí kí o tún fọ́tò yà.';
  }

  @override
  String get msg_unknown_mode => 'Yan iṣẹ́ ilé-ìwé, ìlera tàbí owó.';

  @override
  String get msg_not_allowed_for_tier => 'Èyí kò sí fún àkọọ́lẹ̀ yìí.';

  @override
  String get msg_consent_required =>
      'Àwọn akẹ́kọ̀ọ́ ọmọ ọdún 13 sí 17 nílò àṣẹ òbí tàbí alágbàtọ́ wọn ná.';

  @override
  String get msg_teacher_session_required =>
      'Àwọn akẹ́kọ̀ọ́ tí kò tíì pé ọdún 13 lè lo Magana nínú ìpàdé tí olùkọ́ ń darí nìkan.';

  @override
  String get msg_unreadable_image =>
      'Mi ò lè ṣí fọ́tò yẹn. Jọ̀wọ́ tún gbìyànjú.';

  @override
  String get msg_numbers_unconfirmed =>
      'Mi ò lè fìdí àwọn nọ́ńbà kan nínú àlàyé yìí múlẹ̀, nítorí náà màá ka ojú-ìwé náà gẹ́gẹ́ bí ó ṣe wà.';

  @override
  String get msg_q_fever => 'Do you have a fever or feel very hot?';

  @override
  String get msg_q_fever_days => 'For how many days?';

  @override
  String get msg_q_danger_vomit_weak =>
      'Have you been vomiting everything, or are you too weak to stand?';

  @override
  String get msg_q_danger_breathing => 'Are you having trouble breathing?';

  @override
  String get msg_q_danger_confused =>
      'Have you had a fit, fainted, or felt confused?';

  @override
  String get msg_go_to_clinic_now =>
      'This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.';

  @override
  String get msg_nurse_call_within_2_hours =>
      'Thank you. A nurse will call you within 2 hours.';

  @override
  String get msg_nurse_call_working_hours =>
      'Thank you. A nurse will call you back during working hours.';
}
