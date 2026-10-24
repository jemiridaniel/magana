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
      'Wannan zai iya zama mai tsanani. Don Allah ka je asibiti mafi kusa yanzu, ko ka kira 112. Kada ka jira a kira ka.';

  @override
  String get msg_nurse_call_within_2_hours =>
      'Na gode. Wata ma\'aikaciyar jinya za ta kira ka cikin awa 2.';

  @override
  String get msg_nurse_call_working_hours =>
      'Na gode. Wata ma\'aikaciyar jinya za ta kira ka a lokacin aiki.';

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
  String get msg_q_fever => 'Kana da zazzaɓi, ko jikinka yana da zafi sosai?';

  @override
  String get msg_q_fever_days => 'Kwana nawa kake da zazzaɓin?';

  @override
  String get msg_q_fits =>
      'Ka yi farfaɗiya, ko girgizar jiki da ba ka iya tsayarwa ba?';

  @override
  String get msg_q_cannot_drink =>
      'Ba ka iya shan komai, ko jariri ba ya iya shan nono?';

  @override
  String get msg_q_vomits_everything =>
      'Kana amai duk abin da ka ci ko ka sha?';

  @override
  String get msg_q_very_sleepy =>
      'Kana yawan barci sosai, ko ruɗewa, ko yana da wuya a tashe ka?';

  @override
  String get msg_q_bleeding =>
      'Kana zubar da jini ba tare da dalili ba, daga hanci ko dasashi, ko cikin amai ko bayan gida?';

  @override
  String get msg_q_yellow_eyes => 'Idanunka ko fatarka sun koma rawaya?';

  @override
  String get msg_q_hard_breathing =>
      'Kana numfashi da sauri sosai, ko kana fama wajen numfashi?';

  @override
  String get msg_q_very_pale =>
      'Tafin hannunka, leɓunanka ko cikin fatar idonka sun yi fari sosai?';

  @override
  String get msg_q_dark_urine =>
      'Fitsarinka ya yi duhu sosai, kamar kola ko shayi?';

  @override
  String get msg_q_too_weak =>
      'Ka raunana sosai har ba ka iya zama ko tsayawa ba tare da taimako ba?';

  @override
  String msg_line_end_unclear(String where) {
    return 'Ban iya karanta ƙarshen $where ba. Don Allah ka duba shi ko ka sake ɗaukar hoto.';
  }

  @override
  String get cueHigher => 'Sama';

  @override
  String get cueLower => 'Ƙasa';

  @override
  String get cueLeft => 'Hagu';

  @override
  String get cueRight => 'Dama';

  @override
  String get cueHoldStill => 'Riƙe a tsaye';

  @override
  String get cueCloser => 'Kusa';

  @override
  String get cueFurther => 'Nesa';

  @override
  String get cueMoreLight => 'Ƙarin haske';

  @override
  String get cueNoPage => 'Babu shafi';

  @override
  String stepOf(int n, int total) {
    return 'Mataki na $n cikin $total';
  }

  @override
  String get chooseLanguageTitle => 'Zaɓi harshenka';

  @override
  String get chooseLanguageBody =>
      'Magana za ta yi maka magana da wannan harshe. Kana iya canza shi a kowane lokaci daga shafin farko.';

  @override
  String get languageHearsHint =>
      'Ana karanta kowane zaɓi da harshensa idan ka taɓa shi.';

  @override
  String get continueLabel => 'Ci gaba';

  @override
  String get welcome => 'Barka da zuwa';

  @override
  String get ageTitle => 'Shekarunka nawa?';

  @override
  String get ageBody =>
      'Muna tambaya ne don Magana ta kasance lafiya kuma ta dace da kai.';

  @override
  String get ageAdult => 'Shekaruna 18 ko fiye';

  @override
  String get ageAdultDetail =>
      'Ka yi amfani da komai a Magana, har da takardun lafiya da na kuɗi.';

  @override
  String get ageTeen => 'Shekaruna 13 zuwa 17';

  @override
  String get ageTeenDetail =>
      'Iyaye, mai kula ko malami za su amince tukuna. Magana tana taimakawa da darussan makaranta kawai.';

  @override
  String get ageChild => 'Shekaruna ƙasa da 13';

  @override
  String get ageChildDetail =>
      'Malaminka zai yi amfani da Magana tare da kai a aji.';

  @override
  String get privacyNote =>
      'Ana goge hotunan shafukanka bayan an karanta su. Ba ma ba wa kowa bayananka.';

  @override
  String get hearAgain => 'Sake jin wannan shafi';

  @override
  String get readyTitle => 'Ka shirya';

  @override
  String get readyBody =>
      'Riƙe wayarka sama da kowane shafin da aka buga, Magana za ta karanta maka shi.';

  @override
  String get startLabel => 'Fara';

  @override
  String get consentTitle => 'Tambayi iyaye, mai kula ko malami';

  @override
  String get consentBody => 'Don Allah ku karanta ko ku saurari wannan tare.';

  @override
  String get consentPoint1 =>
      'Magana tana taimakawa da darussan makaranta kawai.';

  @override
  String get consentPoint2 =>
      'Babu takardun lafiya ko na kuɗi, babu WhatsApp, babu hira kai tsaye.';

  @override
  String get consentPoint3 => 'Ana goge hotuna bayan an karanta su.';

  @override
  String get consentConfirm =>
      'Ni ne iyaye, mai kula ko malami, kuma na amince';

  @override
  String get classroomTitle => 'Magana a aji';

  @override
  String get classroomBody =>
      'Malaminka zai fara Magana tare da kai a aji. Idan darasi ya ƙare, a rufe manhajar.';

  @override
  String get classroomStart => 'Malami: fara zaman aji';

  @override
  String get classroomConfirmTitle => 'Kai ne malamin?';

  @override
  String get classroomConfirmYes => 'Eh, fara zaman';

  @override
  String get cancel => 'Soke';

  @override
  String get back => 'Baya';

  @override
  String get msg_unknown_tier =>
      'Don Allah ka sake saita Magana: ba a gane rukunin shekarunka ba.';

  @override
  String get readPageSubtitleSchool =>
      'Aikin makaranta, rubuce-rubuce, littattafai da jarabawa';

  @override
  String get everydaySubtitle => 'Takardun lafiya da na kuɗi · 18+';

  @override
  String get paperMedicine => 'Lakabin magani';

  @override
  String get paperMedicineDetail => 'Lakabi da takardun likita';

  @override
  String get paperReport => 'Rahoton asibiti';

  @override
  String get paperReportDetail => 'Sakamakon gwaji da takardun sallama';

  @override
  String get paperStatement => 'Bayanan banki';

  @override
  String get paperStatementDetail => 'Bayanan banki, rasit da kuɗaɗen biya';

  @override
  String get talkToNurse => 'Yi magana da ma\'aikaciyar jinya';

  @override
  String get talkToNurseDetail => 'Tare da gwajin gaggawa na Ibà';

  @override
  String get everydayPrivacy =>
      'Ana karanta takardun sirri a wayarka, ba a adana su. Magana ba ta taɓa tambayar PIN ko kalmar sirri ba.';

  @override
  String get readExactly => 'Ana karantawa daidai yadda aka buga';

  @override
  String get noteMedicine =>
      'Magana tana karanta abin da aka buga. Ba ta ba da shawarar likita. Idan wani abu a lakabin bai fito sarai ba, tambayi mai sayar da magani kafin ka sha.';

  @override
  String get noteReport =>
      'Ana karanta lambobi da iyaka daidai yadda aka buga. Magana ba ta fassara sakamako: ma\'aikacin lafiyarka ne kawai zai iya bayyana ma\'anarsu gare ka.';

  @override
  String get noteStatement =>
      'Ana karanta kuɗaɗe daidai yadda aka buga. Ba a adana wannan bayanin ba. Magana ba ta taɓa tambayar PIN ko kalmar sirri ba. Idan wani adadi bai fito sarai ba, duba shi da bankinka ko wanda ka amince da shi.';

  @override
  String get askPharmacistOrNurse =>
      'Tambayi mai sayar da magani ko ma\'aikaciyar jinya';

  @override
  String get adultsOnly => 'Wannan na manya ne (shekara 18 zuwa sama).';
}
