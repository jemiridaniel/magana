// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hausa (`ha`).
class AppLocalizationsHa extends AppLocalizations {
  AppLocalizationsHa([String locale = 'ha']) : super(locale);

  @override
  String get appTitle => 'Magana';

  @override
  String get greeting => 'Sannu';

  @override
  String languageButtonLabel(String language) {
    return 'Harshen manhaja: $language. Canza harshe';
  }

  @override
  String get chooseLanguage => 'Zaɓi harshen manhaja';

  @override
  String languageChanged(String language) {
    return 'Yanzu harshen manhaja shi ne $language.';
  }

  @override
  String get settings => 'Saituna';

  @override
  String get readPage => 'Karanta shafi';

  @override
  String get readPageSubtitle =>
      'Aikin makaranta, rahoton asibiti, bayanan banki, wasiƙu — duk abin da aka buga';

  @override
  String get askQuestion => 'Yi tambaya';

  @override
  String get practiceQuiz => 'Jarabawar gwaji';

  @override
  String get myLibrary => 'Ɗakin karatuna';

  @override
  String get everydayPapers => 'Takardun yau da kullum';

  @override
  String get skills => 'Ƙwarewa';

  @override
  String get myScore => 'Makina';

  @override
  String get holdToSpeak => 'Riƙe ka yi magana';

  @override
  String get holdToSpeakLabel => 'Riƙe don faɗin umarni';

  @override
  String get voiceCommands => 'Umarnin murya';

  @override
  String get comingSoonHint => 'Yana zuwa nan ba da daɗewa ba';

  @override
  String comingSoon(String feature) {
    return '$feature yana zuwa nan ba da daɗewa ba.';
  }

  @override
  String get backToHome => 'Koma gida';

  @override
  String get framingGuidance =>
      'Shimfiɗa shafin a wuri mai haske, ka riƙe wayar sama da shi kamar tsawon hannunka. Zan gaya maka yadda za ka matsa, kuma zan ɗauki hoton idan shafin duka ya tsaya. Kana iya taɓa Ɗauki hoto kuma.';

  @override
  String get repeat => 'Maimaita';

  @override
  String get repeatInstructions => 'Sake jin umarnin';

  @override
  String get takePhoto => 'Ɗauki hoto';

  @override
  String get gallery => 'Hotuna';

  @override
  String get galleryLabel => 'Zaɓi hoto daga cikin hotuna';

  @override
  String get cameraFailed =>
      'Na kasa buɗe kyamara. Gwada Hotuna maimakon haka.';

  @override
  String get readingPage => 'Ina karanta shafin. Don Allah ka jira.';

  @override
  String get noTextFound =>
      'Ban sami wani rubutu ba. Tabbatar shafin yana fuskantar sama, ka sake gwadawa.';

  @override
  String get cannotReach =>
      'Na kasa haɗawa da Magana. Duba haɗin intanet, ka sake gwadawa.';

  @override
  String get readFailed =>
      'An sami matsala wajen karanta shafin. Don Allah ka sake gwadawa.';

  @override
  String get yourPage => 'Shafinka';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'layuka $count',
      one: 'layi 1',
    );
    return '$_temp0';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jeri $count',
      one: 'jere 1',
    );
    return '$_temp0';
  }

  @override
  String unclearCount(int count) {
    return '$count ba a tabbatar ba';
  }

  @override
  String linePosition(int number, int total) {
    return 'Layi $number cikin $total';
  }

  @override
  String rowPosition(int number, int total) {
    return 'Jere $number cikin $total';
  }

  @override
  String rowPositionInTable(int number, int total, int table) {
    return 'Jere $number cikin $total, tebur $table';
  }

  @override
  String get nowReading => 'ana karantawa yanzu';

  @override
  String get previous => 'Baya';

  @override
  String get next => 'Gaba';

  @override
  String get previousLine => 'Layin baya';

  @override
  String get previousRow => 'Jeren baya';

  @override
  String get nextLine => 'Layi na gaba';

  @override
  String get nextRow => 'Jere na gaba';

  @override
  String get repeatLine => 'Maimaita wannan layi';

  @override
  String get repeatRow => 'Maimaita wannan jere';

  @override
  String speed(String value) {
    return 'Gudu $value';
  }

  @override
  String speedLabel(String value) {
    return 'Gudun karatu $value. Taɓa don canzawa';
  }

  @override
  String get pause => 'Dakata';

  @override
  String get play => 'Kunna';

  @override
  String get pauseLabel => 'Dakatar da karatu';

  @override
  String get playLabel => 'Karanta daga nan';

  @override
  String get pageRead => 'An karanta shafin.';

  @override
  String unsureSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ban tabbatar da guda $count ba.',
      one: 'Ban tabbatar da guda 1 ba.',
    );
    return '$_temp0 Zan gaya maka idan mun kai can.';
  }

  @override
  String get firstLine => 'Wannan shi ne layi na farko.';

  @override
  String get firstRow => 'Wannan shi ne jere na farko.';

  @override
  String get endOfPage => 'Ƙarshen shafi.';

  @override
  String get endOfPageHint =>
      'Ƙarshen shafi. Taɓa Maimaita, ko ka koma ka karanta wani shafi.';

  @override
  String whereLine(int number) {
    return 'layi na $number';
  }

  @override
  String whereRow(int number) {
    return 'jere na $number';
  }

  @override
  String whereCell(int row, int col) {
    return 'jere na $row, shafi na $col';
  }

  @override
  String get whereTop => 'a saman shafin';

  @override
  String get whereMiddle => 'a tsakiyar shafin';

  @override
  String get whereBottom => 'a ƙasan shafin';

  @override
  String get unclearNumber => 'lambar da ba a gane ba';

  @override
  String get faintPrint => 'Rubutu mara haske';

  @override
  String get msg_too_dark =>
      'Akwai duhu sosai. Kunna fitila ko ka matsa inda haske yake.';

  @override
  String get msg_blurry =>
      'Hoton bai fito sarai ba. Riƙe wayar a tsaye ka sake gwadawa.';

  @override
  String msg_low_confidence(String where) {
    return 'Ban tabbatar da $where ba. Don Allah ka duba shi ko ka sake ɗaukar hoto.';
  }

  @override
  String msg_low_confidence_number(String where) {
    return 'Ban iya karanta wata lamba a $where sarai ba. Don Allah ka duba ko ka sake ɗaukar hoto.';
  }

  @override
  String msg_unreadable_number(String where) {
    return 'Ban iya karanta wata lamba a $where sarai ba. Don Allah ka duba ko ka sake ɗaukar hoto.';
  }

  @override
  String msg_number_mismatch(String where) {
    return 'Ban iya karanta wata lamba a $where sarai ba. Don Allah ka duba ko ka sake ɗaukar hoto.';
  }

  @override
  String msg_faint_region(String where) {
    return 'Akwai rubutu mara haske $where da ban iya karantawa ba. Ka nemi ƙarin haske, ko ka sake ɗaukar hoto.';
  }

  @override
  String get msg_unknown_mode => 'Zaɓi aikin makaranta, lafiya ko kuɗi.';

  @override
  String get msg_not_allowed_for_tier => 'Wannan bai samu a wannan asusun ba.';

  @override
  String get msg_consent_required =>
      'Ɗalibai masu shekaru 13 zuwa 17 suna buƙatar izinin iyaye ko mai kula da su tukuna.';

  @override
  String get msg_teacher_session_required =>
      'Ɗalibai ƙasa da shekara 13 suna iya amfani da Magana ne kawai a zaman da malami ke jagoranta.';

  @override
  String get msg_unreadable_image =>
      'Na kasa buɗe wannan hoton. Don Allah ka sake gwadawa.';

  @override
  String get msg_numbers_unconfirmed =>
      'Ban iya tabbatar da wasu lambobi a wannan bayanin ba, don haka zan karanta shafin daidai yadda yake.';

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
  String get guideTooDark => 'Akwai duhu. Kunna fitila ko ka nemi ƙarin haske.';

  @override
  String get guideNoPage =>
      'Ban ga shafi ba tukuna. Karkata wayar zuwa kan shafin.';

  @override
  String get guideMoveCloser => 'Kawo wayar kusa da shafin kaɗan.';

  @override
  String get guideLiftPhone =>
      'Ɗaga wayar sama kaɗan, don shafin duka ya shiga.';

  @override
  String get guideMoveUp =>
      'Matsar da wayar zuwa saman shafin kaɗan. An yanke saman.';

  @override
  String get guideMoveDown =>
      'Matsar da wayar zuwa ƙasan shafin kaɗan. An yanke ƙasan.';

  @override
  String get guideMoveLeft =>
      'Matsar da wayar hagu kaɗan. An yanke gefen hagu.';

  @override
  String get guideMoveRight =>
      'Matsar da wayar dama kaɗan. An yanke gefen dama.';

  @override
  String get guideHoldStill => 'Yayi kyau. Riƙe a tsaye.';

  @override
  String get guideCapturing => 'Ina ɗaukar hoton.';

  @override
  String get autoCapture => 'Ɗauka da kanta';

  @override
  String get torchOn => 'Kunna fitila';

  @override
  String get torchOff => 'Kashe fitila';

  @override
  String get cameraView => 'Kallon kyamara';

  @override
  String get cameraUnavailable =>
      'Ba zan iya amfani da kyamara ba. Ba da izinin kyamara a Saituna, ko ka zaɓi hoto daga cikin hotuna.';

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
