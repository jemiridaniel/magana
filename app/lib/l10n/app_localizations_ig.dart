// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Igbo (`ig`).
class AppLocalizationsIg extends AppLocalizations {
  AppLocalizationsIg([String locale = 'ig']) : super(locale);

  @override
  String get appTitle => 'Magana';

  @override
  String get greeting => 'Ndewo';

  @override
  String languageButtonLabel(String language) {
    return 'Asụsụ ngwa: $language. Gbanwee asụsụ';
  }

  @override
  String get chooseLanguage => 'Họrọ asụsụ ngwa';

  @override
  String languageChanged(String language) {
    return 'Asụsụ ngwa bụ $language ugbu a.';
  }

  @override
  String get settings => 'Ntọala';

  @override
  String get readPage => 'Gụọ peeji';

  @override
  String get readPageSubtitle =>
      'Ihe ọmụmụ ụlọ akwụkwọ, akụkọ ahụike, nkwupụta ụlọ akụ, akwụkwọ ozi — ihe ọ bụla e biri ebi';

  @override
  String get askQuestion => 'Jụọ ajụjụ';

  @override
  String get practiceQuiz => 'Ajụjụ omume';

  @override
  String get myLibrary => 'Ọbá akwụkwọ m';

  @override
  String get everydayPapers => 'Akwụkwọ kwa ụbọchị';

  @override
  String get skills => 'Nkà';

  @override
  String get myScore => 'Akara m';

  @override
  String get holdToSpeak => 'Jide ka ị kwuo okwu';

  @override
  String get holdToSpeakLabel => 'Jide ka ị kwuo iwu';

  @override
  String get voiceCommands => 'Iwu olu';

  @override
  String get comingSoonHint => 'Ọ na-abịa n\'oge na-adịghị anya';

  @override
  String comingSoon(String feature) {
    return '$feature na-abịa n\'oge na-adịghị anya.';
  }

  @override
  String get backToHome => 'Laghachi n\'ụlọ';

  @override
  String get framingGuidance =>
      'Tọgbọ peeji ahụ n\'ala ebe ìhè dị mma, jide ekwentị ahụ n\'elu ya ihe dịka ogologo aka gị. Aga m agwa gị otú ị ga-esi bugharịa ya, ma see foto ahụ mgbe peeji ahụ niile kwụsiri ọtọ. Ị nwekwara ike ịpịa See foto.';

  @override
  String get repeat => 'Kwughachi';

  @override
  String get repeatInstructions => 'Nụghachi ntụziaka';

  @override
  String get takePhoto => 'See foto';

  @override
  String get gallery => 'Foto';

  @override
  String get galleryLabel => 'Họrọ foto site na foto gị';

  @override
  String get cameraFailed => 'Enweghị m ike imepe igwefoto. Nwaa Foto kama.';

  @override
  String get readingPage => 'Ana m agụ peeji ahụ. Biko chere.';

  @override
  String get noTextFound =>
      'Ahụghị m ederede ọ bụla. Lelee na peeji ahụ chere ihu elu, ma nwaa ọzọ.';

  @override
  String get cannotReach =>
      'Enweghị m ike iru Magana. Lelee njikọ gị ma nwaa ọzọ.';

  @override
  String get readFailed =>
      'Nsogbu mere mgbe m na-agụ peeji ahụ. Biko nwaa ọzọ.';

  @override
  String get yourPage => 'Peeji gị';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ahịrị $count',
      one: 'ahịrị 1',
    );
    return '$_temp0';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'usoro $count',
      one: 'usoro 1',
    );
    return '$_temp0';
  }

  @override
  String unclearCount(int count) {
    return '$count edoghị anya';
  }

  @override
  String linePosition(int number, int total) {
    return 'Ahịrị $number n\'ime $total';
  }

  @override
  String rowPosition(int number, int total) {
    return 'Usoro $number n\'ime $total';
  }

  @override
  String rowPositionInTable(int number, int total, int table) {
    return 'Usoro $number n\'ime $total, tebụl $table';
  }

  @override
  String get nowReading => 'a na-agụ ya ugbu a';

  @override
  String get previous => 'Azụ';

  @override
  String get next => 'Ọzọ';

  @override
  String get previousLine => 'Ahịrị gara aga';

  @override
  String get previousRow => 'Usoro gara aga';

  @override
  String get nextLine => 'Ahịrị na-esote';

  @override
  String get nextRow => 'Usoro na-esote';

  @override
  String get repeatLine => 'Gụghachi ahịrị a';

  @override
  String get repeatRow => 'Gụghachi usoro a';

  @override
  String speed(String value) {
    return 'Ọsọ $value';
  }

  @override
  String speedLabel(String value) {
    return 'Ọsọ ọgụgụ $value. Pịa ka ịgbanwee ya';
  }

  @override
  String get pause => 'Kwụsịtụ';

  @override
  String get play => 'Malite';

  @override
  String get pauseLabel => 'Kwụsịtụ ọgụgụ';

  @override
  String get playLabel => 'Gụọ site ebe a';

  @override
  String get pageRead => 'Agụchaala m peeji ahụ.';

  @override
  String unsureSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ejighị m n\'aka $count n\'ime ha.',
      one: 'Ejighị m n\'aka otu n\'ime ha.',
    );
    return '$_temp0 Aga m agwa gị mgbe anyị ruru ebe ahụ.';
  }

  @override
  String get firstLine => 'Nke a bụ ahịrị mbụ.';

  @override
  String get firstRow => 'Nke a bụ usoro mbụ.';

  @override
  String get endOfPage => 'Njedebe peeji.';

  @override
  String get endOfPageHint =>
      'Njedebe peeji. Pịa Kwughachi, ma ọ bụ laghachi ka ịgụọ peeji ọzọ.';

  @override
  String whereLine(int number) {
    return 'ahịrị $number';
  }

  @override
  String whereRow(int number) {
    return 'usoro $number';
  }

  @override
  String whereCell(int row, int col) {
    return 'usoro $row, kọlụm $col';
  }

  @override
  String get whereTop => 'n\'elu peeji ahụ';

  @override
  String get whereMiddle => 'n\'etiti peeji ahụ';

  @override
  String get whereBottom => 'n\'okpuru peeji ahụ';

  @override
  String get unclearNumber => 'nọmba edoghị anya';

  @override
  String get faintPrint => 'Ederede na-adịghị ahụ anya';

  @override
  String get msg_too_dark =>
      'Ọ gbara ọchịchịrị. Gbanye ọkụ ekwentị ma ọ bụ gaa ebe ìhè dị.';

  @override
  String get msg_blurry =>
      'Foto ahụ edoghị anya. Jide ekwentị ahụ nke ọma ma nwaa ọzọ.';

  @override
  String msg_low_confidence(String where) {
    return 'Ejighị m n\'aka $where. Biko lelee ya ma ọ bụ see foto ọzọ.';
  }

  @override
  String msg_low_confidence_number(String where) {
    return 'Enweghị m ike ịgụ otu nọmba na $where nke ọma. Biko lelee ya ma ọ bụ see foto ọzọ.';
  }

  @override
  String msg_unreadable_number(String where) {
    return 'Enweghị m ike ịgụ otu nọmba na $where nke ọma. Biko lelee ya ma ọ bụ see foto ọzọ.';
  }

  @override
  String msg_number_mismatch(String where) {
    return 'Enweghị m ike ịgụ otu nọmba na $where nke ọma. Biko lelee ya ma ọ bụ see foto ọzọ.';
  }

  @override
  String msg_faint_region(String where) {
    return 'Enwere ederede na-adịghị ahụ anya $where nke m na-enweghị ike ịgụ. Chọọ ìhè karịa, ma ọ bụ see foto ọzọ.';
  }

  @override
  String get msg_unknown_mode =>
      'Họrọ ihe ọmụmụ ụlọ akwụkwọ, ahụike ma ọ bụ ego.';

  @override
  String get msg_not_allowed_for_tier => 'Nke a adịghị na akaụntụ a.';

  @override
  String get msg_consent_required =>
      'Ụmụ akwụkwọ dị afọ 13 ruo 17 chọrọ nkwenye nne na nna ma ọ bụ onye na-elekọta ha mbụ.';

  @override
  String get msg_teacher_session_required =>
      'Ụmụ akwụkwọ na-erubeghị afọ 13 nwere ike iji Magana naanị n\'oge nkuzi onye nkuzi na-edu.';

  @override
  String get msg_unreadable_image =>
      'Enweghị m ike imepe foto ahụ. Biko nwaa ọzọ.';

  @override
  String get msg_numbers_unconfirmed =>
      'Enweghị m ike ikwenye ụfọdụ nọmba na nkọwa a, ya mere aga m agụ peeji ahụ otú o si dị.';

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
  String get guideTooDark =>
      'Ọ gbara ọchịchịrị. Gbanye ọkụ ekwentị ma ọ bụ chọọ ìhè karịa.';

  @override
  String get guideNoPage =>
      'Ahụbeghị m peeji. Tụgharịa ekwentị ahụ lee peeji ahụ.';

  @override
  String get guideMoveCloser => 'Bịaruo ekwentị ahụ nso na peeji ahụ ntakịrị.';

  @override
  String get guideLiftPhone =>
      'Welie ekwentị ahụ elu ntakịrị, ka peeji ahụ niile pụta.';

  @override
  String get guideMoveUp =>
      'Bugharịa ekwentị ahụ ntakịrị gaa n\'elu peeji ahụ. E bipụrụ elu ya.';

  @override
  String get guideMoveDown =>
      'Bugharịa ekwentị ahụ ntakịrị gaa n\'okpuru peeji ahụ. E bipụrụ okpuru ya.';

  @override
  String get guideMoveLeft =>
      'Bugharịa ekwentị ahụ ntakịrị gaa n\'aka ekpe. E bipụrụ akụkụ aka ekpe.';

  @override
  String get guideMoveRight =>
      'Bugharịa ekwentị ahụ ntakịrị gaa n\'aka nri. E bipụrụ akụkụ aka nri.';

  @override
  String get guideHoldStill => 'Ọ dị mma. Jide ya nke ọma.';

  @override
  String get guideCapturing => 'Ana m ese foto ahụ.';

  @override
  String get autoCapture => 'See foto n\'onwe ya';

  @override
  String get torchOn => 'Gbanye ọkụ ekwentị';

  @override
  String get torchOff => 'Gbanyụọ ọkụ ekwentị';

  @override
  String get cameraView => 'Ihe igwefoto na-ahụ';

  @override
  String get cameraUnavailable =>
      'Enweghị m ike iji igwefoto. Nye ikike igwefoto na Ntọala, ma ọ bụ họrọ foto site na foto gị.';

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
}
