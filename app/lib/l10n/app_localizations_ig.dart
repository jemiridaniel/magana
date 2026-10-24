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
      'Tọgbọ peeji ahụ n\'ala ebe ìhè dị mma. Jide ekwentị ahụ n\'elu ya ihe dịka ogologo aka gị, ka akụkụ anọ ya niile pụta. Mgbe ahụ, pịa See foto, n\'okpuru ihuenyo.';

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
  String unsureLine(int number) {
    return 'Ejighị m n\'aka ahịrị $number. Biko lelee ya ma ọ bụ see foto ọzọ.';
  }

  @override
  String unsureRow(int number) {
    return 'Ejighị m n\'aka usoro $number. Biko lelee ya ma ọ bụ see foto ọzọ.';
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
}
