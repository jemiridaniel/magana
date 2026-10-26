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
  String get serverSleeping =>
      'Sabar Magana tana barci. Don Allah ka sake gwadawa nan gaba.';

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
  String get unclearLetter => 'harafi mara tabbas';

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
      'Ban iya bayyana wannan shafi lafiya ba. Ga shi an sake karanta shi.';

  @override
  String get msg_class_code_wrong =>
      'Lambar ajin nan ba daidai ba ce. Duba ta tare da malaminka.';

  @override
  String get msg_code_locked =>
      'Lambobi marasa kyau sun yi yawa. Don Allah jira minti 5, sannan ka sake gwadawa.';

  @override
  String get msg_teacher_code_needed =>
      'Malaminka ne kawai zai iya mayar da kai wani aji. Roƙe shi ya shigar da lambar malami.';

  @override
  String get msg_teacher_code_wrong =>
      'Lambar malamin nan ba daidai ba ce. Roƙi malaminka ya duba ta.';

  @override
  String get msg_class_has_no_accounts =>
      'Wannan ajin yana da darussan da malaminka ke jagoranta kawai. Tambayi malaminka.';

  @override
  String get msg_not_linked =>
      'Wannan wayar ba ta cikin aji yanzu. Har yanzu kana iya karanta shafuka.';

  @override
  String get msg_class_joined => 'Ka shiga ajin.';

  @override
  String get msg_class_changed => 'An canza ajinka.';

  @override
  String get msg_explain_wrong_language =>
      'Ban iya bayyana wannan da harshenka ba, don haka zan karanta shafin daidai yadda yake.';

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
  String quizProgress(int n, int total) {
    return 'Tambaya ta $n cikin $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct daidai cikin $answered da ka amsa';
  }

  @override
  String quizSayAnswer(String letters) {
    return 'Faɗi $letters';
  }

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
  String quizUnclear(String heard, String letters) {
    return 'Na ji “$heard”. Don Allah faɗi $letters.';
  }

  @override
  String quizNothingHeard(String letters) {
    return 'Ban ji amsa ba. Faɗi $letters, ko ka taɓa amsa sau biyu.';
  }

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
  String get areaMoney => 'Kuɗi da wasiƙu';

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

  @override
  String get msg_q_bleeding_no_sight =>
      'Ka ji ko ka ɗanɗana jini, ko wani ya gaya maka cewa kana zubar da jini, daga hanci, dasashi, amai ko bayan gida?';

  @override
  String get msg_q_yellow_eyes_no_sight =>
      'Wani ya gaya maka cewa idanunka ko fatarka sun yi kama da rawaya?';

  @override
  String get msg_q_very_pale_no_sight =>
      'Wani ya gaya maka cewa ka yi fari sosai? Kana jin rauni sosai, jiri ko ƙarancin numfashi idan ka tashi tsaye?';

  @override
  String get msg_q_dark_urine_no_sight =>
      'Wani da ke kusa da kai ya ga cewa fitsarinka ya yi duhu sosai, kamar kola ko shayi?';

  @override
  String get msg_ask_someone_to_check =>
      'Don Allah ka roƙi wani da ke kusa da kai ya duba, ko ka je asibiti.';

  @override
  String get cantTell => 'Ban sani ba';

  @override
  String get appLanguageTitle => 'Harshen manhaja';

  @override
  String get languageSheetBody =>
      'Menu, maɓallai, taimako da muryar Magana duk za su koma harshen da ka zaɓa.';

  @override
  String get languageVoiceTip =>
      'Za ka iya cewa “change language to Hausa” bayan ka danna Faɗi umarni a shafin farko.';

  @override
  String useLanguage(String language) {
    return 'Yi amfani da $language';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'Siga $version (gini $build)';
  }

  @override
  String get settingsVersionNote =>
      'Gaya wa ƙungiyar Magana wannan siga idan kana bayar da rahoton matsala.';

  @override
  String get reportProblem => 'Bayar da rahoton matsala';

  @override
  String get reportHow =>
      'Gaya wa ƙungiyar Magana abubuwa uku: sunan shafin, abin da ka yi, da abin da Magana ta ce.';

  @override
  String get speakCommand => 'Faɗi umarni';

  @override
  String get listeningCommand => 'Ina saurare… Taɓa don tsayawa';

  @override
  String commandNotUnderstood(String heard) {
    return 'Na ji “$heard”, amma ban san wannan umarnin ba. Ka ce help don jin abin da za ka iya faɗi.';
  }

  @override
  String get commandNothingHeard =>
      'Ban ji umarni ba. Sake gwadawa, ko ka ce help.';

  @override
  String commandHelp(String commands) {
    return 'Za ka iya cewa: $commands. Faɗi umarni da Turanci a yanzu.';
  }

  @override
  String get changeLanguageCommand => 'change language';

  @override
  String get voiceCommandsUnavailable =>
      'Ba a iya amfani da umarnin murya a wannan wayar ba. Yi amfani da maɓallai maimakon haka.';

  @override
  String get explainTitle => 'Bayani';

  @override
  String explainFrom(String source) {
    return 'Daga: $source';
  }

  @override
  String get explainPreviewBanner =>
      'Gwaji. N-ATLAS, wanda zai yi bayanin shafuka a harshenka, ba a haɗa shi ba tukuna. A yanzu Magana tana karanta rubutun shafin daidai yadda aka buga.';

  @override
  String answerLanguage(String language) {
    return 'Harshen amsa, yanzu $language';
  }

  @override
  String get youSaid => 'Ka ce';

  @override
  String basedOnPage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bisa: layuka $count na shafinka',
      one: 'Bisa: layi 1 na shafinka',
    );
    return '$_temp0';
  }

  @override
  String get readExactlyNote =>
      'Ana karanta lambobi da kalmomi daga shafin daidai yadda aka buga.';

  @override
  String get saySimpler => 'Faɗa a sauƙaƙe';

  @override
  String get giveExample => 'Ba da misali';

  @override
  String get explainDisclaimer =>
      'Magana na iya yin kuskure. Duba muhimman amsoshi tare da malaminka.';

  @override
  String get askAQuestion => 'Yi tambaya';

  @override
  String get explainNoPage =>
      'Bayani game da shafi ne. Karanta shafi da farko, sannan ka zaɓi Yi bayanin wannan.';

  @override
  String get explainThis => 'Yi bayanin wannan';

  @override
  String get explainQuestionPreview =>
      'Idan an haɗa N-ATLAS, Magana za ta amsa tambayarka daga wannan shafin. A yanzu, ga shafin.';

  @override
  String get msg_explain_preview =>
      'Wannan gwaji ne. Bayani a harshenka zai zo idan an haɗa N-ATLAS. Ga shafin, an karanta shi daidai yadda aka buga.';

  @override
  String get msg_explained => 'Ga bayanin.';

  @override
  String get msg_explain_bad_source =>
      'Babu rubutun shafi da za a yi bayani. Don Allah ka karanta shafi da farko.';

  @override
  String get jumpWithinPage => 'Tsallaka cikin shafi';

  @override
  String get jumpStart => 'Farkon shafin';

  @override
  String jumpTable(int number) {
    return 'Tebur $number';
  }

  @override
  String get jumpWarnings => 'Abu na gaba da ban tabbata ba';

  @override
  String get jumpNotYet => 'Ba a iya tsallaka zuwa zane-zane ba tukuna.';

  @override
  String get paperLetter => 'Wasiƙu da fom';

  @override
  String get paperLetterDetail => 'Sanarwa, fom, rubuce-rubucen addini';

  @override
  String get noteLetter =>
      'Magana tana karanta abin da aka buga. Ba ta ba da shawarar shari\'a ko ta kuɗi, kuma ba ta taɓa neman PIN ko kalmar sirrinka ba.';

  @override
  String get readAnyPaper => 'Karanta kowace takarda';

  @override
  String get readAnyPaperDetail => 'Magana za ta gane irin takardar';

  @override
  String detectedPaper(String paper) {
    return 'Irin takarda: $paper.';
  }

  @override
  String weekReadLetter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An karanta wasiƙu ko fom $count',
      one: 'An karanta wasiƙa ko fom 1',
    );
    return '$_temp0';
  }

  @override
  String get readAgain => 'Sake karantawa';

  @override
  String get askAboutResult => 'Me wannan yake nufi?';

  @override
  String get resultAnswer =>
      'Ma\'aikacin lafiyarka ne kaɗai zai iya bayyana abin da wannan sakamakon yake nufi a gare ka. Zan iya adana tambayarka don ziyararka ta gaba, ko in roƙi ma\'aikaciyar jinya ta kira ka.';

  @override
  String youAsked(String question) {
    return 'Ka tambaya: “$question”';
  }

  @override
  String get saveQuestion => 'Adana tambaya';

  @override
  String get questionSaved =>
      'An adana. Za ka same shi a Yi magana da ma\'aikacin lafiya.';

  @override
  String get askANurse => 'Tambayi ma\'aikaciyar jinya';

  @override
  String get savedQuestionsTitle => 'Tambayoyi don ziyararka ta gaba';

  @override
  String removeQuestion(String question) {
    return 'Cire: $question';
  }

  @override
  String questionAbout(String question, String where) {
    return '$question (game da $where)';
  }

  @override
  String get fromTheStatement => 'Daga bayanin banki, daidai yadda aka buga';

  @override
  String get findTransaction => 'Nemo ma\'amala';

  @override
  String get findPrompt =>
      'Faɗi ko rubuta kalma, kwanan wata ko adadin kuɗi daga ma\'amalar.';

  @override
  String get findField => 'Kalma, kwanan wata ko adadi';

  @override
  String get findSearch => 'Nemo';

  @override
  String get findSpeak => 'Faɗa maimakon haka';

  @override
  String findNoMatch(String query) {
    return 'Babu layin da ke da “$query”.';
  }

  @override
  String get sayYesOrNo => 'Faɗi i, a\'a, ko ban sani ba';

  @override
  String voiceAnswerUnclear(String heard) {
    return 'Na ji “$heard”. Don Allah ka ce i, a\'a, ko ban sani ba.';
  }

  @override
  String scoreUpSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'makonni $weeks da suka wuce',
      one: 'mako 1 da ya wuce',
    );
    return 'Ya tashi daga $start lokacin da ka fara, $_temp0';
  }

  @override
  String scoreSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'makonni $weeks da suka wuce',
      one: 'mako 1 da ya wuce',
    );
    return '$start lokacin da ka fara, $_temp0';
  }

  @override
  String get shareScore => 'Raba makina da malamina';

  @override
  String get shareScoreNote =>
      'Malaminka zai ga makinka, ba shafukanka ko tambayoyinka ba, da zarar an haɗa ajinku da shafin malamai na Magana.';

  @override
  String get sayNameWhenLocked => 'Faɗi sunan magani idan waya a kulle take';

  @override
  String get sayNameNote =>
      'A kashe: allon kulle zai ce “Tunatarwar Magana” kawai. A kunne: allon kulle zai nuna maganin da yawansa, kuma Magana za ta faɗa da ƙarfi a kowane lokaci, don haka mutanen da ke kusa da kai za su iya gani ko ji.';

  @override
  String get reminderGenericTitle => 'Tunatarwar Magana';

  @override
  String get reminderGenericBody => 'Buɗe Magana don jin wane magani.';

  @override
  String get msg_bad_api_key =>
      'Wannan kwafin Magana ba zai iya kaiwa ga sabis ɗin karatu ba. Don Allah ka sabunta manhajar.';

  @override
  String get msg_explain_unavailable =>
      'Ba a samun bayani a yanzu. Ga shafin, an karanta shi daidai yadda aka buga.';

  @override
  String get msg_asr_unavailable =>
      'Ba a saita gane murya a sabar ba; ana amfani da na wayar.';

  @override
  String get msg_audio_too_long =>
      'Rikodin ya yi tsawo sosai. Don Allah ka faɗi gajeriyar amsa.';

  @override
  String get msg_unreadable_audio =>
      'Ban ji wannan rikodin ba. Don Allah ka sake gwadawa.';

  @override
  String get aboutTitle => 'Game da Magana';

  @override
  String get aboutModels => 'Samfuran harshe';

  @override
  String get aboutModelsNote =>
      'Magana tana amfani da waɗannan samfuran buɗe ido ƙarƙashin Sharuɗɗan Amfani na N-ATLaS, siga 1.0. An kawo layukan yabo da ke ƙasa kamar yadda sharuɗɗan suka buƙata.';

  @override
  String get aboutExplain => 'Bayani a harshenka';

  @override
  String get aboutSpeech => 'Gane murya';

  @override
  String get openSourceLicences => 'Lasisin buɗaɗɗen tushe';

  @override
  String aboutContact(String email) {
    return 'Tambayoyi ko matsaloli: aika imel zuwa $email';
  }

  @override
  String get msg_explain_not_available =>
      'Bayani bai samu ba tukuna. Ga shafin, an karanta shi daidai yadda aka buga.';

  @override
  String quizConfirm(String answer) {
    return 'Ka ce $answer. Haka ne?';
  }

  @override
  String quizConfirmYes(String answer) {
    return 'I, $answer';
  }

  @override
  String get quizConfirmNo => 'A\'a, sake tambayata';

  @override
  String get quizSayYesOrNo => 'Faɗi i ko a\'a';

  @override
  String get quizSayAgain => 'Don Allah ka sake faɗin amsarka.';

  @override
  String get quizTapInstead =>
      'Ina da wahalar jin ka. Don Allah ka taɓa amsarka sau biyu maimakon haka.';

  @override
  String get quizSayTrueFalse => 'Faɗi gaskiya ko ƙarya';

  @override
  String get msg_too_many_requests =>
      'Magana tana da aiki sosai yanzu. Don Allah ka jira minti ɗaya ka sake gwadawa.';

  @override
  String get remindersNeedApp =>
      'Tunatarwa na buƙatar manhajar Android ko iPhone. A cikin burauza Magana ba za ta iya yin ƙara a daidai lokaci ba.';

  @override
  String get quizVoiceUnavailable =>
      'Har yanzu ba a iya amsa da murya a wannan na\'urar ba. Taɓa amsa maimakon haka.';

  @override
  String quizVoiceUnavailableWeb(String letters) {
    return 'Har yanzu ba a iya amsa da murya a wannan na\'urar ba. Taɓa ko danna amsa, ko ka danna $letters a kan madannai.';
  }

  @override
  String quizKeysHint(String letters) {
    return 'Taɓa ko danna amsa, ko ka danna $letters a kan madannai.';
  }

  @override
  String get quizKeysHintTrueFalse =>
      'Taɓa ko danna gaskiya ko ƙarya, ko ka danna A don gaskiya ko B don ƙarya.';

  @override
  String get quizTapAnswer => 'Taɓa amsa.';

  @override
  String get startMagana => 'Fara Magana';

  @override
  String get classTitle => 'A wane aji kake?';

  @override
  String get classBody =>
      'Magana za ta zaɓi tambayoyin gwaji na ajinka. Malami zai iya canza shi daga baya.';

  @override
  String get classNotInSchool => 'Ba na makaranta';

  @override
  String get classGroupPrimary => 'Makarantar firamare';

  @override
  String get classGroupJss => 'Ƙaramar sakandare';

  @override
  String get classGroupSss => 'Babbar sakandare';

  @override
  String get classroomChooseClass => 'Malami: zaɓi ajin wannan zaman';

  @override
  String get classroomNeedsClass => 'Zaɓi ajin tukuna.';

  @override
  String get settingsClass => 'Ajina';

  @override
  String get settingsChangeClass => 'Canza aji (malami)';

  @override
  String quizYourClass(String name) {
    return 'Ajinka: $name';
  }

  @override
  String get quizFromTeacher => 'Daga malaminka';

  @override
  String get quizSamples => 'Tambayoyin misali';

  @override
  String quizCount(int n) {
    return 'Tambayoyi $n';
  }

  @override
  String get quizChooseClassHint =>
      'Zaɓi ajinka don samun tambayoyinsa. Malami zai iya saita shi a Saituna.';

  @override
  String get quizSampleNote =>
      'Tambayoyin misali da ƙungiyar Magana ta rubuta. Ba tsofaffin tambayoyi ba ne, kuma malami zai duba su. Tambayoyin da Turanci suke.';

  @override
  String get quizTeacherNote => 'Malaminka ne ya yi shi.';

  @override
  String quizSubjectTitle(String subject) {
    return 'Gwajin $subject';
  }

  @override
  String quizCorrectPrimary(String letter) {
    return 'Madalla! Ka zaɓi $letter.';
  }

  @override
  String quizWrongPrimary(String answer) {
    return 'Ka yi ƙoƙari! Amsar ita ce $answer.';
  }

  @override
  String quizPicture(String description) {
    return 'Hoto: $description';
  }

  @override
  String get quizOr => 'ko';

  @override
  String get quizSessionOpen => 'Malami: buɗe zaman ajinka';

  @override
  String get quizSessionPrompt =>
      'Malami ne kaɗai ya kamata ya buɗe zaman aji. Rubuta lambar zaman daga shafin malamai.';

  @override
  String get quizSessionCodeLabel => 'Lambar zama';

  @override
  String get quizSessionStart => 'Buɗe zama';

  @override
  String quizSessionActive(String code) {
    return 'Zaman aji $code';
  }

  @override
  String get quizSessionEnd => 'Rufe zaman aji';

  @override
  String get quizSessionEmpty =>
      'Babu jarabawa daga malaminka a wannan zaman tukuna.';

  @override
  String get msg_session_code_invalid =>
      'Wannan lambar zaman ba daidai ba ce. Duba ta a shafin malamai.';

  @override
  String get msg_paper_lines =>
      'Ba a bayyana takardun lafiya da na kuɗi da AI. Ana karanta kowane layi daidai yadda yake, da harshenka kawai inda aka tabbatar da fassara.';

  @override
  String get msg_cant_translate_line_health =>
      'Ba zan iya fassara wannan layin lafiya ba. Don Allah ka tambayi mai harhaɗa magani.';

  @override
  String get msg_cant_translate_line_money =>
      'Ba zan iya fassara wannan layin lafiya ba. Don Allah ka tambayi wani a bankinka.';

  @override
  String get msg_numbers_left_out =>
      'Ainihin lambobin suna kan shafin. Faɗi ‘read again’ don jin su.';

  @override
  String get explainReadAgain => 'Sake karanta shafin';

  @override
  String get quizNotSure =>
      'Ban tabbatar da abin da ka faɗa ba. Don Allah ka sake faɗar amsarka.';

  @override
  String quizVoiceNotReady(String language) {
    return 'Amsa da murya a $language ba ta da inganci sosai tukuna. Taɓa amsa maimakon haka.';
  }

  @override
  String quizVoiceNotReadyWeb(String language, String letters) {
    return 'Amsa da murya a $language ba ta da inganci sosai tukuna. Taɓa ko danna amsa, ko ka danna $letters a kan madannai.';
  }

  @override
  String get quizVoicePrimaryOff =>
      'A azuzuwan firamare, taɓa amsarka. Amsa da murya za ta zo daga baya.';

  @override
  String quizVoicePrimaryOffWeb(String letters) {
    return 'A azuzuwan firamare, taɓa ko danna amsarka, ko ka danna $letters a kan madannai.';
  }

  @override
  String get whoTitle => 'Wane ne ke amfani da Magana?';

  @override
  String get whoBody =>
      'Wannan yana taimaka wa Magana zaɓar darussa da tambayoyi da suka dace da kai.';

  @override
  String get whoInSchool => 'Ina makaranta';

  @override
  String get whoInSchoolDetail =>
      'Firamare ko sakandare. Za ka shiga ajinka da lamba daga malaminka.';

  @override
  String get whoFinished => 'Na gama makaranta';

  @override
  String get whoFinishedDetail =>
      'Ka yi shiri don JAMB ko WAEC, ka inganta karatunka, ko ka koyi sababbin ƙwarewa.';

  @override
  String get whoOther => 'Jami\'a ko wani abu';

  @override
  String get whoOtherDetail =>
      'Karanta littattafanka, bayananka da takardunka. Ba a buƙatar aji.';

  @override
  String get joinTitle => 'Shiga ajinka';

  @override
  String get joinBody => 'Roƙi malaminka lambar aji mai lambobi 6.';

  @override
  String get classCodeLabel => 'Lambar aji';

  @override
  String get teacherCodeLabel => 'Lambar malami';

  @override
  String codeGroup(String label, String typed, int count) {
    return '$label: $typed, lambobi $count cikin 6';
  }

  @override
  String get codeEmpty => 'Babu lamba tukuna. Rubuta lambobi 6.';

  @override
  String codeProgress(String typed, int left) {
    return 'Ka rubuta $typed. Saura $left.';
  }

  @override
  String codeComplete(String typed) {
    return 'Duk lambobi 6: $typed.';
  }

  @override
  String get codeNeedsSix => 'Rubuta duk lambobi 6 da farko.';

  @override
  String get keypadDelete => 'Goge';

  @override
  String get keypadReadBack => 'Karanta mini';

  @override
  String get joinUnder18Note =>
      'Ƙasa da 18? Malaminka zai roƙi iyaye ko mai kula ya amince kafin a haɗa ajinka. Kafin nan har yanzu kana iya karanta shafuka.';

  @override
  String get joinButton => 'Shiga aji';

  @override
  String get joinNoCode => 'Ba ni da lamba tukuna';

  @override
  String get joinedTitle => 'Ka shiga!';

  @override
  String joinedTeacher(String name) {
    return 'Malami: $name';
  }

  @override
  String get joinedRightClass =>
      'Wannan ajin daidai ne? Idan ba haka ba, faɗa wa malaminka. Malaminka ne kawai zai iya mayar da kai wani aji.';

  @override
  String get joinedWaiting =>
      'Ana jiran iyayenka ko mai kula da kai su amince. Malaminka zai tambaye su.';

  @override
  String get startReading => 'Fara karatu';

  @override
  String get changeClassTitle => 'Canza aji';

  @override
  String get changeClassNow => 'Ajinka yanzu';

  @override
  String get teacherCodeNeededTitle => 'Malaminka ne zai yi wannan';

  @override
  String get teacherCodeBody =>
      'Roƙi malaminka ya shigar da lambar malami. Tana kan shafin malamin Magana.';

  @override
  String get newClassCodeTitle => 'Yanzu lambar sabon ajin';

  @override
  String get confirmLabel => 'Tabbatar';

  @override
  String get teacherCodeLockNote =>
      'Lamba mara kyau sau 3? Magana tana jira minti 5 kafin ka sake gwadawa.';

  @override
  String get goalsTitle => 'Me kake so ka yi?';

  @override
  String get goalsBody => 'Zaɓi duk wanda kake so.';

  @override
  String get goalJamb => 'Shirya don JAMB';

  @override
  String get goalJambDetail =>
      'Atisaye irin na tsofaffin tambayoyi: Turanci, Lissafi da sauransu';

  @override
  String get goalWaec => 'Shirya don sake WAEC ko NECO';

  @override
  String get goalWaecDetail => 'Atisaye bisa darasi, a matakin SS3';

  @override
  String get goalReading => 'Yi atisayen karatu';

  @override
  String get goalReadingDetail =>
      'Gajerun rubutu da labarai, ana karanta su tare da kai';

  @override
  String get goalSkills => 'Koyi sababbin ƙwarewa';

  @override
  String get goalSkillsDetail => 'Ƙwarewar waya, zirga-zirga, tushen kuɗi';

  @override
  String get goalPapers => 'Karanta takarduna kawai';

  @override
  String get goalPapersDetail => 'Wasiƙu, takardun biyan kuɗi, alamomin magani';

  @override
  String get goalsNote =>
      'Kana iya canza su kowane lokaci a Saituna. Ba a buƙatar malami.';

  @override
  String get saveLabel => 'Ajiye';

  @override
  String get waitingBanner =>
      'Ana jiran iyayenka ko mai kula da kai su amince. Kafin nan kana iya karanta shafuka.';

  @override
  String get removedNotice =>
      'Malaminka ya cire wannan wayar daga ajin. Har yanzu kana iya karanta shafuka.';

  @override
  String get settingsGoals => 'Burina';

  @override
  String get settingsNoClass => 'Ba a cikin aji';

  @override
  String get practiceLevelTitle => 'Matakin atisayena';

  @override
  String get msg_unreadable_pdf =>
      'Ban iya buɗe wannan PDF ɗin ba. Don Allah gwada wani fayil.';

  @override
  String get msg_pdf_password_needed =>
      'An kulle wannan PDF ɗin. Rubuta kalmar sirrinsa: sau da yawa tana cikin imel ɗin da ya zo da shi.';

  @override
  String get msg_pdf_password_wrong =>
      'Wannan kalmar sirri ba ta buɗe PDF ɗin ba. Don Allah duba ka sake gwadawa.';

  @override
  String get msg_pdf_too_long =>
      'Wannan PDF ɗin ya yi tsawo. Zan iya karanta shafi 20 a lokaci ɗaya.';

  @override
  String get readPdf => 'Karanta PDF';

  @override
  String get readPdfDetail =>
      'Bayanin banki, sakamako ko wasiƙa da aka aiko zuwa wayarka';

  @override
  String get pdfTitle => 'Karanta PDF';

  @override
  String get pdfBody =>
      'Zaɓi PDF a wayarka. Hakanan za ka iya buɗe shi daga WhatsApp, Gmail ko Files da “Buɗe da Magana” ko Raba.';

  @override
  String get pdfChoose => 'Zaɓi PDF';

  @override
  String get pdfReading =>
      'Ana karanta PDF ɗin. Dogayen bayanai suna ɗaukar ɗan lokaci.';

  @override
  String get pdfPasswordTitle => 'An kulle wannan PDF ɗin';

  @override
  String get pdfPasswordBody =>
      'Rubuta kalmar sirrinsa. Bankuna sukan aiko ta a cikin imel ɗin, ko kuma wani ɓangare ne na lambar wayarka ko ranar haihuwarka.';

  @override
  String get pdfPasswordLabel => 'Kalmar sirrin PDF';

  @override
  String get pdfPasswordNote =>
      'Magana tana amfani da wannan kalmar sirri don buɗe wannan fayil kawai, sannan ta manta da ita. Ba a ajiye ta ba. Magana ba ta taɓa tambayar PIN ɗin bankinka ko kalmar sirrin manhaja ba.';

  @override
  String get pdfOpen => 'Buɗe PDF ɗin';

  @override
  String get pdfPasswordEmpty => 'Rubuta kalmar sirri tukuna.';

  @override
  String get pdfPasswordReadBack => 'Karanta abin da na rubuta';

  @override
  String pdfPasswordSays(String spelled) {
    return 'Ka rubuta: $spelled';
  }

  @override
  String get pdfNotChosen => 'Ba a zaɓi PDF ba.';

  @override
  String pageOf(int page, int count) {
    return 'Shafi $page cikin $count';
  }

  @override
  String pdfShared(String name) {
    return 'An raba PDF da Magana: $name';
  }

  @override
  String msg_line_part_unclear(String where) {
    return 'Ba a karanta wani ɓangare na $where ba: akwai rubutu da ban iya gane shi ba. Don Allah duba shi ko ka sake ɗaukar hoto.';
  }

  @override
  String get msg_small_print =>
      'Rubutun ƙanana ne sosai ko ba ya fitowa sosai a wannan hoton, don haka zan iya tsallake wani ɓangare. Matsar da wayar kusa, ko ka buɗe PDF ɗin kansa idan kana da shi.';

  @override
  String get msg_handwritten_page =>
      'Wannan shafin kamar rubutun hannu ne. Rubutun hannu yana mini wahala, don haka zan iya kuskure a kalmomi. Ana karanta lambobi ne kawai idan na tabbata.';

  @override
  String get msg_mixed_page =>
      'Wani ɓangare na wannan shafin kamar rubutun hannu ne. Zan iya kuskure a waɗannan wuraren. Ana karanta lambobin can ne kawai idan na tabbata.';

  @override
  String get msg_handwritten_prescription =>
      'Wannan kamar rubutun hannu ne a takardar lafiya. Ba zan karanta magunguna ko adadin da aka rubuta da hannu ba. Don Allah ka roƙi mai harhaɗa magunguna ko nas su karanta maka.';

  @override
  String msg_handwritten_number(String where) {
    return 'A $where, lambar rubutun hannu. Ba zan yi hasashe ba: don Allah ka tambayi mai harhaɗa magunguna ko nas.';
  }

  @override
  String get msg_money_amounts_unreliable =>
      'Ban iya karanta adadin kuɗin da ke wannan shafin da tabbaci ba. Don Allah buɗe PDF daga manhajar bankinka ko imel, ko ka roƙi wanda ka amince da shi.';

  @override
  String get msg_reading_incomplete =>
      'Wannan karatun bai cika ba. Zan karanta sassan da na iya tantancewa kawai.';

  @override
  String columnsNote(int count) {
    return 'Ginshiƙai $count. Na hagu da farko, sannan na dama.';
  }

  @override
  String columnsSubtitle(int count) {
    return 'Ginshiƙai $count · hagu, sannan dama';
  }

  @override
  String columnPosition(int column, int columns, int number, int total) {
    return 'Ginshiƙi $column cikin $columns · Layi $number cikin $total';
  }

  @override
  String columnStart(int column, int columns) {
    return 'Ginshiƙi $column cikin $columns';
  }

  @override
  String columnLabel(int column) {
    return 'Ginshiƙi $column';
  }

  @override
  String headingSpoken(String text) {
    return 'Kanun labari: $text';
  }

  @override
  String get headingLabel => 'Kanun labari';

  @override
  String get nextColumn => 'Ginshiƙi na gaba';

  @override
  String get lastColumn => 'Wannan shi ne ginshiƙi na ƙarshe.';

  @override
  String get jumpHeadings => 'Kanun labarai';

  @override
  String get jumpColumns => 'Ginshiƙai';

  @override
  String get jumpTables => 'Teburori';

  @override
  String get noHeadings => 'Ban sami kanun labarai a wannan shafin ba.';

  @override
  String get noColumns => 'Wannan shafin ginshiƙi ɗaya ne.';

  @override
  String get noTables => 'Babu tebur a wannan shafin.';

  @override
  String get mapNow => 'yanzu';

  @override
  String get mapNext => 'na gaba';

  @override
  String letterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kalmomi $count na iya zama ba daidai ba.',
      one: 'Kalma 1 na iya zama ba daidai ba.',
    );
    return '$_temp0';
  }

  @override
  String letterCheckWords(String words) {
    return 'Waɗannan kalmomin na iya rasa wani harafi na musamman: $words.';
  }

  @override
  String get spellWord => 'Faɗi haruffa';

  @override
  String get spellNone => 'Babu kalmar da aka yi wa alama a wannan layin.';

  @override
  String get askSomeone => 'Tambayi wani';

  @override
  String askSomeoneText(String language) {
    return 'Tambayi wanda ke karanta $language ya duba kalmomin da aka yi wa alama.';
  }

  @override
  String languagePage(String language) {
    return 'Shafin $language';
  }

  @override
  String get msg_letters_ha =>
      'Shafin Hausa. Zan iya rasa haruffa kamar ƙ, ɗ da ɓ. Kalmomin da aka yi wa alama na iya ƙunsar ɗaya daga cikinsu. Faɗi haruffan kalma ko ka duba da wani.';

  @override
  String get msg_letters_yo =>
      'Shafin Yarbanci. Zan iya rasa haruffa kamar ẹ, ọ da ṣ, da alamomin sauti. Kalmomin da aka yi wa alama na iya ƙunsar ɗaya daga cikinsu. Faɗi haruffan kalma ko ka duba da wani.';

  @override
  String get msg_letters_ig =>
      'Shafin Igbo. Zan iya rasa haruffa kamar ị, ọ da ụ. Kalmomin da aka yi wa alama na iya ƙunsar ɗaya daga cikinsu. Faɗi haruffan kalma ko ka duba da wani.';

  @override
  String get msg_cut_off_top => 'Wani ɓangare na shafin ya yanke a sama.';

  @override
  String get msg_cut_off_bottom => 'Wani ɓangare na shafin ya yanke a ƙasa.';

  @override
  String get msg_cut_off_left => 'Wani ɓangare na shafin ya yanke a hagu.';

  @override
  String get msg_cut_off_right => 'Wani ɓangare na shafin ya yanke a dama.';

  @override
  String get offlineBanner => 'Babu intanet. Ana karantawa a wannan wayar.';

  @override
  String get offlineBannerSlow =>
      'Sabar Magana ba ta amsawa. Ana karantawa a wannan wayar.';

  @override
  String get offlineNote =>
      'Karatu na asali kawai. Teburori, ginshiƙai da Bayani suna buƙatar intanet.';

  @override
  String get offlineQueued =>
      'Zan ajiye wannan shafin in yi cikakken karatu idan intanet ta dawo.';

  @override
  String get fullReadingWhenOnline => 'Cikakken karatu idan akwai intanet';

  @override
  String queueDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'An cire tsofaffin shafuka $count da ke jira: shafuka 20 ne kawai ke iya jira.',
      one: 'An cire tsohon shafin da ke jira: shafuka 20 ne kawai ke iya jira.',
    );
    return '$_temp0';
  }

  @override
  String fullReadingsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cikakkun karatu $count sun shirya a Ɗakin karatuna.',
      one: 'Cikakken karatu ya shirya a Ɗakin karatuna.',
    );
    return '$_temp0';
  }

  @override
  String get cueTiltToward => 'Karkata saman wayar zuwa gare ka';

  @override
  String get cueTiltAway => 'Karkata saman wayar daga gare ka';

  @override
  String get cueBlurry => 'Ba a gani sosai. Riƙe a tsaye';

  @override
  String get readerCommandHelp =>
      'Za ka iya cewa: next, back, repeat, pause, read, next column, headings ko spell. Faɗi umarni da Turanci a yanzu.';

  @override
  String msg_explain_language_coming(String language) {
    return 'Bayani da $language yana zuwa. Kuna iya jin sa da Turanci.';
  }

  @override
  String get explainInEnglish => 'Ji shi da Turanci';

  @override
  String get msg_progress_shared => 'An aika jimillar ka zuwa ga malaminka.';

  @override
  String get helpCheckPage => 'Shin ka karanta wannan shafi da kanka?';

  @override
  String get helpCheckPdf => 'Shin ka karanta wannan PDF da kanka?';

  @override
  String get helpCheckQuiz => 'Shin ka yi wannan gwaji da kanka?';

  @override
  String get helpCheckHow => 'Faɗi “eh”, “taimako” ko “tsallake”, ko ka taɓa.';

  @override
  String get helpOwn => 'Eh, da kaina';

  @override
  String get helpOwnDetail => 'Ba tare da taimakon mai gani ba';

  @override
  String get helpSome => 'Na ɗan buƙaci taimako';

  @override
  String get helpSomeDetail => 'Wani ya taimaka da wani ɓangare';

  @override
  String get helpSkip => 'Tsallake';

  @override
  String get helpSkipDetail => 'Kada a tambaya yau';

  @override
  String get helpCheckNoteClass =>
      'Ana tambaya sau ɗaya a rana kawai. Malaminka yana ganin jimilla kawai, ba abin da ka karanta ba.';

  @override
  String get helpCheckNotePhone =>
      'Ana tambaya sau ɗaya a rana kawai. Amsoshinka suna zama a wannan waya.';

  @override
  String get helpCheckNotHeard =>
      'Don Allah faɗi eh, taimako ko tsallake, ko ka taɓa amsarka.';

  @override
  String get helpCheckThanks => 'Na gode.';
}
