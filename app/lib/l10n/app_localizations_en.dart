// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Magana';

  @override
  String get greeting => 'Hello';

  @override
  String languageButtonLabel(String language) {
    return 'App language: $language. Change language';
  }

  @override
  String get chooseLanguage => 'Choose app language';

  @override
  String languageChanged(String language) {
    return 'App language is now $language.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get readPage => 'Read a page';

  @override
  String get readPageSubtitle =>
      'Schoolwork, medical reports, bank statements, letters — anything printed';

  @override
  String get askQuestion => 'Ask a question';

  @override
  String get practiceQuiz => 'Practice quiz';

  @override
  String get myLibrary => 'My library';

  @override
  String get everydayPapers => 'Everyday papers';

  @override
  String get skills => 'Skills';

  @override
  String get myScore => 'My score';

  @override
  String get holdToSpeak => 'Hold to speak';

  @override
  String get holdToSpeakLabel => 'Hold to speak a command';

  @override
  String get voiceCommands => 'Voice commands';

  @override
  String get comingSoonHint => 'Coming soon';

  @override
  String comingSoon(String feature) {
    return '$feature is coming soon.';
  }

  @override
  String get backToHome => 'Back to home';

  @override
  String get framingGuidance =>
      'Lay the page flat in good light. Hold the phone about one forearm above it, so all four corners fit. Then tap Take photo, at the bottom of the screen.';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatInstructions => 'Hear the instructions again';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get gallery => 'Gallery';

  @override
  String get galleryLabel => 'Choose a photo from the gallery';

  @override
  String get cameraFailed =>
      'I couldn\'t open the camera. Try Gallery instead.';

  @override
  String get readingPage => 'Reading the page. Please wait.';

  @override
  String get noTextFound =>
      'I couldn\'t find any text. Check the page is face up and try again.';

  @override
  String get cannotReach =>
      'I couldn\'t reach Magana. Check the connection and try again.';

  @override
  String get readFailed =>
      'Something went wrong reading the page. Please try again.';

  @override
  String get yourPage => 'Your page';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String unclearCount(int count) {
    return '$count unclear';
  }

  @override
  String linePosition(int number, int total) {
    return 'Line $number of $total';
  }

  @override
  String rowPosition(int number, int total) {
    return 'Row $number of $total';
  }

  @override
  String rowPositionInTable(int number, int total, int table) {
    return 'Row $number of $total, table $table';
  }

  @override
  String get nowReading => 'now reading';

  @override
  String get previous => 'Prev';

  @override
  String get next => 'Next';

  @override
  String get previousLine => 'Previous line';

  @override
  String get previousRow => 'Previous row';

  @override
  String get nextLine => 'Next line';

  @override
  String get nextRow => 'Next row';

  @override
  String get repeatLine => 'Repeat this line';

  @override
  String get repeatRow => 'Repeat this row';

  @override
  String speed(String value) {
    return 'Speed $value';
  }

  @override
  String speedLabel(String value) {
    return 'Reading speed $value. Tap to change';
  }

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get pauseLabel => 'Pause reading';

  @override
  String get playLabel => 'Read from here';

  @override
  String get pageRead => 'Page read.';

  @override
  String unsureSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I\'m not sure about $count of them.',
      one: 'I\'m not sure about 1 of them.',
    );
    return '$_temp0 I\'ll tell you when we get there.';
  }

  @override
  String unsureLine(int number) {
    return 'I\'m not sure about line $number. Please check it or retake the photo.';
  }

  @override
  String unsureRow(int number) {
    return 'I\'m not sure about row $number. Please check it or retake the photo.';
  }

  @override
  String get firstLine => 'This is the first line.';

  @override
  String get firstRow => 'This is the first row.';

  @override
  String get endOfPage => 'End of page.';

  @override
  String get endOfPageHint =>
      'End of page. Tap Repeat, or go back to read another page.';
}
