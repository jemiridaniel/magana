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
      'Shimfiɗa shafin a wuri mai haske. Riƙe wayar sama da shi kamar tsawon hannunka, har kusurwoyi huɗu duka su shiga. Sannan ka taɓa Ɗauki hoto, a ƙasan allo.';

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
  String unsureLine(int number) {
    return 'Ban tabbatar da layi na $number ba. Don Allah ka duba shi ko ka sake ɗaukar hoto.';
  }

  @override
  String unsureRow(int number) {
    return 'Ban tabbatar da jere na $number ba. Don Allah ka duba shi ko ka sake ɗaukar hoto.';
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
}
