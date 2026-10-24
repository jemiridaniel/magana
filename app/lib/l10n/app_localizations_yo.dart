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
      'Tẹ́ ojú-ìwé náà sílẹ̀ níbi tí ìmọ́lẹ̀ dára, kí o sì gbé fóònù sókè lórí rẹ̀ tó ìwọ̀n apá kan. Màá sọ bí o ṣe máa sún un fún ọ, màá sì ya fọ́tò náà nígbà tí gbogbo ojú-ìwé bá dúró jẹ́ẹ́. O tún lè tẹ Ya fọ́tò.';

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
  String get msg_go_to_clinic_now =>
      'Èyí lè le. Jọ̀wọ́ lọ sí ilé-ìwòsàn tó súnmọ́ ọ jù lọ báyìí, tàbí pe 112. Má ṣe dúró kí wọ́n pè ọ́ padà.';

  @override
  String get msg_nurse_call_within_2_hours =>
      'A dúpẹ́. Nọ́ọ̀sì kan yóò pè ọ́ láàrin wákàtí 2.';

  @override
  String get msg_nurse_call_working_hours =>
      'A dúpẹ́. Nọ́ọ̀sì kan yóò pè ọ́ padà ní àkókò iṣẹ́.';

  @override
  String get autoCapture => 'Ya fọ́tò fúnra rẹ̀';

  @override
  String get torchOn => 'Tan iná fóònù';

  @override
  String get torchOff => 'Pa iná fóònù';

  @override
  String get cameraView => 'Ìwòye kámẹ́rà';

  @override
  String get cameraUnavailable =>
      'Mi ò lè lo kámẹ́rà. Fún kámẹ́rà láṣẹ nínú Ètò, tàbí yan fọ́tò láti inú àwọn fọ́tò.';

  @override
  String get msg_q_fever => 'Ṣé o ní ibà, tàbí ara rẹ gbóná gan-an?';

  @override
  String get msg_q_fever_days => 'Ọjọ́ mélòó ni o ti ní ibà náà?';

  @override
  String get msg_q_fits =>
      'Ṣé gìrì ti mú ọ, tàbí ara rẹ gbọ̀n tí o kò lè dá dúró?';

  @override
  String get msg_q_cannot_drink =>
      'Ṣé o kò lè mu ohunkóhun, tàbí ọmọ ọwọ́ kò lè mu ọmú?';

  @override
  String get msg_q_vomits_everything =>
      'Ṣé o ń bì gbogbo ohun tí o jẹ tàbí tí o mu?';

  @override
  String get msg_q_very_sleepy =>
      'Ṣé oorun ń kùn ọ́ gan-an, ṣé ọkàn rẹ dàrú, tàbí ṣé ó ṣòro láti jí ọ?';

  @override
  String get msg_q_bleeding =>
      'Ṣé ẹ̀jẹ̀ ń jáde lára rẹ láìnídìí, láti imú tàbí èrìgì, tàbí nínú èébì tàbí ìgbẹ́?';

  @override
  String get msg_q_yellow_eyes => 'Ṣé ojú rẹ tàbí awọ ara rẹ ti pọ́n?';

  @override
  String get msg_q_hard_breathing =>
      'Ṣé o ń mí kíákíá gan-an, tàbí ó ń ṣòro fún ọ láti mí?';

  @override
  String get msg_q_very_pale =>
      'Ṣé àtẹ́lẹwọ́ rẹ, ètè rẹ tàbí inú ìpéǹpéjú rẹ funfun gan-an?';

  @override
  String get msg_q_dark_urine =>
      'Ṣé ìtọ̀ rẹ ṣókùnkùn gan-an, bíi kóòkì tàbí tíì?';

  @override
  String get msg_q_too_weak =>
      'Ṣé ara rẹ ti rẹ̀ débi pé o kò lè jókòó tàbí dìde láìsí ìrànlọ́wọ́?';

  @override
  String msg_line_end_unclear(String where) {
    return 'Mi ò lè ka òpin $where. Jọ̀wọ́ ṣàyẹ̀wò rẹ̀ tàbí kí o tún fọ́tò yà.';
  }

  @override
  String get cueHigher => 'Sókè';

  @override
  String get cueLower => 'Sísàlẹ̀';

  @override
  String get cueLeft => 'Òsì';

  @override
  String get cueRight => 'Ọ̀tún';

  @override
  String get cueHoldStill => 'Dúró jẹ́ẹ́';

  @override
  String get cueCloser => 'Súnmọ́';

  @override
  String get cueFurther => 'Sẹ́yìn';

  @override
  String get cueMoreLight => 'Ìmọ́lẹ̀ sí i';

  @override
  String get cueNoPage => 'Kò sí ojú-ìwé';

  @override
  String stepOf(int n, int total) {
    return 'Ìgbésẹ̀ $n nínú $total';
  }

  @override
  String get chooseLanguageTitle => 'Yan èdè rẹ';

  @override
  String get chooseLanguageBody =>
      'Magana yóò bá ọ sọ̀rọ̀ ní èdè yìí. O lè yí i padà nígbàkúùgbà láti ojú-ìwé àkọ́kọ́.';

  @override
  String get languageHearsHint =>
      'A ó ka àṣàyàn kọ̀ọ̀kan ní èdè tirẹ̀ nígbà tí o bá fọwọ́ kàn án.';

  @override
  String get continueLabel => 'Tẹ̀síwájú';

  @override
  String get welcome => 'Ẹ káàbọ̀';

  @override
  String get ageTitle => 'Ọmọ ọdún mélòó ni ọ́?';

  @override
  String get ageBody => 'A ń béèrè kí Magana lè jẹ́ ààbò àti kí ó bá ọ mu.';

  @override
  String get ageAdult => 'Mo ti pé ọdún 18 tàbí jù bẹ́ẹ̀ lọ';

  @override
  String get ageAdultDetail =>
      'Lo gbogbo ohun tí ó wà nínú Magana, pẹ̀lú ìwé ìlera àti ti owó.';

  @override
  String get ageTeen => 'Mo wà láàrin ọdún 13 sí 17';

  @override
  String get ageTeenDetail =>
      'Òbí, alágbàtọ́ tàbí olùkọ́ yóò kọ́kọ́ gbà. Magana ń ràn ọ́ lọ́wọ́ pẹ̀lú ẹ̀kọ́ ilé-ìwé nìkan.';

  @override
  String get ageChild => 'Mi ò tíì pé ọdún 13';

  @override
  String get ageChildDetail => 'Olùkọ́ rẹ yóò lo Magana pẹ̀lú rẹ ní kíláàsì.';

  @override
  String get privacyNote =>
      'A máa ń pa fọ́tò ojú-ìwé rẹ rẹ́ lẹ́yìn kíkà. A kì í pín àlàyé rẹ fún ẹnikẹ́ni.';

  @override
  String get hearAgain => 'Tún gbọ́ ojú-ìwé yìí';

  @override
  String get readyTitle => 'O ti ṣetán';

  @override
  String get readyBody =>
      'Gbé fóònù rẹ sórí ojú-ìwé tí a tẹ̀ jáde, Magana yóò kà á fún ọ.';

  @override
  String get startLabel => 'Bẹ̀rẹ̀';

  @override
  String get consentTitle => 'Bi òbí, alágbàtọ́ tàbí olùkọ́ léèrè';

  @override
  String get consentBody => 'Jọ̀wọ́ ẹ ka tàbí ẹ gbọ́ èyí papọ̀.';

  @override
  String get consentPoint1 => 'Magana ń ràn lọ́wọ́ pẹ̀lú ẹ̀kọ́ ilé-ìwé nìkan.';

  @override
  String get consentPoint2 =>
      'Kò sí ìwé ìlera tàbí ti owó, kò sí WhatsApp, kò sí ìjíròrò ọ̀fẹ́.';

  @override
  String get consentPoint3 => 'A máa ń pa fọ́tò rẹ́ lẹ́yìn kíkà.';

  @override
  String get consentConfirm => 'Èmi ni òbí, alágbàtọ́ tàbí olùkọ́, mo sì gbà';

  @override
  String get classroomTitle => 'Magana ní kíláàsì';

  @override
  String get classroomBody =>
      'Olùkọ́ rẹ yóò bẹ̀rẹ̀ Magana pẹ̀lú rẹ ní kíláàsì. Nígbà tí ẹ̀kọ́ bá parí, ẹ pa áàpù náà.';

  @override
  String get classroomStart => 'Olùkọ́: bẹ̀rẹ̀ ìpàdé kíláàsì';

  @override
  String get classroomConfirmTitle => 'Ṣé ìwọ ni olùkọ́?';

  @override
  String get classroomConfirmYes => 'Bẹ́ẹ̀ ni, bẹ̀rẹ̀ ìpàdé';

  @override
  String get cancel => 'Fagilé';

  @override
  String get back => 'Padà';

  @override
  String get msg_unknown_tier =>
      'Jọ̀wọ́ tún Magana ṣètò: a kò dá ẹgbẹ́ ọjọ́-orí rẹ mọ̀.';

  @override
  String get readPageSubtitleSchool =>
      'Iṣẹ́ ilé-ìwé, àkọsílẹ̀, ìwé ẹ̀kọ́ àti ìdánwò';
}
