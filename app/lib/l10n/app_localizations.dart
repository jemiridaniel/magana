import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_ig.dart';
import 'app_localizations_yo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ha'),
    Locale('ig'),
    Locale('yo'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Magana'**
  String get appTitle;

  /// Short greeting under the app name on Home.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get greeting;

  /// No description provided for @languageButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'App language: {language}. Change language'**
  String languageButtonLabel(String language);

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose app language'**
  String get chooseLanguage;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'App language is now {language}.'**
  String languageChanged(String language);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @readPage.
  ///
  /// In en, this message translates to:
  /// **'Read a page'**
  String get readPage;

  /// No description provided for @readPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schoolwork, medical reports, bank statements, letters — anything printed'**
  String get readPageSubtitle;

  /// No description provided for @askQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get askQuestion;

  /// No description provided for @practiceQuiz.
  ///
  /// In en, this message translates to:
  /// **'Practice quiz'**
  String get practiceQuiz;

  /// No description provided for @myLibrary.
  ///
  /// In en, this message translates to:
  /// **'My library'**
  String get myLibrary;

  /// No description provided for @everydayPapers.
  ///
  /// In en, this message translates to:
  /// **'Everyday papers'**
  String get everydayPapers;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @myScore.
  ///
  /// In en, this message translates to:
  /// **'My score'**
  String get myScore;

  /// No description provided for @holdToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Hold to speak'**
  String get holdToSpeak;

  /// No description provided for @holdToSpeakLabel.
  ///
  /// In en, this message translates to:
  /// **'Hold to speak a command'**
  String get holdToSpeakLabel;

  /// No description provided for @voiceCommands.
  ///
  /// In en, this message translates to:
  /// **'Voice commands'**
  String get voiceCommands;

  /// No description provided for @comingSoonHint.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoonHint;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} is coming soon.'**
  String comingSoon(String feature);

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// Spoken when Capture opens. Keep it to short, concrete steps.
  ///
  /// In en, this message translates to:
  /// **'Lay the page flat in good light. Hold the phone about one forearm above it, so all four corners fit. Then tap Take photo, at the bottom of the screen.'**
  String get framingGuidance;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repeatInstructions.
  ///
  /// In en, this message translates to:
  /// **'Hear the instructions again'**
  String get repeatInstructions;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @galleryLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo from the gallery'**
  String get galleryLabel;

  /// No description provided for @cameraFailed.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t open the camera. Try Gallery instead.'**
  String get cameraFailed;

  /// No description provided for @readingPage.
  ///
  /// In en, this message translates to:
  /// **'Reading the page. Please wait.'**
  String get readingPage;

  /// No description provided for @noTextFound.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t find any text. Check the page is face up and try again.'**
  String get noTextFound;

  /// No description provided for @cannotReach.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t reach Magana. Check the connection and try again.'**
  String get cannotReach;

  /// No description provided for @readFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong reading the page. Please try again.'**
  String get readFailed;

  /// No description provided for @yourPage.
  ///
  /// In en, this message translates to:
  /// **'Your page'**
  String get yourPage;

  /// No description provided for @lineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String lineCount(int count);

  /// No description provided for @rowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String rowCount(int count);

  /// No description provided for @unclearCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unclear'**
  String unclearCount(int count);

  /// No description provided for @linePosition.
  ///
  /// In en, this message translates to:
  /// **'Line {number} of {total}'**
  String linePosition(int number, int total);

  /// No description provided for @rowPosition.
  ///
  /// In en, this message translates to:
  /// **'Row {number} of {total}'**
  String rowPosition(int number, int total);

  /// No description provided for @rowPositionInTable.
  ///
  /// In en, this message translates to:
  /// **'Row {number} of {total}, table {table}'**
  String rowPositionInTable(int number, int total, int table);

  /// No description provided for @nowReading.
  ///
  /// In en, this message translates to:
  /// **'now reading'**
  String get nowReading;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previousLine.
  ///
  /// In en, this message translates to:
  /// **'Previous line'**
  String get previousLine;

  /// No description provided for @previousRow.
  ///
  /// In en, this message translates to:
  /// **'Previous row'**
  String get previousRow;

  /// No description provided for @nextLine.
  ///
  /// In en, this message translates to:
  /// **'Next line'**
  String get nextLine;

  /// No description provided for @nextRow.
  ///
  /// In en, this message translates to:
  /// **'Next row'**
  String get nextRow;

  /// No description provided for @repeatLine.
  ///
  /// In en, this message translates to:
  /// **'Repeat this line'**
  String get repeatLine;

  /// No description provided for @repeatRow.
  ///
  /// In en, this message translates to:
  /// **'Repeat this row'**
  String get repeatRow;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed {value}'**
  String speed(String value);

  /// No description provided for @speedLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading speed {value}. Tap to change'**
  String speedLabel(String value);

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause reading'**
  String get pauseLabel;

  /// No description provided for @playLabel.
  ///
  /// In en, this message translates to:
  /// **'Read from here'**
  String get playLabel;

  /// No description provided for @pageRead.
  ///
  /// In en, this message translates to:
  /// **'Page read.'**
  String get pageRead;

  /// No description provided for @unsureSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{I\'m not sure about 1 of them.} other{I\'m not sure about {count} of them.}} I\'ll tell you when we get there.'**
  String unsureSummary(int count);

  /// No description provided for @unsureLine.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure about line {number}. Please check it or retake the photo.'**
  String unsureLine(int number);

  /// No description provided for @unsureRow.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure about row {number}. Please check it or retake the photo.'**
  String unsureRow(int number);

  /// No description provided for @firstLine.
  ///
  /// In en, this message translates to:
  /// **'This is the first line.'**
  String get firstLine;

  /// No description provided for @firstRow.
  ///
  /// In en, this message translates to:
  /// **'This is the first row.'**
  String get firstRow;

  /// No description provided for @endOfPage.
  ///
  /// In en, this message translates to:
  /// **'End of page.'**
  String get endOfPage;

  /// No description provided for @endOfPageHint.
  ///
  /// In en, this message translates to:
  /// **'End of page. Tap Repeat, or go back to read another page.'**
  String get endOfPageHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ha', 'ig', 'yo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ha':
      return AppLocalizationsHa();
    case 'ig':
      return AppLocalizationsIg();
    case 'yo':
      return AppLocalizationsYo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
