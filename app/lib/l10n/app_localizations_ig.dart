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
  String get msg_explain_wrong_language =>
      'Enweghị m ike ịkọwa nke a n\'asụsụ gị, ya mere aga m agụ peeji ahụ otú o si dị.';

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
  String quizProgress(int n, int total) {
    return 'Ajụjụ $n n\'ime $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct ziri ezi n\'ime $answered ị zara';
  }

  @override
  String quizSayAnswer(String letters) {
    return 'Kwuo $letters';
  }

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
  String quizUnclear(String heard, String letters) {
    return 'Anụrụ m “$heard”. Biko kwuo $letters.';
  }

  @override
  String quizNothingHeard(String letters) {
    return 'Anụghị m azịza. Kwuo $letters, ma ọ bụ pịa azịza ugboro abụọ.';
  }

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
  String get areaMoney => 'Ego na akwụkwọ ozi';

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

  @override
  String get librarySubtitle => 'Ihe agụrụ e chekwara, ruo ụbọchị 30';

  @override
  String get libraryEmpty =>
      'Enweghị ihe echekwara ugbu a. Mgbe Magana gụchara peeji, họrọ Chekwaa n\'ọbá akwụkwọ m.';

  @override
  String libraryDeletesIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'a ga-ehichapụ ya n\'ụbọchị $count',
      one: 'a ga-ehichapụ ya echi',
      zero: 'a ga-ehichapụ ya taa',
    );
    return '$_temp0';
  }

  @override
  String librarySavedOn(String date) {
    return 'Echekwara na $date';
  }

  @override
  String get libraryPrivacy =>
      'Ihe agụrụ e chekwara na-anọ na ekwentị a, a na-ehichapụkwa ha mgbe ụbọchị 30 gachara. Anaghị echekwa foto.';

  @override
  String get saveToLibrary => 'Chekwaa n\'ọbá akwụkwọ m';

  @override
  String get savedToLibrary =>
      'Echekwala ya n\'ọbá akwụkwọ gị. Ọ ga-anọ na ekwentị a ruo ụbọchị 30.';

  @override
  String get deleteFromLibrary => 'Hichapụ ya n\'ọbá akwụkwọ m';

  @override
  String get deleteConfirm => 'Ị chọrọ ihichapụ ihe a agụrụ n\'ọbá akwụkwọ gị?';

  @override
  String get deleteYes => 'Hichapụ';

  @override
  String get deletedFromLibrary => 'Ehichapụla ya n\'ọbá akwụkwọ gị.';

  @override
  String get remindersTitle => 'Ọgwụ taa';

  @override
  String get remindersSubtitle => 'Oge gị na onye na-ere ọgwụ setịrị';

  @override
  String get remindersCard => 'Ihe ncheta ọgwụ';

  @override
  String get remindersCardDetail => 'Oge maka ọgwụ gị';

  @override
  String get remindersEmpty =>
      'Enweghị ihe ncheta ugbu a. Tinye oge onye na-ere ọgwụ ma ọ bụ dọkịta nyere gị.';

  @override
  String get doseTaken => 'Aṅụọla';

  @override
  String get doseDue => 'Oge eruola';

  @override
  String get doseLater => 'Ma emechaa taa';

  @override
  String doseLabel(String time, String state, String medicine, String amount) {
    return '$time, $state. $medicine. $amount';
  }

  @override
  String get iTookIt => 'Aṅụọla m ya';

  @override
  String get remindLater => 'Chetara m n\'ime nkeji 15';

  @override
  String get remindLaterSet => 'M ga-echetara gị ọzọ n\'ime nkeji 15.';

  @override
  String get markedTaken => 'Edere na ị ṅụọla ya.';

  @override
  String get addReminder => 'Tinye ihe ncheta';

  @override
  String get medicineName => 'Aha ọgwụ, dị ka o dị n\'akara';

  @override
  String get medicineAmount => 'Ole ka onye na-ere ọgwụ kwuru (dịka, mkpụrụ 2)';

  @override
  String get reminderTime => 'Oge';

  @override
  String get earlierHour => 'Otu awa tupu';

  @override
  String get laterHour => 'Otu awa mgbe';

  @override
  String get earlierMinutes => 'Nkeji 15 tupu';

  @override
  String get laterMinutes => 'Nkeji 15 mgbe';

  @override
  String get saveReminder => 'Chekwaa ihe ncheta';

  @override
  String get medicineNameNeeded => 'Buru ụzọ dee aha ọgwụ ahụ.';

  @override
  String reminderSaved(String time) {
    return 'Echekwala ihe ncheta maka $time.';
  }

  @override
  String get deleteReminder => 'Hichapụ ihe ncheta';

  @override
  String deleteReminderConfirm(String time, String medicine) {
    return 'Hichapụ ihe ncheta $time maka $medicine?';
  }

  @override
  String get reminderNotice =>
      'Ekwentị gị ga-ada ụda ma maa jijiji n\'oge ọ bụla, dị ka ọkwa. Magana na-echetara gị n\'oge ị setịrị. Ọ naghị agbanwe ọnụọgụ ọgwụ.';

  @override
  String get notificationsOff =>
      'Agbanyụrụ ọkwa maka Magana, ya mere ihe ncheta ga-apụta naanị mgbe Magana mepere emepe. Ị nwere ike ịgbanye ha na ntọala ekwentị gị.';

  @override
  String get missedDose => 'Ị ṅụghị ọgwụ n\'oge? Jụọ onye na-ere ọgwụ';

  @override
  String get reminderNotifyTitle => 'Oge ịṅụ ọgwụ gị eruola';

  @override
  String get exactTitle => 'Ka ọ daa n\'oge?';

  @override
  String get exactBody =>
      'Ka ọ daa n\'otu nkeji ahụ, ekwentị gị ga-ekwe Magana ka o setịa mkpu na ihe ncheta. Ihuenyo na-esote nwere otu mgbanwe: gbanye ya, wee laghachi.';

  @override
  String get exactOpen => 'Mepee ntọala ahụ';

  @override
  String get notNow => 'Ọ bụghị ugbu a';

  @override
  String get remindersMayBeLate =>
      'Na ekwentị a, ihe ncheta nwere ike ịda ruo otu awa mgbe oge gachara. Ka ọ daa n\'oge, kwe Magana maka mkpu na ihe ncheta.';

  @override
  String get allowOnTime => 'Kwe ihe ncheta n\'oge';

  @override
  String get msg_q_bleeding_no_sight =>
      'Ị nụrụ ma ọ bụ detụ ọbara ire, ma ọ bụ onye ọ gwara gị na ọbara na-esi gị, site n\'imi, ọnụ eze, agbọ ma ọ bụ nsị?';

  @override
  String get msg_q_yellow_eyes_no_sight =>
      'Onye ọ gwara gị na anya gị ma ọ bụ akpụkpọ ahụ gị dị ka odo odo?';

  @override
  String get msg_q_very_pale_no_sight =>
      'Onye ọ gwara gị na ị chachara nke ukwuu? Ị na-adịkarị ike nke ukwuu, isi na-agba gị gburugburu ma ọ bụ ume na-ekupụ gị mgbe ị guzoro?';

  @override
  String get msg_q_dark_urine_no_sight =>
      'Onye nọ gị nso ọ hụla na mamịrị gị gbara oji nke ukwuu, dịka kola ma ọ bụ tii?';

  @override
  String get msg_ask_someone_to_check =>
      'Biko rịọ onye nọ gị nso ka o lelee ya, ma ọ bụ gaa ụlọ ọgwụ.';

  @override
  String get cantTell => 'Amaghị m';

  @override
  String get appLanguageTitle => 'Asụsụ ngwa';

  @override
  String get languageSheetBody =>
      'Menu, bọtịnụ, enyemaka na olu Magana ga-agbanwe gaa n\'asụsụ ị họọrọ.';

  @override
  String get languageVoiceTip =>
      'Ị nwekwara ike ikwu “change language to Igbo” mgbe ị pịrị Kwuo iwu na ihuenyo mbụ.';

  @override
  String useLanguage(String language) {
    return 'Jiri $language';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'Ụdị $version (nke $build)';
  }

  @override
  String get settingsVersionNote =>
      'Gwa ndị otu Magana ụdị a mgbe ị na-akọ nsogbu.';

  @override
  String get reportProblem => 'Kọọ nsogbu';

  @override
  String get reportHow =>
      'Gwa ndị otu Magana ihe atọ: aha ihuenyo ahụ, ihe ị mere, na ihe Magana kwuru.';

  @override
  String get speakCommand => 'Kwuo iwu';

  @override
  String get listeningCommand => 'Ana m ege ntị… Pịa ka ọ kwụsị';

  @override
  String commandNotUnderstood(String heard) {
    return 'Anụrụ m “$heard”, mana amaghị m iwu ahụ. Kwuo help ka ị nụ ihe ị nwere ike ikwu.';
  }

  @override
  String get commandNothingHeard =>
      'Anụghị m iwu ọ bụla. Nwaa ọzọ, ma ọ bụ kwuo help.';

  @override
  String commandHelp(String commands) {
    return 'Ị nwere ike ikwu: $commands. Kwuo iwu n\'asụsụ Bekee ugbu a.';
  }

  @override
  String get changeLanguageCommand => 'change language';

  @override
  String get voiceCommandsUnavailable =>
      'Enweghị ike iji iwu olu na ekwentị a. Jiri bọtịnụ kama.';

  @override
  String get explainTitle => 'Nkọwa';

  @override
  String explainFrom(String source) {
    return 'Site na: $source';
  }

  @override
  String get explainPreviewBanner =>
      'Nlele. N-ATLAS, nke ga-akọwa peeji n\'asụsụ gị, ejikọbeghị. Ugbu a Magana na-agụ ederede peeji ahụ kpọmkwem ka e si bipụta ya.';

  @override
  String answerLanguage(String language) {
    return 'Asụsụ azịza, ugbu a $language';
  }

  @override
  String get youSaid => 'Ị kwuru';

  @override
  String basedOnPage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dabere na: ahịrị $count nke peeji gị',
      one: 'Dabere na: ahịrị 1 nke peeji gị',
    );
    return '$_temp0';
  }

  @override
  String get readExactlyNote =>
      'A na-agụ nọmba na okwu sitere na peeji ahụ kpọmkwem ka e si bipụta ha.';

  @override
  String get saySimpler => 'Kwuo ya n\'ụzọ dị mfe';

  @override
  String get giveExample => 'Nye ihe atụ';

  @override
  String get explainDisclaimer =>
      'Magana nwere ike imehie. Lelee azịza ndị dị mkpa na onye nkuzi gị.';

  @override
  String get askAQuestion => 'Jụọ ajụjụ';

  @override
  String get explainNoPage =>
      'Nkọwa bụ maka peeji. Buru ụzọ gụọ peeji, wee họrọ Kọwaa nke a.';

  @override
  String get explainThis => 'Kọwaa nke a';

  @override
  String get explainQuestionPreview =>
      'Mgbe ejikọrọ N-ATLAS, Magana ga-aza ajụjụ gị site na peeji a. Ugbu a, lee peeji ahụ.';

  @override
  String get msg_explain_preview =>
      'Nke a bụ nlele. Nkọwa n\'asụsụ gị ga-abịa mgbe ejikọrọ N-ATLAS. Lee peeji ahụ, a gụrụ ya kpọmkwem ka e si bipụta ya.';

  @override
  String get msg_explained => 'Lee nkọwa ahụ.';

  @override
  String get msg_explain_bad_source =>
      'Enweghị ederede peeji a ga-akọwa. Biko buru ụzọ gụọ peeji.';

  @override
  String get jumpWithinPage => 'Wụga n\'ime peeji';

  @override
  String get jumpStart => 'Mmalite peeji';

  @override
  String jumpTable(int number) {
    return 'Tebụl $number';
  }

  @override
  String get jumpWarnings => 'Ihe na-esote m na-ejighị n\'aka';

  @override
  String get jumpNotYet => 'Enweghị ike ịwụga n\'isiokwu na eserese ugbu a.';

  @override
  String get paperLetter => 'Akwụkwọ ozi na fọm';

  @override
  String get paperLetterDetail => 'Ọkwa, fọm, ederede okpukpe';

  @override
  String get noteLetter =>
      'Magana na-agụ ihe e biri ebi. Ọ naghị enye ndụmọdụ iwu ma ọ bụ ego, ọ naghịkwa ajụ PIN ma ọ bụ okwuntughe gị.';

  @override
  String get readAnyPaper => 'Gụọ akwụkwọ ọ bụla';

  @override
  String get readAnyPaperDetail => 'Magana ga-achọpụta ụdị akwụkwọ ọ bụ';

  @override
  String detectedPaper(String paper) {
    return 'Ụdị akwụkwọ: $paper.';
  }

  @override
  String weekReadLetter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Agụrụ akwụkwọ ozi ma ọ bụ fọm $count',
      one: 'Agụrụ akwụkwọ ozi ma ọ bụ fọm 1',
    );
    return '$_temp0';
  }

  @override
  String get readAgain => 'Gụọ ya ọzọ';

  @override
  String get askAboutResult => 'Gịnị ka nke a pụtara?';

  @override
  String get resultAnswer =>
      'Naanị onye ọrụ ahụike gị nwere ike ịkọwa ihe nsonaazụ a pụtara maka gị. Enwere m ike ichekwa ajụjụ gị maka nleta gị ọzọ, ma ọ bụ rịọ nọọsụ ka ọ kpọọ gị.';

  @override
  String youAsked(String question) {
    return 'Ị jụrụ: “$question”';
  }

  @override
  String get saveQuestion => 'Chekwaa ajụjụ';

  @override
  String get questionSaved =>
      'Echekwala ya. Ị ga-ahụ ya na Gwa onye ọrụ ahụike okwu.';

  @override
  String get askANurse => 'Jụọ nọọsụ';

  @override
  String get savedQuestionsTitle => 'Ajụjụ maka nleta gị ọzọ';

  @override
  String removeQuestion(String question) {
    return 'Wepụ: $question';
  }

  @override
  String questionAbout(String question, String where) {
    return '$question (maka $where)';
  }

  @override
  String get fromTheStatement =>
      'Site na akwụkwọ ụlọ akụ, kpọmkwem ka e si bipụta ya';

  @override
  String get findTransaction => 'Chọta azụmahịa';

  @override
  String get findPrompt =>
      'Kwuo ma ọ bụ dee okwu, ụbọchị ma ọ bụ ego site na azụmahịa ahụ.';

  @override
  String get findField => 'Okwu, ụbọchị ma ọ bụ ego';

  @override
  String get findSearch => 'Chọta';

  @override
  String get findSpeak => 'Kwuo ya kama';

  @override
  String findNoMatch(String query) {
    return 'Enweghị ahịrị nwere “$query”.';
  }

  @override
  String get sayYesOrNo => 'Kwuo ee, mba, ma ọ bụ amaghị m';

  @override
  String voiceAnswerUnclear(String heard) {
    return 'Anụrụ m “$heard”. Biko kwuo ee, mba, ma ọ bụ amaghị m.';
  }

  @override
  String scoreUpSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'izu $weeks gara aga',
      one: 'izu 1 gara aga',
    );
    return 'Ọ rịgoro site na $start mgbe ị malitere, $_temp0';
  }

  @override
  String scoreSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'izu $weeks gara aga',
      one: 'izu 1 gara aga',
    );
    return '$start mgbe ị malitere, $_temp0';
  }

  @override
  String get shareScore => 'Kekọrịta akara m na onye nkuzi m';

  @override
  String get shareScoreNote =>
      'Onye nkuzi gị ga-ahụ akara gị, ọ bụghị peeji ma ọ bụ ajụjụ gị, ozugbo ejikọrọ klaasị gị na ọnụ ụzọ ndị nkuzi Magana.';

  @override
  String get sayNameWhenLocked => 'Kwuo aha ọgwụ mgbe ekwentị kpọchiri';

  @override
  String get sayNameNote =>
      'Agbanyụọ: ihuenyo mkpọchi ga-ekwu naanị “Ihe ncheta Magana”. Agbanyere: ihuenyo mkpọchi ga-egosi ọgwụ na ole, Magana ga-ekwukwa ha n\'oke olu n\'oge ọ bụla, ya mere ndị nọ gị nso nwere ike ịhụ ma ọ bụ nụ ha.';

  @override
  String get reminderGenericTitle => 'Ihe ncheta Magana';

  @override
  String get reminderGenericBody => 'Mepee Magana ka ị nụ ọgwụ ole.';

  @override
  String get msg_bad_api_key =>
      'Mbipụta Magana a enweghị ike iru ọrụ ịgụ ihe. Biko melite ngwa ahụ.';

  @override
  String get msg_explain_unavailable =>
      'Enweghị nkọwa ugbu a. Lee peeji ahụ, a gụrụ ya kpọmkwem ka e si bipụta ya.';

  @override
  String get msg_asr_unavailable =>
      'Edoziteghị nghọta olu na sava; a na-eji nke ekwentị.';

  @override
  String get msg_audio_too_long =>
      'Ndekọ ahụ ogologo nke ukwuu. Biko kwuo azịza dị mkpụmkpụ.';

  @override
  String get msg_unreadable_audio => 'Anụghị m ndekọ ahụ. Biko nwaa ọzọ.';

  @override
  String get aboutTitle => 'Banyere Magana';

  @override
  String get aboutModels => 'Ụdị asụsụ';

  @override
  String get aboutModelsNote =>
      'Magana na-eji ụdị mepere emepe ndị a n\'okpuru Usoro Ojiji N-ATLaS, ụdị 1.0. A kọpịrị ahịrị nkwanye ùgwù ndị dị n\'okpuru ka usoro ahụ si chọọ.';

  @override
  String get aboutExplain => 'Nkọwa n\'asụsụ gị';

  @override
  String get aboutSpeech => 'Nghọta olu';

  @override
  String get openSourceLicences => 'Ikikere isi mmalite mepere emepe';

  @override
  String aboutContact(String email) {
    return 'Ajụjụ ma ọ bụ nsogbu: zigara $email ozi email';
  }

  @override
  String get msg_explain_not_available =>
      'Nkọwa adịbeghị. Lee peeji ahụ, a gụrụ ya kpọmkwem ka e si bipụta ya.';

  @override
  String quizConfirm(String answer) {
    return 'Ị kwuru $answer. Ọ bụ eziokwu?';
  }

  @override
  String quizConfirmYes(String answer) {
    return 'Ee, $answer';
  }

  @override
  String get quizConfirmNo => 'Mba, jụọ m ọzọ';

  @override
  String get quizSayYesOrNo => 'Kwuo ee ma ọ bụ mba';

  @override
  String get quizSayAgain => 'Biko kwughachi azịza gị.';

  @override
  String get quizTapInstead =>
      'O siri m ike ịnụ gị. Biko pịa azịza gị ugboro abụọ kama.';

  @override
  String get quizSayTrueFalse => 'Kwuo eziokwu ma ọ bụ ụgha';

  @override
  String get msg_too_many_requests =>
      'Magana na-arụsi ọrụ ike ugbu a. Biko chere otu nkeji wee nwaa ọzọ.';

  @override
  String get remindersNeedApp =>
      'Ihe ncheta chọrọ ngwa Android ma ọ bụ iPhone. Na ihe nchọgharị, Magana enweghị ike ịda n\'oge kwesịrị ekwesị.';

  @override
  String get quizVoiceUnavailable =>
      'Ịza n\'olu adịbeghị na ngwaọrụ a. Pịa azịza kama.';

  @override
  String quizVoiceUnavailableWeb(String letters) {
    return 'Ịza n\'olu adịbeghị na ngwaọrụ a. Pịa ma ọ bụ kpịa azịza, ma ọ bụ pịa $letters na kiiboodu gị.';
  }

  @override
  String quizKeysHint(String letters) {
    return 'Pịa ma ọ bụ kpịa azịza, ma ọ bụ pịa $letters na kiiboodu gị.';
  }

  @override
  String get quizKeysHintTrueFalse =>
      'Pịa ma ọ bụ kpịa eziokwu ma ọ bụ ụgha, ma ọ bụ pịa A maka eziokwu ma ọ bụ B maka ụgha.';

  @override
  String get quizTapAnswer => 'Pịa azịza.';

  @override
  String get startMagana => 'Malite Magana';

  @override
  String get classTitle => 'Klaasị ole ka ị nọ?';

  @override
  String get classBody =>
      'Magana ga-ahọrọ ajụjụ omume maka klaasị gị. Onye nkuzi nwere ike ịgbanwe ya ma emechaa.';

  @override
  String get classNotInSchool => 'Anọghị m n\'ụlọ akwụkwọ';

  @override
  String get classGroupPrimary => 'Ụlọ akwụkwọ praịmarị';

  @override
  String get classGroupJss => 'Sekọndrị nta';

  @override
  String get classGroupSss => 'Sekọndrị ukwu';

  @override
  String get classroomChooseClass => 'Onye nkuzi: họrọ klaasị maka nnọkọ a';

  @override
  String get classroomNeedsClass => 'Buru ụzọ họrọ klaasị.';

  @override
  String get settingsClass => 'Klaasị m';

  @override
  String get settingsChangeClass => 'Gbanwee klaasị (onye nkuzi)';

  @override
  String get changeClassConfirmTitle =>
      'Ọ bụ naanị onye nkuzi kwesịrị ịgbanwe klaasị. Ị bụ onye nkuzi?';

  @override
  String get changeClassYes => 'Ee, abụ m onye nkuzi';

  @override
  String quizYourClass(String name) {
    return 'Klaasị gị: $name';
  }

  @override
  String get quizFromTeacher => 'Site n\'aka onye nkuzi gị';

  @override
  String get quizSamples => 'Ajụjụ ihe atụ';

  @override
  String quizCount(int n) {
    return 'Ajụjụ $n';
  }

  @override
  String get quizChooseClassHint =>
      'Họrọ klaasị gị iji nweta ajụjụ ya. Onye nkuzi nwere ike idozi ya na Ntọala.';

  @override
  String get quizSampleNote =>
      'Ajụjụ ihe atụ ndị otu Magana dere. Ha abụghị ajụjụ ochie, onye nkuzi ga-elele ha. Ajụjụ ndị a dị n\'asụsụ Bekee.';

  @override
  String get quizTeacherNote => 'Onye nkuzi gị mere ya.';

  @override
  String quizSubjectTitle(String subject) {
    return 'Omume $subject';
  }

  @override
  String quizCorrectPrimary(String letter) {
    return 'Ị mere nke ọma! Ị họọrọ $letter.';
  }

  @override
  String quizWrongPrimary(String answer) {
    return 'Ị nwalere nke ọma! Azịza ya bụ $answer.';
  }

  @override
  String quizPicture(String description) {
    return 'Foto: $description';
  }

  @override
  String get quizOr => 'ma ọ bụ';

  @override
  String get quizSessionOpen => 'Onye nkuzi: meghee nnọkọ klaasị gị';

  @override
  String get quizSessionPrompt =>
      'Ọ bụ naanị onye nkuzi kwesịrị imeghe nnọkọ klaasị. Dee koodu nnọkọ si na ọdụ ndị nkuzi.';

  @override
  String get quizSessionCodeLabel => 'Koodu nnọkọ';

  @override
  String get quizSessionStart => 'Meghee nnọkọ';

  @override
  String quizSessionActive(String code) {
    return 'Nnọkọ klaasị $code';
  }

  @override
  String get quizSessionEnd => 'Kwụsị nnọkọ klaasị';

  @override
  String get quizSessionEmpty =>
      'Enweghị ajụjụ site n\'aka onye nkuzi gị na nnọkọ a ugbu a.';

  @override
  String get msg_session_code_invalid =>
      'Koodu nnọkọ ahụ ezighi ezi. Lelee ya na ọdụ ndị nkuzi.';

  @override
  String get msg_paper_lines =>
      'Anaghị eji AI akọwa akwụkwọ ahụike na nke ego. A na-agụ ahịrị ọ bụla kpọmkwem, n\'asụsụ gị naanị ebe enwere ntụgharị a lelere.';

  @override
  String get msg_cant_translate_line_health =>
      'Enweghị m ike ịtụgharị ahịrị a n\'enweghị nsogbu. Biko jụọ onye na-ere ọgwụ (pharmacist).';

  @override
  String get msg_cant_translate_line_money =>
      'Enweghị m ike ịtụgharị ahịrị a n\'enweghị nsogbu. Biko jụọ mmadụ n\'ụlọ akụ gị.';

  @override
  String get msg_numbers_left_out =>
      'Ọnụọgụgụ kpọmkwem dị na peeji ahụ. Kwuo ‘read again’ ka ị nụ ha.';

  @override
  String get explainReadAgain => 'Gụgharịa peeji ahụ ọzọ';

  @override
  String get quizNotSure =>
      'Amaghị m nke ọma ihe ị kwuru. Biko kwughachi azịza gị.';

  @override
  String quizVoiceNotReady(String language) {
    return 'Ịza n\'olu n\'asụsụ $language adịbeghị nke ọma. Pịa azịza kama.';
  }

  @override
  String quizVoiceNotReadyWeb(String language, String letters) {
    return 'Ịza n\'olu n\'asụsụ $language adịbeghị nke ọma. Pịa ma ọ bụ kpịa azịza, ma ọ bụ pịa $letters na kiiboodu gị.';
  }

  @override
  String get quizVoicePrimaryOff =>
      'Na klaasị praịmarị, pịa azịza gị. Ịza n\'olu ga-abịa ma emechaa.';

  @override
  String quizVoicePrimaryOffWeb(String letters) {
    return 'Na klaasị praịmarị, pịa ma ọ bụ kpịa azịza gị, ma ọ bụ pịa $letters na kiiboodu gị.';
  }
}
