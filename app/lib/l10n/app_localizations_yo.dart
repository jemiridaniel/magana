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

  @override
  String get everydaySubtitle => 'Ìwé ìlera àti ti owó · 18+';

  @override
  String get paperMedicine => 'Àmì òògùn';

  @override
  String get paperMedicineDetail => 'Àmì àti ìwé àṣẹ dókítà';

  @override
  String get paperReport => 'Ìjábọ̀ ìlera';

  @override
  String get paperReportDetail => 'Àbájáde àyẹ̀wò àti ìwé ìdásílẹ̀';

  @override
  String get paperStatement => 'Ìwé àkọsílẹ̀ báǹkì';

  @override
  String get paperStatementDetail =>
      'Ìwé àkọsílẹ̀, ìwé ìsanwó àti owó tí a ó san';

  @override
  String get talkToNurse => 'Bá nọ́ọ̀sì sọ̀rọ̀';

  @override
  String get talkToNurseDetail => 'Pẹ̀lú àyẹ̀wò kíákíá Ibà';

  @override
  String get everydayPrivacy =>
      'A ń ka àwọn ìwé àṣírí lórí fóònù rẹ, a kì í tọ́jú wọn. Magana kì í béèrè PIN tàbí ọ̀rọ̀ aṣínà rẹ.';

  @override
  String get readExactly => 'A ń kà á gẹ́gẹ́ bí a ṣe tẹ̀ ẹ́';

  @override
  String get noteMedicine =>
      'Magana ń ka ohun tí a tẹ̀. Kò fúnni ní ìmọ̀ràn ìlera. Bí ohunkóhun lórí àmì bá ṣókùnkùn, bi oníṣègùn òògùn rẹ léèrè kí o tó lò ó.';

  @override
  String get noteReport =>
      'A ń ka nọ́ńbà àti ààlà gẹ́gẹ́ bí a ṣe tẹ̀ wọ́n. Magana kì í ṣàlàyé àbájáde: òṣìṣẹ́ ìlera rẹ nìkan ló lè ṣàlàyé ohun tí wọ́n túmọ̀ sí fún ọ.';

  @override
  String get noteStatement =>
      'A ń ka iye owó gẹ́gẹ́ bí a ṣe tẹ̀ ẹ́. A kò tọ́jú ìwé yìí. Magana kì í béèrè PIN tàbí ọ̀rọ̀ aṣínà rẹ. Bí iye kan bá ṣókùnkùn, ṣàyẹ̀wò rẹ̀ pẹ̀lú báǹkì rẹ tàbí ẹni tí o fọkàn tán.';

  @override
  String get askPharmacistOrNurse => 'Bi oníṣègùn òògùn tàbí nọ́ọ̀sì léèrè';

  @override
  String get adultsOnly => 'Èyí wà fún àgbàlagbà (ọdún 18 sókè).';

  @override
  String get healthWorkerTitle => 'Bá òṣìṣẹ́ ìlera sọ̀rọ̀';

  @override
  String get healthWorkerSubtitle =>
      'Nọ́ọ̀sì tàbí oníṣègùn òògùn yóò pè ọ́ padà';

  @override
  String get helpWithTitle => 'Kí ni o nílò ìrànlọ́wọ́ fún?';

  @override
  String get reasonMedicine => 'Òye òògùn mi';

  @override
  String get reasonResults => 'Òye àbájáde mi';

  @override
  String get reasonOther => 'Nǹkan mìíràn';

  @override
  String get callLanguage => 'Èdè fún ìpè náà';

  @override
  String get answerIbaFirst => 'Kọ́kọ́ dáhùn ìbéèrè kíákíá díẹ̀ (Ibà)';

  @override
  String get requestCallback => 'Béèrè kí wọ́n pè ọ́ padà';

  @override
  String get emergencyBold => 'Pàjáwìrì?';

  @override
  String get emergencyText => 'Má ṣe dúró kí wọ́n pè ọ́ padà. Pe 112 báyìí.';

  @override
  String get call112 => 'Pe 112';

  @override
  String get quickCheckTitle => 'Àyẹ̀wò ìlera kíákíá';

  @override
  String quickCheckProgress(int n, int total) {
    return 'Ibà · ìbéèrè $n nínú $total';
  }

  @override
  String get yes => 'Bẹ́ẹ̀ ni';

  @override
  String get no => 'Rárá';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ọjọ́ $count',
      one: 'ọjọ́ 1',
    );
    return '$_temp0';
  }

  @override
  String get moreDays => 'Ọjọ́ kan sí i';

  @override
  String get fewerDays => 'Ọjọ́ kan dín';

  @override
  String get nextLabel => 'Èyí tó kàn';

  @override
  String get quickCheckNote =>
      'Ìdáhùn rẹ ń ran nọ́ọ̀sì lọ́wọ́ láti mọ bí ó ṣe yára tó láti pè ọ́. Ibà kì í ṣe àyẹ̀wò àìsàn. Bí o bá ní àmì ewu, Magana yóò sọ fún ọ pé kí o lọ sí ilé-ìwòsàn báyìí.';

  @override
  String get resultTitle => 'Àbájáde rẹ';

  @override
  String get checkingAnswers => 'Mo ń ṣàyẹ̀wò ìdáhùn rẹ.';

  @override
  String get backHome => 'Padà sí ilé';

  @override
  String get msg_callback_booked =>
      'A ti ṣètò ìpè rẹ. Nọ́ọ̀sì tàbí oníṣègùn òògùn yóò pè ọ́.';

  @override
  String get msg_callback_unavailable =>
      'Ìpè padà kò tíì sí. Bí o bá nílò ìrànlọ́wọ́ báyìí, lọ sí ilé-ìwòsàn tàbí pe 112.';

  @override
  String quickCheckProgressFallback(int n, int total) {
    return 'Àyẹ̀wò ààbò inú áàpù · ìbéèrè $n nínú $total';
  }

  @override
  String get resultUrgent =>
      'Ó yẹ kí nọ́ọ̀sì pè ọ́ láàrin wákàtí 2. Béèrè kí wọ́n pè ọ́ padà báyìí. Bí ara rẹ bá burú sí i, lọ sí ilé-ìwòsàn tàbí pe 112.';

  @override
  String get resultRoutine =>
      'Nọ́ọ̀sì lè pè ọ́ padà ní àkókò iṣẹ́. Béèrè kí wọ́n pè ọ́ padà. Bí ara rẹ bá burú sí i, lọ sí ilé-ìwòsàn tàbí pe 112.';

  @override
  String get quizTitle => 'Ìdánrawò Biology';

  @override
  String quizProgress(int n, int total) {
    return 'Bíi WAEC · Ìbéèrè $n nínú $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct tó tọ̀nà nínú $answered tí o ti dáhùn';
  }

  @override
  String get quizSayAnswer => 'Sọ A, B, C tàbí D';

  @override
  String get quizListening => 'Mo ń gbọ́… Tẹ̀ láti dúró';

  @override
  String quizCorrect(String letter) {
    return 'Ó tọ̀nà! O yan $letter.';
  }

  @override
  String quizWrong(String letter, String answer) {
    return 'Kò tọ̀nà. O yan $letter. Ìdáhùn ni $answer.';
  }

  @override
  String quizUnclear(String heard) {
    return 'Mo gbọ́ “$heard”. Jọ̀wọ́ sọ A, B, C tàbí D.';
  }

  @override
  String get quizNothingHeard =>
      'Mi ò gbọ́ ìdáhùn kankan. Sọ A, B, C tàbí D, tàbí tẹ ìdáhùn kan lẹ́ẹ̀mejì.';

  @override
  String get quizNoVoice =>
      'A kò lè dáhùn pẹ̀lú ohùn lórí fóònù yìí. Tẹ ìdáhùn kan lẹ́ẹ̀mejì dípò rẹ̀.';

  @override
  String get quizRepeat => 'Tún ìbéèrè sọ';

  @override
  String get quizNext => 'Ìbéèrè tó kàn';

  @override
  String get quizFinish => 'Wo èsì mi';

  @override
  String get quizYourAnswerRight => 'ìdáhùn rẹ, ó tọ̀nà';

  @override
  String get quizYourAnswerWrong => 'ìdáhùn rẹ, kò tọ̀nà';

  @override
  String get quizRightAnswer => 'ìdáhùn tó tọ̀nà';

  @override
  String get quizResultTitle => 'Ìdánrawò ti parí';

  @override
  String quizResult(int correct, int total) {
    return 'O gba $correct tó tọ̀nà nínú $total.';
  }

  @override
  String get quizAgain => 'Tún ṣe ìdánrawò';

  @override
  String get quizSource =>
      'Ẹgbẹ́ Magana ló kọ àwọn ìbéèrè náà bíi ti WAEC Biology. Wọn kì í ṣe ìbéèrè àtijọ́. Èdè Gẹ̀ẹ́sì ni àwọn ìbéèrè wà.';

  @override
  String get skillsSubtitle => 'Àwọn ẹ̀kọ́ kúkúrú tí a ń sọ, bí o ṣe fẹ́';

  @override
  String nextLesson(int minutes) {
    return 'Ẹ̀kọ́ tó kàn · ìṣẹ́jú $minutes';
  }

  @override
  String get playLesson => 'Gbọ́ ẹ̀kọ́';

  @override
  String get pauseLesson => 'Dúró díẹ̀';

  @override
  String get practiseNow => 'Ṣe é báyìí';

  @override
  String get lessonDone => 'Ó ti parí';

  @override
  String lessonStepOf(int step, int total) {
    return 'Ìgbésẹ̀ $step nínú $total';
  }

  @override
  String get lessonNotStarted => 'Kò tíì bẹ̀rẹ̀';

  @override
  String get allLessonsDone => 'O ti parí gbogbo ẹ̀kọ́. O ṣe dáadáa!';

  @override
  String get practiseWithChampion => 'Ṣe ìdánrawò pẹ̀lú Akọni Magana';

  @override
  String get skillsNote =>
      'Ẹ̀kọ́ àpẹẹrẹ tí ẹgbẹ́ Magana kọ ni, àwọn olùkọ́ ìmúpadàbọ̀sípò yóò yẹ̀ wọ́n wò. Èdè Gẹ̀ẹ́sì ni ẹ̀kọ́ wà fún báyìí.';

  @override
  String get previousStep => 'Ìgbésẹ̀ tó ṣáájú';

  @override
  String get nextStep => 'Ìgbésẹ̀ tó kàn';

  @override
  String get lessonFinished => 'Ẹ̀kọ́ ti parí.';

  @override
  String get scoreTitle => 'Ìwọ̀n Òmìnira Mi';

  @override
  String get scoreSubtitle => 'Àwọn iṣẹ́ tí o parí nínú Magana';

  @override
  String scoreOutOf(int score) {
    return '$score nínú 100';
  }

  @override
  String get scoreByArea => 'Ní ẹ̀ka kọ̀ọ̀kan';

  @override
  String get areaLearning => 'Ẹ̀kọ́';

  @override
  String get areaHealth => 'Ìwé ìlera';

  @override
  String get areaMoney => 'Owó àti lẹ́tà';

  @override
  String get areaSkills => 'Ọgbọ́n';

  @override
  String areaScoreLabel(String area, int score) {
    return '$area: $score nínú 100';
  }

  @override
  String get scoreThisWeek => 'Ọ̀sẹ̀ yìí';

  @override
  String get scoreNothingThisWeek =>
      'Kò sí iṣẹ́ kankan ní ọ̀sẹ̀ yìí. Ka ojú-ìwé kan tàbí ṣe ìdánrawò láti bẹ̀rẹ̀.';

  @override
  String weekReadSchool(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ojú-ìwé iṣẹ́ ilé-ìwé $count ni a kà',
      one: 'Ojú-ìwé iṣẹ́ ilé-ìwé 1 ni a kà',
    );
    return '$_temp0';
  }

  @override
  String weekReadMedicine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Àmì oògùn $count ni a kà',
      one: 'Àmì oògùn 1 ni a kà',
    );
    return '$_temp0';
  }

  @override
  String weekReadReport(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ìròyìn ìlera $count ni a kà',
      one: 'Ìròyìn ìlera 1 ni a kà',
    );
    return '$_temp0';
  }

  @override
  String weekReadStatement(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ìwé bánkì tàbí rìsíìtì $count ni a kà',
      one: 'Ìwé bánkì tàbí rìsíìtì 1 ni a kà',
    );
    return '$_temp0';
  }

  @override
  String weekQuiz(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ìdánrawò $count ti parí',
      one: 'Ìdánrawò 1 ti parí',
    );
    return '$_temp0';
  }

  @override
  String weekLesson(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ẹ̀kọ́ $count ti parí',
      one: 'Ẹ̀kọ́ 1 ti parí',
    );
    return '$_temp0';
  }

  @override
  String get scoreHow =>
      'Ìwọ̀n rẹ ń ka àwọn iṣẹ́ gidi tí o parí nínú Magana ní ọgbọ̀n ọjọ́ sẹ́yìn. Ó wà lórí fóònù yìí nìkan; ìwọ nìkan ló ń rí i.';

  @override
  String get championsTitle => 'Àwọn Akọni Magana';

  @override
  String get championsSubtitle => 'Kọ́ láti ọ̀dọ̀ àwọn tó ti là á kọjá';

  @override
  String get championSample => 'Àpẹẹrẹ àkọsílẹ̀';

  @override
  String get championDetail =>
      'Afọ́jú láti ọmọ ọdún 12 · Kano · Hausa, Gẹ̀ẹ́sì';

  @override
  String get championNotYet =>
      'Àpẹẹrẹ ni èyí. A ó so ọ́ pọ̀ mọ́ Akọni nípasẹ̀ àwọn àjọ alábàáṣiṣẹ́pọ̀. Ìpè kò tíì ṣeé ṣe.';

  @override
  String get becomeChampion => 'Di Akọni';

  @override
  String get becomeChampionBody =>
      'Ran àwọn mìíràn lọ́wọ́ ní àdúgbò rẹ kí o sì gba ìwé-ẹ̀rí.';

  @override
  String get champStepBasics => 'Parí ẹ̀kọ́ Ìpìlẹ̀ fóònù';

  @override
  String get champStepPhotos => 'Parí ẹ̀kọ́ Yíya fọ́tò tó mọ́';

  @override
  String get champStepScore => 'Dé Ìwọ̀n Òmìnira 60';

  @override
  String get champStepTraining => 'Darapọ̀ mọ́ ìdálẹ́kọ̀ọ́ Akọni wákàtí 2';

  @override
  String get champStepHelp => 'Ran ènìyàn mẹ́ta àkọ́kọ́ lọ́wọ́';

  @override
  String get stepDone => 'ó ti parí';

  @override
  String get stepNotDone => 'kò tíì parí';

  @override
  String get championsPartnerNote =>
      'Ìdálẹ́kọ̀ọ́ Akọni yóò wáyé pẹ̀lú àwọn àjọ alábàáṣiṣẹ́pọ̀. Kò tíì ṣí sílẹ̀.';

  @override
  String get librarySubtitle => 'Àwọn ìwé tí a fi pamọ́, fún ọgbọ̀n ọjọ́';

  @override
  String get libraryEmpty =>
      'Kò sí ohun tí a fi pamọ́ síbẹ̀. Lẹ́yìn tí Magana bá ka ojú-ìwé kan, yan Fi pamọ́ sí ilé-ìkàwé mi.';

  @override
  String libraryDeletesIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'a ó pa á rẹ́ ní ọjọ́ $count',
      one: 'a ó pa á rẹ́ lọ́la',
      zero: 'a ó pa á rẹ́ lónìí',
    );
    return '$_temp0';
  }

  @override
  String librarySavedOn(String date) {
    return 'A fi pamọ́ ní $date';
  }

  @override
  String get libraryPrivacy =>
      'Àwọn ìwé tí a fi pamọ́ wà lórí fóònù yìí, a sì ń pa wọ́n rẹ́ lẹ́yìn ọgbọ̀n ọjọ́. A kì í fi fọ́tò pamọ́ rárá.';

  @override
  String get saveToLibrary => 'Fi pamọ́ sí ilé-ìkàwé mi';

  @override
  String get savedToLibrary =>
      'A ti fi pamọ́ sí ilé-ìkàwé rẹ. Yóò wà lórí fóònù yìí fún ọgbọ̀n ọjọ́.';

  @override
  String get deleteFromLibrary => 'Pa á rẹ́ kúrò ní ilé-ìkàwé mi';

  @override
  String get deleteConfirm => 'Ṣé kí a pa ìwé yìí rẹ́ kúrò ní ilé-ìkàwé rẹ?';

  @override
  String get deleteYes => 'Pa á rẹ́';

  @override
  String get deletedFromLibrary => 'A ti pa á rẹ́ kúrò ní ilé-ìkàwé rẹ.';

  @override
  String get remindersTitle => 'Àwọn oògùn òní';

  @override
  String get remindersSubtitle => 'Àkókò tí o ṣètò pẹ̀lú oníṣègùn oògùn';

  @override
  String get remindersCard => 'Ìrántí oògùn';

  @override
  String get remindersCardDetail => 'Àkókò fún àwọn oògùn rẹ';

  @override
  String get remindersEmpty =>
      'Kò sí ìrántí síbẹ̀. Fi àkókò tí oníṣègùn oògùn tàbí dókítà fún ọ kún un.';

  @override
  String get doseTaken => 'A ti lò ó';

  @override
  String get doseDue => 'Àkókò ti tó';

  @override
  String get doseLater => 'Lẹ́yìn náà lónìí';

  @override
  String doseLabel(String time, String state, String medicine, String amount) {
    return '$time, $state. $medicine. $amount';
  }

  @override
  String get iTookIt => 'Mo ti lò ó';

  @override
  String get remindLater => 'Rán mi létí ní ìṣẹ́jú 15';

  @override
  String get remindLaterSet => 'Màá tún rán ọ létí ní ìṣẹ́jú 15.';

  @override
  String get markedTaken => 'A ti kọ ọ́ pé o ti lò ó.';

  @override
  String get addReminder => 'Fi ìrántí kún un';

  @override
  String get medicineName => 'Orúkọ oògùn, bí ó ṣe wà lórí àmì';

  @override
  String get medicineAmount => 'Iye tí oníṣègùn oògùn sọ (fún àpẹẹrẹ, oògùn 2)';

  @override
  String get reminderTime => 'Àkókò';

  @override
  String get earlierHour => 'Wákàtí kan ṣáájú';

  @override
  String get laterHour => 'Wákàtí kan lẹ́yìn';

  @override
  String get earlierMinutes => 'Ìṣẹ́jú 15 ṣáájú';

  @override
  String get laterMinutes => 'Ìṣẹ́jú 15 lẹ́yìn';

  @override
  String get saveReminder => 'Fi ìrántí pamọ́';

  @override
  String get medicineNameNeeded => 'Kọ orúkọ oògùn náà kọ́kọ́.';

  @override
  String reminderSaved(String time) {
    return 'A ti fi ìrántí pamọ́ fún $time.';
  }

  @override
  String get deleteReminder => 'Pa ìrántí rẹ́';

  @override
  String deleteReminderConfirm(String time, String medicine) {
    return 'Ṣé kí a pa ìrántí $time fún $medicine rẹ́?';
  }

  @override
  String get reminderNotice =>
      'Fóònù rẹ yóò dún, yóò sì gbọ̀n ní àkókò kọ̀ọ̀kan, gẹ́gẹ́ bí ìfitónilétí. Magana ń rán ọ létí ní àkókò tí o ṣètò. Kì í yí iye oògùn padà.';

  @override
  String get notificationsOff =>
      'Ìfitónilétí ti wà ní pípa fún Magana, nítorí náà ìrántí yóò hàn nígbà tí Magana bá ṣí nìkan. O lè tàn wọ́n nínú ètò fóònù rẹ.';

  @override
  String get missedDose =>
      'Ṣé o gbàgbé láti lo oògùn? Béèrè lọ́wọ́ oníṣègùn oògùn';

  @override
  String get reminderNotifyTitle => 'Àkókò láti lo oògùn rẹ ti tó';

  @override
  String get exactTitle => 'Ṣé kí ó dún ní àkókò gan-an?';

  @override
  String get exactBody =>
      'Kí ó lè dún ní ìṣẹ́jú gan-an, fóònù rẹ gbọ́dọ̀ gba Magana láàyè láti ṣètò aago àti ìrántí. Ojú-ìwé tó kàn ní bọ́tìnnì kan: tàn án, lẹ́yìn náà padà sẹ́yìn.';

  @override
  String get exactOpen => 'Ṣí ètò náà';

  @override
  String get notNow => 'Kì í ṣe báyìí';

  @override
  String get remindersMayBeLate =>
      'Lórí fóònù yìí, ìrántí lè dún ní wákàtí kan lẹ́yìn àkókò. Kí ó lè dún ní àkókò, gba Magana láàyè fún aago àti ìrántí.';

  @override
  String get allowOnTime => 'Gba ìrántí ní àkókò láàyè';

  @override
  String get msg_q_bleeding_no_sight =>
      'Ṣé o ti ní ìmọ̀lára tàbí tọ́ ẹ̀jẹ̀ wò, tàbí ṣé ẹnìkan ti sọ fún ọ pé ẹ̀jẹ̀ ń jáde lára rẹ, láti imú, èrìgì, èébì tàbí ìgbẹ́?';

  @override
  String get msg_q_yellow_eyes_no_sight =>
      'Ṣé ẹnìkan ti sọ fún ọ pé ojú rẹ tàbí awọ ara rẹ dà bí ẹni pé ó ti pọ́n?';

  @override
  String get msg_q_very_pale_no_sight =>
      'Ṣé ẹnìkan ti sọ fún ọ pé o funfun gan-an? Ṣé o ń rẹ̀wẹ̀sì gan-an, ṣé òòyì ń kọ́ ọ tàbí ṣé èémí ń já ọ nígbà tí o bá dìde dúró?';

  @override
  String get msg_q_dark_urine_no_sight =>
      'Ṣé ẹnìkan tó wà nítòsí rẹ ti rí i pé ìtọ̀ rẹ ṣókùnkùn gan-an, bíi kóòkì tàbí tíì?';

  @override
  String get msg_ask_someone_to_check =>
      'Jọ̀wọ́ ní kí ẹnìkan tó wà nítòsí rẹ yẹ̀ ẹ́ wò, tàbí lọ sí ilé-ìwòsàn.';

  @override
  String get cantTell => 'Mi ò mọ̀';

  @override
  String get appLanguageTitle => 'Èdè áàpù';

  @override
  String get languageSheetBody =>
      'Àwọn àkójọ, bọ́tìnnì, ìrànlọ́wọ́ àti ohùn Magana yóò yí padà sí èdè tí o yàn.';

  @override
  String get languageVoiceTip =>
      'O tún lè sọ “change language to Yoruba” lẹ́yìn tí o bá tẹ Sọ àṣẹ kan ní ojú-ìwé àkọ́kọ́.';

  @override
  String useLanguage(String language) {
    return 'Lo $language';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'Ẹ̀yà $version (kíkọ́ $build)';
  }

  @override
  String get settingsVersionNote =>
      'Sọ ẹ̀yà yìí fún ẹgbẹ́ Magana nígbà tí o bá ń ròyìn ìṣòro kan.';

  @override
  String get reportProblem => 'Ròyìn ìṣòro kan';

  @override
  String get reportHow =>
      'Sọ nǹkan mẹ́ta fún ẹgbẹ́ Magana: orúkọ ojú-ìwé náà, ohun tí o ṣe, àti ohun tí Magana sọ.';

  @override
  String get speakCommand => 'Sọ àṣẹ kan';

  @override
  String get listeningCommand => 'Mo ń gbọ́… Tẹ̀ láti dúró';

  @override
  String commandNotUnderstood(String heard) {
    return 'Mo gbọ́ “$heard”, ṣùgbọ́n mi ò mọ àṣẹ yẹn. Sọ help láti gbọ́ ohun tí o lè sọ.';
  }

  @override
  String get commandNothingHeard =>
      'Mi ò gbọ́ àṣẹ kankan. Tún gbìyànjú, tàbí sọ help.';

  @override
  String commandHelp(String commands) {
    return 'O lè sọ pé: $commands. Sọ àwọn àṣẹ ní èdè Gẹ̀ẹ́sì fún báyìí.';
  }

  @override
  String get changeLanguageCommand => 'change language';

  @override
  String get voiceCommandsUnavailable =>
      'A kò lè lo àṣẹ ohùn lórí fóònù yìí. Lo àwọn bọ́tìnnì dípò rẹ̀.';

  @override
  String get explainTitle => 'Àlàyé';

  @override
  String explainFrom(String source) {
    return 'Láti: $source';
  }

  @override
  String get explainPreviewBanner =>
      'Àyẹ̀wò. N-ATLAS, tí yóò ṣàlàyé ojú-ìwé ní èdè rẹ, kò tíì so pọ̀. Fún báyìí Magana ń ka ọ̀rọ̀ ojú-ìwé náà gẹ́gẹ́ bí a ṣe tẹ̀ ẹ́.';

  @override
  String answerLanguage(String language) {
    return 'Èdè ìdáhùn, lọ́wọ́lọ́wọ́ $language';
  }

  @override
  String get youSaid => 'O sọ pé';

  @override
  String basedOnPage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ó dá lórí: ìlà $count nínú ojú-ìwé rẹ',
      one: 'Ó dá lórí: ìlà 1 nínú ojú-ìwé rẹ',
    );
    return '$_temp0';
  }

  @override
  String get readExactlyNote =>
      'A ń ka àwọn nọ́ńbà àti ọ̀rọ̀ láti ojú-ìwé náà gẹ́gẹ́ bí a ṣe tẹ̀ wọ́n.';

  @override
  String get saySimpler => 'Sọ ọ́ ní ìrọ̀rùn';

  @override
  String get giveExample => 'Fún mi ní àpẹẹrẹ';

  @override
  String get explainDisclaimer =>
      'Magana lè ṣe àṣìṣe. Yẹ àwọn ìdáhùn pàtàkì wò pẹ̀lú olùkọ́ rẹ.';

  @override
  String get askAQuestion => 'Béèrè ìbéèrè';

  @override
  String get explainNoPage =>
      'Àlàyé jẹ́ nípa ojú-ìwé kan. Ka ojú-ìwé kan kọ́kọ́, lẹ́yìn náà yan Ṣàlàyé èyí.';

  @override
  String get explainThis => 'Ṣàlàyé èyí';

  @override
  String get explainQuestionPreview =>
      'Nígbà tí N-ATLAS bá so pọ̀, Magana yóò dáhùn ìbéèrè rẹ láti ojú-ìwé yìí. Fún báyìí, ojú-ìwé náà nìyí.';

  @override
  String get msg_explain_preview =>
      'Àyẹ̀wò ni èyí. Àlàyé ní èdè rẹ yóò dé nígbà tí N-ATLAS bá so pọ̀. Ojú-ìwé náà nìyí, a kà á gẹ́gẹ́ bí a ṣe tẹ̀ ẹ́.';

  @override
  String get msg_explained => 'Àlàyé náà nìyí.';

  @override
  String get msg_explain_bad_source =>
      'Kò sí ọ̀rọ̀ ojú-ìwé láti ṣàlàyé. Jọ̀wọ́ ka ojú-ìwé kan kọ́kọ́.';

  @override
  String get jumpWithinPage => 'Fò sí ibòmíràn nínú ojú-ìwé';

  @override
  String get jumpStart => 'Ìbẹ̀rẹ̀ ojú-ìwé';

  @override
  String jumpTable(int number) {
    return 'Tábìlì $number';
  }

  @override
  String get jumpWarnings => 'Ohun tó kàn tí mi ò dá lójú';

  @override
  String get jumpNotYet => 'A kò tíì lè fò sí àwọn àkọlé àti àwòrán.';

  @override
  String get paperLetter => 'Lẹ́tà àti fọ́ọ̀mù';

  @override
  String get paperLetterDetail => 'Ìkéde, fọ́ọ̀mù, ìwé ẹ̀sìn';

  @override
  String get noteLetter =>
      'Magana ń ka ohun tí a tẹ̀. Kì í fúnni ní ìmọ̀ràn òfin tàbí ti owó, kì í sì í béèrè PIN tàbí ọ̀rọ̀ aṣínà rẹ.';

  @override
  String get readAnyPaper => 'Ka ìwé èyíkéyìí';

  @override
  String get readAnyPaperDetail => 'Magana yóò mọ irú ìwé tí ó jẹ́';

  @override
  String detectedPaper(String paper) {
    return 'Irú ìwé: $paper.';
  }

  @override
  String weekReadLetter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lẹ́tà tàbí fọ́ọ̀mù $count ni a kà',
      one: 'Lẹ́tà tàbí fọ́ọ̀mù 1 ni a kà',
    );
    return '$_temp0';
  }

  @override
  String get readAgain => 'Tún kà á';

  @override
  String get askAboutResult => 'Kí ni èyí túmọ̀ sí?';

  @override
  String get resultAnswer =>
      'Òṣìṣẹ́ ìlera rẹ nìkan ló lè ṣàlàyé ohun tí èsì yìí túmọ̀ sí fún ọ. Mo lè fi ìbéèrè rẹ pamọ́ fún ìbẹ̀wò rẹ tó kàn, tàbí kí n ní kí nọ́ọ̀sì pè ọ́.';

  @override
  String youAsked(String question) {
    return 'O béèrè pé: “$question”';
  }

  @override
  String get saveQuestion => 'Fi ìbéèrè pamọ́';

  @override
  String get questionSaved =>
      'A ti fi pamọ́. Wà á rí i nínú Bá òṣìṣẹ́ ìlera sọ̀rọ̀.';

  @override
  String get askANurse => 'Béèrè lọ́wọ́ nọ́ọ̀sì';

  @override
  String get savedQuestionsTitle => 'Àwọn ìbéèrè fún ìbẹ̀wò rẹ tó kàn';

  @override
  String removeQuestion(String question) {
    return 'Yọ kúrò: $question';
  }

  @override
  String questionAbout(String question, String where) {
    return '$question (nípa $where)';
  }

  @override
  String get fromTheStatement => 'Láti inú ìwé bánkì, gẹ́gẹ́ bí a ṣe tẹ̀ ẹ́';

  @override
  String get findTransaction => 'Wá ìṣòwò kan';

  @override
  String get findPrompt =>
      'Sọ tàbí kọ ọ̀rọ̀, ọjọ́ tàbí iye owó láti inú ìṣòwò náà.';

  @override
  String get findField => 'Ọ̀rọ̀, ọjọ́ tàbí iye';

  @override
  String get findSearch => 'Wá a';

  @override
  String get findSpeak => 'Sọ ọ́ dípò rẹ̀';

  @override
  String findNoMatch(String query) {
    return 'Kò sí ìlà tó ní “$query”.';
  }

  @override
  String get sayYesOrNo => 'Sọ bẹ́ẹ̀ni, rárá, tàbí mi ò mọ̀';

  @override
  String voiceAnswerUnclear(String heard) {
    return 'Mo gbọ́ “$heard”. Jọ̀wọ́ sọ bẹ́ẹ̀ni, rárá, tàbí mi ò mọ̀.';
  }

  @override
  String scoreUpSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'ọ̀sẹ̀ $weeks sẹ́yìn',
      one: 'ọ̀sẹ̀ 1 sẹ́yìn',
    );
    return 'Ó ti gòkè láti $start nígbà tí o bẹ̀rẹ̀, $_temp0';
  }

  @override
  String scoreSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'ọ̀sẹ̀ $weeks sẹ́yìn',
      one: 'ọ̀sẹ̀ 1 sẹ́yìn',
    );
    return '$start nígbà tí o bẹ̀rẹ̀, $_temp0';
  }

  @override
  String get shareScore => 'Pín ìwọ̀n mi pẹ̀lú olùkọ́ mi';

  @override
  String get shareScoreNote =>
      'Olùkọ́ rẹ yóò rí ìwọ̀n rẹ, kì í ṣe ojú-ìwé tàbí ìbéèrè rẹ, nígbà tí a bá so kíláàsì rẹ pọ̀ mọ́ ojú-òpó olùkọ́ Magana.';

  @override
  String get sayNameWhenLocked => 'Sọ orúkọ oògùn nígbà tí fóònù bá wà ní títì';

  @override
  String get sayNameNote =>
      'Ní pípa: ojú títì yóò sọ “Ìrántí Magana” nìkan. Ní títàn: ojú títì yóò fi oògùn àti iye rẹ̀ hàn, Magana yóò sì sọ wọ́n jáde ní àkókò kọ̀ọ̀kan, nítorí náà àwọn tó wà nítòsí rẹ lè rí tàbí gbọ́ wọn.';

  @override
  String get reminderGenericTitle => 'Ìrántí Magana';

  @override
  String get reminderGenericBody => 'Ṣí Magana láti gbọ́ oògùn wo.';

  @override
  String get msg_bad_api_key =>
      'Ẹ̀dà Magana yìí kò lè dé iṣẹ́ kíkà. Jọ̀wọ́ ṣe àtúnṣe áàpù náà.';
}
