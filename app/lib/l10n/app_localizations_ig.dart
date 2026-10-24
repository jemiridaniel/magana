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
      'Nke a nwere ike ịdị njọ. Biko gaa n\'ụlọ ọgwụ kacha nso ugbu a, ma ọ bụ kpọọ 112. Echerela ka a kpọọ gị.';

  @override
  String get msg_nurse_call_within_2_hours =>
      'Daalụ. Otu nọọsụ ga-akpọ gị n\'ime awa 2.';

  @override
  String get msg_nurse_call_working_hours =>
      'Daalụ. Otu nọọsụ ga-akpọghachi gị n\'oge ọrụ.';

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
  String get msg_q_fever => 'Ị nwere ahụ ọkụ, ka ahụ gị na-ekpo ọkụ nke ukwuu?';

  @override
  String get msg_q_fever_days => 'Ụbọchị ole ka ahụ ọkụ ahụ jịdere gị?';

  @override
  String get msg_q_fits =>
      'Ị nwere akwụkwụ, ma ọ bụ ahụ ịma jijiji ị na-enweghị ike ịkwụsị?';

  @override
  String get msg_q_cannot_drink =>
      'Ị nweghị ike ịṅụ ihe ọ bụla, ka nwa ọhụrụ enweghị ike ịṅụ ara?';

  @override
  String get msg_q_vomits_everything =>
      'Ị na-agbọpụta ihe niile i riri ma ọ bụ ṅụọ?';

  @override
  String get msg_q_very_sleepy =>
      'Ụra ọ na-atụ gị nke ukwuu, uche gị ọ gbagwojuru anya, ka ọ na-esiri ike ịkpọte gị?';

  @override
  String get msg_q_bleeding =>
      'Ọbara ọ na-esi gị n\'enweghị ihe kpatara ya, site n\'imi ma ọ bụ ọnụ eze, ma ọ bụ n\'agbọ ma ọ bụ nsị?';

  @override
  String get msg_q_yellow_eyes =>
      'Anya gị ma ọ bụ akpụkpọ ahụ gị ọ ghọrọ odo odo?';

  @override
  String get msg_q_hard_breathing =>
      'Ị na-eku ume ọsọ ọsọ nke ukwuu, ka ọ na-esiri gị ike iku ume?';

  @override
  String get msg_q_very_pale =>
      'Ọbụ aka gị, egbugbere ọnụ gị ma ọ bụ ime akpụkpọ anya gị ọ chachara nke ukwuu?';

  @override
  String get msg_q_dark_urine =>
      'Mamịrị gị ọ gbara oji nke ukwuu, dịka kola ma ọ bụ tii?';

  @override
  String get msg_q_too_weak =>
      'Ahụ ọ gwụrụ gị nke na ị nweghị ike ịnọdụ ala ma ọ bụ iguzo n\'enweghị enyemaka?';

  @override
  String msg_line_end_unclear(String where) {
    return 'Enweghị m ike ịgụ njedebe $where. Biko lelee ya ma ọ bụ see foto ọzọ.';
  }

  @override
  String get cueHigher => 'Elu';

  @override
  String get cueLower => 'Ala';

  @override
  String get cueLeft => 'Aka ekpe';

  @override
  String get cueRight => 'Aka nri';

  @override
  String get cueHoldStill => 'Kwụsị ọtọ';

  @override
  String get cueCloser => 'Bịaruo nso';

  @override
  String get cueFurther => 'Pụọ azụ';

  @override
  String get cueMoreLight => 'Ìhè karịa';

  @override
  String get cueNoPage => 'Enweghị peeji';

  @override
  String stepOf(int n, int total) {
    return 'Nzọụkwụ $n n\'ime $total';
  }

  @override
  String get chooseLanguageTitle => 'Họrọ asụsụ gị';

  @override
  String get chooseLanguageBody =>
      'Magana ga-agwa gị okwu n\'asụsụ a. Ị nwere ike ịgbanwe ya oge ọ bụla site na ihuenyo mbụ.';

  @override
  String get languageHearsHint =>
      'A ga-agụ nhọrọ ọ bụla n\'asụsụ nke ya mgbe i metụrụ ya aka.';

  @override
  String get continueLabel => 'Gaa n\'ihu';

  @override
  String get welcome => 'Nnọọ';

  @override
  String get ageTitle => 'Afọ ole ka ị dị?';

  @override
  String get ageBody => 'Anyị na-ajụ ka Magana wee dị nchebe ma kwekọọ gị.';

  @override
  String get ageAdult => 'Adị m afọ 18 ma ọ bụ karịa';

  @override
  String get ageAdultDetail =>
      'Jiri ihe niile dị na Magana, gụnyere akwụkwọ ahụike na nke ego.';

  @override
  String get ageTeen => 'Adị m afọ 13 ruo 17';

  @override
  String get ageTeenDetail =>
      'Nne na nna, onye na-elekọta gị ma ọ bụ onye nkuzi ga-ebu ụzọ kwenye. Magana na-enyere naanị n\'ihe ọmụmụ ụlọ akwụkwọ.';

  @override
  String get ageChild => 'Erubeghị m afọ 13';

  @override
  String get ageChildDetail =>
      'Onye nkuzi gị ga-eji Magana na gị n\'ime klaasị.';

  @override
  String get privacyNote =>
      'A na-ehichapụ foto peeji gị mgbe a gụchara ha. Anyị anaghị ekesa nkọwa gị.';

  @override
  String get hearAgain => 'Nụghachi peeji a';

  @override
  String get readyTitle => 'Ị dị njikere';

  @override
  String get readyBody =>
      'Jide ekwentị gị n\'elu peeji e biri ebi, Magana ga-agụrụ gị ya.';

  @override
  String get startLabel => 'Malite';

  @override
  String get consentTitle =>
      'Jụọ nne na nna, onye na-elekọta gị ma ọ bụ onye nkuzi';

  @override
  String get consentBody => 'Biko gụọ ma ọ bụ gee nke a ọnụ.';

  @override
  String get consentPoint1 =>
      'Magana na-enyere naanị n\'ihe ọmụmụ ụlọ akwụkwọ.';

  @override
  String get consentPoint2 =>
      'Enweghị akwụkwọ ahụike ma ọ bụ nke ego, enweghị WhatsApp, enweghị mkparịta ụka efu.';

  @override
  String get consentPoint3 => 'A na-ehichapụ foto mgbe a gụchara ha.';

  @override
  String get consentConfirm =>
      'Abụ m nne ma ọ bụ nna, onye na-elekọta ma ọ bụ onye nkuzi, ekwenyere m';

  @override
  String get classroomTitle => 'Magana n\'ime klaasị';

  @override
  String get classroomBody =>
      'Onye nkuzi gị ga-amalite Magana na gị n\'ime klaasị. Mgbe nkuzi gwụchara, mechie ngwa ahụ.';

  @override
  String get classroomStart => 'Onye nkuzi: malite oge klaasị';

  @override
  String get classroomConfirmTitle => 'Ị bụ onye nkuzi?';

  @override
  String get classroomConfirmYes => 'Ee, malite oge ahụ';

  @override
  String get cancel => 'Kagbuo';

  @override
  String get back => 'Laghachi';

  @override
  String get msg_unknown_tier => 'Biko hazie Magana ọzọ: amataghị otu afọ gị.';

  @override
  String get readPageSubtitleSchool =>
      'Ihe ọmụmụ ụlọ akwụkwọ, ndetu, akwụkwọ ọgụgụ na ule';

  @override
  String get everydaySubtitle => 'Akwụkwọ ahụike na nke ego · 18+';

  @override
  String get paperMedicine => 'Akara ọgwụ';

  @override
  String get paperMedicineDetail => 'Akara na ndenye ọgwụ';

  @override
  String get paperReport => 'Akụkọ ahụike';

  @override
  String get paperReportDetail => 'Nsonaazụ ule na akwụkwọ ntọhapụ';

  @override
  String get paperStatement => 'Nkwupụta ụlọ akụ';

  @override
  String get paperStatementDetail => 'Nkwupụta, nnata na ụgwọ';

  @override
  String get talkToNurse => 'Gwa nọọsụ okwu';

  @override
  String get talkToNurseDetail => 'Ya na nyocha ọsọ ọsọ Ibà';

  @override
  String get everydayPrivacy =>
      'A na-agụ akwụkwọ nzuzo na ekwentị gị, anaghị echekwa ha. Magana anaghị arịọ PIN ma ọ bụ okwuntughe gị.';

  @override
  String get readExactly => 'A na-agụ ya otú e biri ya';

  @override
  String get noteMedicine =>
      'Magana na-agụ ihe e biri ebi. Ọ naghị enye ndụmọdụ ahụike. Ọ bụrụ na ihe ọ bụla dị na akara edoghị anya, jụọ onye na-ere ọgwụ gị tupu ị ṅụọ ya.';

  @override
  String get noteReport =>
      'A na-agụ nọmba na oke otú e biri ha. Magana anaghị akọwa nsonaazụ: naanị onye ọrụ ahụike gị nwere ike ịkọwa ihe ha pụtara nye gị.';

  @override
  String get noteStatement =>
      'A na-agụ ego otú e biri ya. Anaghị echekwa nkwupụta a. Magana anaghị arịọ PIN ma ọ bụ okwuntughe gị. Ọ bụrụ na ego ọ bụla edoghị anya, lelee ya na ụlọ akụ gị ma ọ bụ onye ị tụkwasịrị obi.';

  @override
  String get askPharmacistOrNurse => 'Jụọ onye na-ere ọgwụ ma ọ bụ nọọsụ';

  @override
  String get adultsOnly => 'Nke a bụ maka ndị okenye (afọ 18 gaa n\'ihu).';

  @override
  String get healthWorkerTitle => 'Gwa onye ọrụ ahụike okwu';

  @override
  String get healthWorkerSubtitle =>
      'Nọọsụ ma ọ bụ onye na-ere ọgwụ ga-akpọghachi gị';

  @override
  String get helpWithTitle => 'Gịnị ka ị chọrọ enyemaka na ya?';

  @override
  String get reasonMedicine => 'Ịghọta ọgwụ m';

  @override
  String get reasonResults => 'Ịghọta nsonaazụ m';

  @override
  String get reasonOther => 'Ihe ọzọ';

  @override
  String get callLanguage => 'Asụsụ maka oku ahụ';

  @override
  String get answerIbaFirst => 'Buru ụzọ zaa ajụjụ ole na ole (Ibà)';

  @override
  String get requestCallback => 'Rịọ ka a kpọghachi gị';

  @override
  String get emergencyBold => 'Ihe mberede?';

  @override
  String get emergencyText => 'Echerela ka a kpọghachi gị. Kpọọ 112 ugbu a.';

  @override
  String get call112 => 'Kpọọ 112';

  @override
  String get quickCheckTitle => 'Nyocha ahụike ọsọ ọsọ';

  @override
  String quickCheckProgress(int n, int total) {
    return 'Ibà · ajụjụ $n n\'ime $total';
  }

  @override
  String get yes => 'Ee';

  @override
  String get no => 'Mba';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ụbọchị $count',
      one: 'ụbọchị 1',
    );
    return '$_temp0';
  }

  @override
  String get moreDays => 'Otu ụbọchị ọzọ';

  @override
  String get fewerDays => 'Otu ụbọchị belata';

  @override
  String get nextLabel => 'Na-esote';

  @override
  String get quickCheckNote =>
      'Azịza gị na-enyere nọọsụ aka ịkpebi otú ọ ga-esi kpọọ gị ọsọ ọsọ. Ibà anaghị achọpụta ọrịa. Ọ bụrụ na ị nwere ihe ịrịba ama ihe ize ndụ, Magana ga-agwa gị ka ị gaa n\'ụlọ ọgwụ ugbu a.';

  @override
  String get resultTitle => 'Nsonaazụ gị';

  @override
  String get checkingAnswers => 'Ana m enyocha azịza gị.';

  @override
  String get backHome => 'Laghachi n\'ụlọ';

  @override
  String get msg_callback_booked =>
      'E debela oku gị. Nọọsụ ma ọ bụ onye na-ere ọgwụ ga-akpọ gị.';

  @override
  String get msg_callback_unavailable =>
      'Enweghị oku nkpọghachi ugbu a. Ọ bụrụ na ịchọrọ enyemaka ugbu a, gaa n\'ụlọ ọgwụ ma ọ bụ kpọọ 112.';

  @override
  String quickCheckProgressFallback(int n, int total) {
    return 'Nyocha nchekwa dị n\'ime · ajụjụ $n n\'ime $total';
  }

  @override
  String get resultUrgent =>
      'Nọọsụ kwesịrị ịkpọ gị n\'ime awa 2. Rịọ ka a kpọghachi gị ugbu a. Ọ bụrụ na ọ ka njọ, gaa n\'ụlọ ọgwụ ma ọ bụ kpọọ 112.';

  @override
  String get resultRoutine =>
      'Nọọsụ nwere ike ịkpọghachi gị n\'oge ọrụ. Rịọ ka a kpọghachi gị. Ọ bụrụ na ọ ka njọ, gaa n\'ụlọ ọgwụ ma ọ bụ kpọọ 112.';

  @override
  String get quizTitle => 'Omume Biology';

  @override
  String quizProgress(int n, int total) {
    return 'Ụdị WAEC · Ajụjụ $n n\'ime $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct ziri ezi n\'ime $answered ị zara';
  }

  @override
  String get quizSayAnswer => 'Kwuo A, B, C ma ọ bụ D';

  @override
  String get quizListening => 'Ana m ege ntị… Pịa ka ọ kwụsị';

  @override
  String quizCorrect(String letter) {
    return 'Ọ ziri ezi! Ị họọrọ $letter.';
  }

  @override
  String quizWrong(String letter, String answer) {
    return 'Ọ bụghị ya. Ị họọrọ $letter. Azịza ya bụ $answer.';
  }

  @override
  String quizUnclear(String heard) {
    return 'Anụrụ m “$heard”. Biko kwuo A, B, C ma ọ bụ D.';
  }

  @override
  String get quizNothingHeard =>
      'Anụghị m azịza. Kwuo A, B, C ma ọ bụ D, ma ọ bụ pịa azịza ugboro abụọ.';

  @override
  String get quizNoVoice =>
      'Enweghị ike ịza n\'olu na ekwentị a. Pịa azịza ugboro abụọ kama.';

  @override
  String get quizRepeat => 'Kwughachi ajụjụ';

  @override
  String get quizNext => 'Ajụjụ ọzọ';

  @override
  String get quizFinish => 'Hụ nsonaazụ m';

  @override
  String get quizYourAnswerRight => 'azịza gị, ọ ziri ezi';

  @override
  String get quizYourAnswerWrong => 'azịza gị, o zighị ezi';

  @override
  String get quizRightAnswer => 'azịza ziri ezi';

  @override
  String get quizResultTitle => 'Omume agwụla';

  @override
  String quizResult(int correct, int total) {
    return 'Ị nwetara $correct ziri ezi n\'ime $total.';
  }

  @override
  String get quizAgain => 'Mee omume ọzọ';

  @override
  String get quizSource =>
      'Ndị otu Magana dere ajụjụ ndị a n\'ụdị WAEC Biology. Ha abụghị ajụjụ ochie. Ajụjụ ndị a dị n\'asụsụ Bekee.';

  @override
  String get skillsSubtitle => 'Nkuzi dị mkpụmkpụ a na-ekwu, n\'oge gị';

  @override
  String nextLesson(int minutes) {
    return 'Nkuzi ọzọ · nkeji $minutes';
  }

  @override
  String get playLesson => 'Kpọọ nkuzi';

  @override
  String get pauseLesson => 'Kwụsịtụ';

  @override
  String get practiseNow => 'Mee ya ugbu a';

  @override
  String get lessonDone => 'Emechara';

  @override
  String lessonStepOf(int step, int total) {
    return 'Nzọụkwụ $step n\'ime $total';
  }

  @override
  String get lessonNotStarted => 'Amabeghị';

  @override
  String get allLessonsDone => 'Ị mechaala nkuzi niile. Ị mere nke ọma!';

  @override
  String get practiseWithChampion => 'Mee omume ya na Onye mmeri Magana';

  @override
  String get skillsNote =>
      'Nkuzi ndị a bụ ihe atụ ndị otu Magana dere; ndị nkuzi mgbake ga-enyocha ha. Nkuzi dị n\'asụsụ Bekee ugbu a.';

  @override
  String get previousStep => 'Nzọụkwụ gara aga';

  @override
  String get nextStep => 'Nzọụkwụ ọzọ';

  @override
  String get lessonFinished => 'Nkuzi agwụla.';

  @override
  String get scoreTitle => 'Akara Nnwere Onwe M';

  @override
  String get scoreSubtitle => 'Ọrụ ị mechara na Magana';

  @override
  String scoreOutOf(int score) {
    return '$score n\'ime 100';
  }

  @override
  String get scoreByArea => 'Site na mpaghara';

  @override
  String get areaLearning => 'Mmụta';

  @override
  String get areaHealth => 'Akwụkwọ ahụike';

  @override
  String get areaMoney => 'Ego';

  @override
  String get areaSkills => 'Nka';

  @override
  String areaScoreLabel(String area, int score) {
    return '$area: $score n\'ime 100';
  }

  @override
  String get scoreThisWeek => 'Izu a';

  @override
  String get scoreNothingThisWeek =>
      'Enweghị ọrụ n\'izu a. Gụọ peeji ma ọ bụ mee ajụjụ ka ịmalite.';

  @override
  String weekReadSchool(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Agụrụ peeji ọrụ ụlọ akwụkwọ $count',
      one: 'Agụrụ peeji ọrụ ụlọ akwụkwọ 1',
    );
    return '$_temp0';
  }

  @override
  String weekReadMedicine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Agụrụ akara ọgwụ $count',
      one: 'Agụrụ akara ọgwụ 1',
    );
    return '$_temp0';
  }

  @override
  String weekReadReport(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Agụrụ akụkọ ahụike $count',
      one: 'Agụrụ akụkọ ahụike 1',
    );
    return '$_temp0';
  }

  @override
  String weekReadStatement(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Agụrụ akwụkwọ ụlọ akụ ma ọ bụ nnata $count',
      one: 'Agụrụ akwụkwọ ụlọ akụ ma ọ bụ nnata 1',
    );
    return '$_temp0';
  }

  @override
  String weekQuiz(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Emechara ajụjụ $count',
      one: 'Emechara ajụjụ 1',
    );
    return '$_temp0';
  }

  @override
  String weekLesson(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Emechara nkuzi $count',
      one: 'Emechara nkuzi 1',
    );
    return '$_temp0';
  }

  @override
  String get scoreHow =>
      'Akara gị na-agụ ezigbo ọrụ ị mechara na Magana n\'ime ụbọchị 30 gara aga. Ọ na-anọ na ekwentị a; naanị gị na-ahụ ya.';

  @override
  String get championsTitle => 'Ndị mmeri Magana';

  @override
  String get championsSubtitle => 'Mụta n\'aka ndị gabigara ya';

  @override
  String get championSample => 'Ihe atụ profaịlụ';

  @override
  String get championDetail => 'Kpuru ìsì kemgbe afọ 12 · Kano · Hausa, Bekee';

  @override
  String get championNotYet =>
      'Nke a bụ ihe atụ. A ga-ejikọ gị na Onye mmeri site n\'òtù ndị mmekọ. Oku adịbeghị.';

  @override
  String get becomeChampion => 'Bụrụ Onye mmeri';

  @override
  String get becomeChampionBody =>
      'Nyere ndị ọzọ aka n\'obodo gị ma nweta asambodo.';

  @override
  String get champStepBasics => 'Mechaa nkuzi Ntọala ekwentị';

  @override
  String get champStepPhotos => 'Mechaa nkuzi Ịse foto doro anya';

  @override
  String get champStepScore => 'Ruo Akara Nnwere Onwe 60';

  @override
  String get champStepTraining => 'Sonye na ọzụzụ Onye mmeri awa 2';

  @override
  String get champStepHelp => 'Nyere mmadụ 3 mbụ aka';

  @override
  String get stepDone => 'emechara';

  @override
  String get stepNotDone => 'emechabeghị';

  @override
  String get championsPartnerNote =>
      'A ga-eme ọzụzụ Onye mmeri na òtù ndị mmekọ. Emepebeghị ya.';
}
