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

  @override
  String get healthWorkerTitle => 'Yi magana da ma\'aikacin lafiya';

  @override
  String get healthWorkerSubtitle =>
      'Ma\'aikaciyar jinya ko mai sayar da magani za ta kira ka';

  @override
  String get helpWithTitle => 'Me kake buƙatar taimako a kai?';

  @override
  String get reasonMedicine => 'Fahimtar maganina';

  @override
  String get reasonResults => 'Fahimtar sakamakona';

  @override
  String get reasonOther => 'Wani abu daban';

  @override
  String get callLanguage => 'Harshen kiran';

  @override
  String get answerIbaFirst => 'Amsa \'yan tambayoyi na gaggawa tukuna (Ibà)';

  @override
  String get requestCallback => 'Nemi a kira ka';

  @override
  String get emergencyBold => 'Gaggawa?';

  @override
  String get emergencyText => 'Kada ka jira a kira ka. Kira 112 yanzu.';

  @override
  String get call112 => 'Kira 112';

  @override
  String get quickCheckTitle => 'Gwajin lafiya na gaggawa';

  @override
  String quickCheckProgress(int n, int total) {
    return 'Ibà · tambaya ta $n cikin $total';
  }

  @override
  String get yes => 'Eh';

  @override
  String get no => 'A\'a';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kwanaki $count',
      one: 'kwana 1',
    );
    return '$_temp0';
  }

  @override
  String get moreDays => 'Ƙara kwana ɗaya';

  @override
  String get fewerDays => 'Rage kwana ɗaya';

  @override
  String get nextLabel => 'Na gaba';

  @override
  String get quickCheckNote =>
      'Amsoshinka suna taimaka wa ma\'aikaciyar jinya ta yanke yadda za ta kira ka da sauri. Ibà ba ta gano cuta. Idan kana da alamun haɗari, Magana za ta ce ka je asibiti yanzu.';

  @override
  String get resultTitle => 'Sakamakonka';

  @override
  String get checkingAnswers => 'Ina duba amsoshinka.';

  @override
  String get backHome => 'Koma gida';

  @override
  String get msg_callback_booked =>
      'An tsara kiran. Ma\'aikaciyar jinya ko mai sayar da magani za ta kira ka.';

  @override
  String get msg_callback_unavailable =>
      'Ba a fara kiran dawowa ba tukuna. Idan kana buƙatar taimako yanzu, je asibiti ko ka kira 112.';

  @override
  String quickCheckProgressFallback(int n, int total) {
    return 'Gwajin tsaro na ciki · tambaya ta $n cikin $total';
  }

  @override
  String get resultUrgent =>
      'Ya kamata ma\'aikaciyar jinya ta kira ka cikin awa 2. Nemi a kira ka yanzu. Idan ka ƙara rashin lafiya, je asibiti ko ka kira 112.';

  @override
  String get resultRoutine =>
      'Ma\'aikaciyar jinya za ta iya kiran ka a lokacin aiki. Nemi a kira ka. Idan ka ƙara rashin lafiya, je asibiti ko ka kira 112.';

  @override
  String get quizTitle => 'Gwajin Biology';

  @override
  String quizProgress(int n, int total) {
    return 'Irin WAEC · Tambaya ta $n cikin $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct daidai cikin $answered da ka amsa';
  }

  @override
  String get quizSayAnswer => 'Faɗi A, B, C ko D';

  @override
  String get quizListening => 'Ina saurare… Taɓa don tsayawa';

  @override
  String quizCorrect(String letter) {
    return 'Daidai ne! Ka zaɓi $letter.';
  }

  @override
  String quizWrong(String letter, String answer) {
    return 'Ba haka ba. Ka zaɓi $letter. Amsar ita ce $answer.';
  }

  @override
  String quizUnclear(String heard) {
    return 'Na ji “$heard”. Don Allah faɗi A, B, C ko D.';
  }

  @override
  String get quizNothingHeard =>
      'Ban ji amsa ba. Faɗi A, B, C ko D, ko ka taɓa amsa sau biyu.';

  @override
  String get quizNoVoice =>
      'Ba a iya amsa da murya a wannan wayar ba. Taɓa amsa sau biyu maimakon haka.';

  @override
  String get quizRepeat => 'Maimaita tambaya';

  @override
  String get quizNext => 'Tambaya ta gaba';

  @override
  String get quizFinish => 'Duba sakamakona';

  @override
  String get quizYourAnswerRight => 'amsarka, daidai ne';

  @override
  String get quizYourAnswerWrong => 'amsarka, ba daidai ba';

  @override
  String get quizRightAnswer => 'amsar da ta dace';

  @override
  String get quizResultTitle => 'An gama gwaji';

  @override
  String quizResult(int correct, int total) {
    return 'Ka samu $correct daidai cikin $total.';
  }

  @override
  String get quizAgain => 'Sake gwadawa';

  @override
  String get quizSource =>
      'Ƙungiyar Magana ce ta rubuta tambayoyin irin na WAEC Biology. Ba tsofaffin tambayoyi ba ne. Tambayoyin da Turanci suke.';

  @override
  String get skillsSubtitle => 'Gajerun darussa na murya, a saurinka';

  @override
  String nextLesson(int minutes) {
    return 'Darasi na gaba · minti $minutes';
  }

  @override
  String get playLesson => 'Kunna darasi';

  @override
  String get pauseLesson => 'Dakata';

  @override
  String get practiseNow => 'Gwada yanzu';

  @override
  String get lessonDone => 'An gama';

  @override
  String lessonStepOf(int step, int total) {
    return 'Mataki na $step cikin $total';
  }

  @override
  String get lessonNotStarted => 'Ba a fara ba';

  @override
  String get allLessonsDone => 'Ka gama duk darussan. Madalla!';

  @override
  String get practiseWithChampion => 'Gwada tare da Gwarzon Magana';

  @override
  String get skillsNote =>
      'Darussan misali ne da ƙungiyar Magana ta rubuta; masu horar da gyaran rayuwa za su duba su. Darussan da Turanci suke a yanzu.';

  @override
  String get previousStep => 'Mataki na baya';

  @override
  String get nextStep => 'Mataki na gaba';

  @override
  String get lessonFinished => 'An gama darasi.';

  @override
  String get scoreTitle => 'Makin \'Yancina';

  @override
  String get scoreSubtitle => 'Ayyukan da ka gama a Magana';

  @override
  String scoreOutOf(int score) {
    return '$score cikin 100';
  }

  @override
  String get scoreByArea => 'Ta fanni';

  @override
  String get areaLearning => 'Karatu';

  @override
  String get areaHealth => 'Takardun lafiya';

  @override
  String get areaMoney => 'Kuɗi';

  @override
  String get areaSkills => 'Ƙwarewa';

  @override
  String areaScoreLabel(String area, int score) {
    return '$area: $score cikin 100';
  }

  @override
  String get scoreThisWeek => 'Wannan makon';

  @override
  String get scoreNothingThisWeek =>
      'Babu aiki tukuna a wannan makon. Karanta shafi ko ka yi gwaji don farawa.';

  @override
  String weekReadSchool(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An karanta shafukan aikin makaranta $count',
      one: 'An karanta shafin aikin makaranta 1',
    );
    return '$_temp0';
  }

  @override
  String weekReadMedicine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An karanta alamun magani $count',
      one: 'An karanta alamar magani 1',
    );
    return '$_temp0';
  }

  @override
  String weekReadReport(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An karanta rahotannin lafiya $count',
      one: 'An karanta rahoton lafiya 1',
    );
    return '$_temp0';
  }

  @override
  String weekReadStatement(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An karanta bayanan banki ko rasidi $count',
      one: 'An karanta bayanin banki ko rasidi 1',
    );
    return '$_temp0';
  }

  @override
  String weekQuiz(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An gama gwaje-gwaje $count',
      one: 'An gama gwaji 1',
    );
    return '$_temp0';
  }

  @override
  String weekLesson(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An gama darussa $count',
      one: 'An gama darasi 1',
    );
    return '$_temp0';
  }

  @override
  String get scoreHow =>
      'Makinka yana ƙidaya ayyukan gaske da ka gama a Magana cikin kwanaki 30 da suka wuce. Yana nan a wannan wayar; kai kaɗai kake gani.';

  @override
  String get championsTitle => 'Gwarzayen Magana';

  @override
  String get championsSubtitle => 'Koyi daga waɗanda suka taɓa fuskantar haka';

  @override
  String get championSample => 'Misalin bayanan mutum';

  @override
  String get championDetail =>
      'Makaho tun yana shekara 12 · Kano · Hausa, Turanci';

  @override
  String get championNotYet =>
      'Wannan misali ne kawai. Za a haɗa ka da Gwarzo ta ƙungiyoyin abokan hulɗa. Ba a iya kira tukuna ba.';

  @override
  String get becomeChampion => 'Zama Gwarzo';

  @override
  String get becomeChampionBody =>
      'Taimaka wa wasu a cikin al\'ummarka kuma ka sami takardar shaida.';

  @override
  String get champStepBasics => 'Gama darasin Asalin waya';

  @override
  String get champStepPhotos => 'Gama darasin Ɗaukar hoto mai kyau';

  @override
  String get champStepScore => 'Kai makin \'Yanci na 60';

  @override
  String get champStepTraining => 'Halarci horon Gwarzo na awa 2';

  @override
  String get champStepHelp => 'Taimaki mutanenka 3 na farko';

  @override
  String get stepDone => 'an gama';

  @override
  String get stepNotDone => 'ba a gama ba tukuna';

  @override
  String get championsPartnerNote =>
      'Za a yi horon Gwarzo tare da ƙungiyoyin abokan hulɗa. Ba a buɗe ba tukuna.';

  @override
  String get librarySubtitle => 'Karatun da aka adana, na kwanaki 30';

  @override
  String get libraryEmpty =>
      'Babu abin da aka adana tukuna. Bayan Magana ta karanta shafi, zaɓi Adana a laburarena.';

  @override
  String libraryDeletesIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'za a goge cikin kwanaki $count',
      one: 'za a goge gobe',
      zero: 'za a goge yau',
    );
    return '$_temp0';
  }

  @override
  String librarySavedOn(String date) {
    return 'An adana $date';
  }

  @override
  String get libraryPrivacy =>
      'Karatun da aka adana suna nan a wannan wayar kuma ana goge su bayan kwanaki 30. Ba a taɓa adana hotuna ba.';

  @override
  String get saveToLibrary => 'Adana a laburarena';

  @override
  String get savedToLibrary =>
      'An adana a laburarena. Zai kasance a wannan wayar na kwanaki 30.';

  @override
  String get deleteFromLibrary => 'Goge daga laburarena';

  @override
  String get deleteConfirm => 'A goge wannan karatun daga laburarenka?';

  @override
  String get deleteYes => 'Goge';

  @override
  String get deletedFromLibrary => 'An goge daga laburarenka.';

  @override
  String get remindersTitle => 'Magungunan yau';

  @override
  String get remindersSubtitle => 'Lokutan da ka tsara da mai ba da magani';

  @override
  String get remindersCard => 'Tunatarwar magani';

  @override
  String get remindersCardDetail => 'Lokutan shan maganinka';

  @override
  String get remindersEmpty =>
      'Babu tunatarwa tukuna. Ƙara lokutan da mai ba da magani ko likita ya ba ka.';

  @override
  String get doseTaken => 'An sha';

  @override
  String get doseDue => 'Lokaci ya yi';

  @override
  String get doseLater => 'Anjima yau';

  @override
  String doseLabel(String time, String state, String medicine, String amount) {
    return '$time, $state. $medicine. $amount';
  }

  @override
  String get iTookIt => 'Na sha';

  @override
  String get remindLater => 'Tuna min bayan minti 15';

  @override
  String get remindLaterSet => 'Zan sake tuna maka bayan minti 15.';

  @override
  String get markedTaken => 'An rubuta cewa ka sha.';

  @override
  String get addReminder => 'Ƙara tunatarwa';

  @override
  String get medicineName => 'Sunan magani, kamar yadda yake a jiki';

  @override
  String get medicineAmount =>
      'Yawan da za a sha, kamar yadda mai ba da magani ya faɗa (misali, ƙwaya 2)';

  @override
  String get reminderTime => 'Lokaci';

  @override
  String get earlierHour => 'Awa ɗaya a baya';

  @override
  String get laterHour => 'Awa ɗaya a gaba';

  @override
  String get earlierMinutes => 'Minti 15 a baya';

  @override
  String get laterMinutes => 'Minti 15 a gaba';

  @override
  String get saveReminder => 'Adana tunatarwa';

  @override
  String get medicineNameNeeded => 'Rubuta sunan maganin da farko.';

  @override
  String reminderSaved(String time) {
    return 'An adana tunatarwa na $time.';
  }

  @override
  String get deleteReminder => 'Goge tunatarwa';

  @override
  String deleteReminderConfirm(String time, String medicine) {
    return 'A goge tunatarwar $time ta $medicine?';
  }

  @override
  String get reminderNotice =>
      'Wayarka za ta yi ƙara da girgiza a kowane lokaci, a matsayin sanarwa. Magana tana tuna maka a lokutan da ka saita. Ba ta taɓa canja yawan magani ba.';

  @override
  String get notificationsOff =>
      'An kashe sanarwa ga Magana, don haka tunatarwa za ta bayyana ne kawai idan Magana a buɗe take. Za ka iya kunna su a saitunan wayarka.';

  @override
  String get missedDose => 'Ka manta da shan magani? Tambayi mai ba da magani';

  @override
  String get reminderNotifyTitle => 'Lokacin shan maganinka ya yi';

  @override
  String get exactTitle => 'Ta yi ƙara a kan lokaci?';

  @override
  String get exactBody =>
      'Don ta yi ƙara daidai minti, wayarka tana buƙatar ba Magana izinin saita ƙararrawa da tunatarwa. Shafi na gaba yana da maɓalli ɗaya: kunna shi, sannan ka koma.';

  @override
  String get exactOpen => 'Buɗe saitin';

  @override
  String get notNow => 'Ba yanzu ba';

  @override
  String get remindersMayBeLate =>
      'A wannan wayar, tunatarwa na iya yin ƙara har awa ɗaya a makare. Don ta yi ƙara a kan lokaci, ba Magana izinin ƙararrawa da tunatarwa.';

  @override
  String get allowOnTime => 'Ba da izinin tunatarwa a kan lokaci';
}
