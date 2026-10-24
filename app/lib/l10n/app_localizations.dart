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
  /// **'Lay the page flat in good light and hold the phone about one forearm above it. I\'ll tell you how to move, and take the photo when the whole page is steady. You can also tap Take photo.'**
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

  /// No description provided for @whereLine.
  ///
  /// In en, this message translates to:
  /// **'line {number}'**
  String whereLine(int number);

  /// No description provided for @whereRow.
  ///
  /// In en, this message translates to:
  /// **'row {number}'**
  String whereRow(int number);

  /// No description provided for @whereCell.
  ///
  /// In en, this message translates to:
  /// **'row {row}, column {col}'**
  String whereCell(int row, int col);

  /// No description provided for @whereTop.
  ///
  /// In en, this message translates to:
  /// **'near the top of the page'**
  String get whereTop;

  /// No description provided for @whereMiddle.
  ///
  /// In en, this message translates to:
  /// **'in the middle of the page'**
  String get whereMiddle;

  /// No description provided for @whereBottom.
  ///
  /// In en, this message translates to:
  /// **'near the bottom of the page'**
  String get whereBottom;

  /// Said and shown in place of a number the app could not read reliably.
  ///
  /// In en, this message translates to:
  /// **'unclear number'**
  String get unclearNumber;

  /// No description provided for @faintPrint.
  ///
  /// In en, this message translates to:
  /// **'Faint print'**
  String get faintPrint;

  /// No description provided for @msg_too_dark.
  ///
  /// In en, this message translates to:
  /// **'It\'s quite dark. Turn on the torch or move to more light.'**
  String get msg_too_dark;

  /// No description provided for @msg_blurry.
  ///
  /// In en, this message translates to:
  /// **'The photo looks blurry. Hold the phone still and try again.'**
  String get msg_blurry;

  /// No description provided for @msg_low_confidence.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure about {where}. Please check it or retake the photo.'**
  String msg_low_confidence(String where);

  /// No description provided for @msg_low_confidence_number.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read a number on {where} clearly. Please check it or retake the photo.'**
  String msg_low_confidence_number(String where);

  /// No description provided for @msg_unreadable_number.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read a number on {where} clearly. Please check it or retake the photo.'**
  String msg_unreadable_number(String where);

  /// No description provided for @msg_number_mismatch.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read a number on {where} clearly. Please check it or retake the photo.'**
  String msg_number_mismatch(String where);

  /// No description provided for @msg_faint_region.
  ///
  /// In en, this message translates to:
  /// **'There is faint print {where} that I can\'t read. Try more light, or retake the photo.'**
  String msg_faint_region(String where);

  /// No description provided for @msg_unknown_mode.
  ///
  /// In en, this message translates to:
  /// **'Choose schoolwork, health or money.'**
  String get msg_unknown_mode;

  /// No description provided for @msg_not_allowed_for_tier.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available on this account.'**
  String get msg_not_allowed_for_tier;

  /// No description provided for @msg_consent_required.
  ///
  /// In en, this message translates to:
  /// **'Learners aged 13 to 17 need a parent\'s or guardian\'s consent first.'**
  String get msg_consent_required;

  /// No description provided for @msg_teacher_session_required.
  ///
  /// In en, this message translates to:
  /// **'Learners under 13 can only use Magana in a teacher-run session.'**
  String get msg_teacher_session_required;

  /// No description provided for @msg_unreadable_image.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t open that photo. Please try again.'**
  String get msg_unreadable_image;

  /// No description provided for @msg_numbers_unconfirmed.
  ///
  /// In en, this message translates to:
  /// **'I can\'t confirm some numbers in this explanation, so I\'ll read the page exactly instead.'**
  String get msg_numbers_unconfirmed;

  /// CLINICAL DRAFT: needs clinical sign-off before translation.
  ///
  /// In en, this message translates to:
  /// **'This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.'**
  String get msg_go_to_clinic_now;

  /// CLINICAL DRAFT: needs clinical sign-off before translation.
  ///
  /// In en, this message translates to:
  /// **'Thank you. A nurse will call you within 2 hours.'**
  String get msg_nurse_call_within_2_hours;

  /// CLINICAL DRAFT: needs clinical sign-off before translation.
  ///
  /// In en, this message translates to:
  /// **'Thank you. A nurse will call you back during working hours.'**
  String get msg_nurse_call_working_hours;

  /// No description provided for @guideTooDark.
  ///
  /// In en, this message translates to:
  /// **'It\'s dark. Turn on the torch or find more light.'**
  String get guideTooDark;

  /// No description provided for @guideNoPage.
  ///
  /// In en, this message translates to:
  /// **'I can\'t see a page yet. Point the phone down at the page.'**
  String get guideNoPage;

  /// No description provided for @guideMoveCloser.
  ///
  /// In en, this message translates to:
  /// **'Bring the phone a little closer to the page.'**
  String get guideMoveCloser;

  /// No description provided for @guideLiftPhone.
  ///
  /// In en, this message translates to:
  /// **'Lift the phone a little higher, so the whole page fits.'**
  String get guideLiftPhone;

  /// Spoken while framing: the page's top edge is outside the camera view.
  ///
  /// In en, this message translates to:
  /// **'Move the phone a little toward the top of the page. The top is cut off.'**
  String get guideMoveUp;

  /// No description provided for @guideMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move the phone a little toward the bottom of the page. The bottom is cut off.'**
  String get guideMoveDown;

  /// No description provided for @guideMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move the phone a little to the left. The left edge is cut off.'**
  String get guideMoveLeft;

  /// No description provided for @guideMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move the phone a little to the right. The right edge is cut off.'**
  String get guideMoveRight;

  /// No description provided for @guideHoldStill.
  ///
  /// In en, this message translates to:
  /// **'Good. Hold still.'**
  String get guideHoldStill;

  /// No description provided for @guideCapturing.
  ///
  /// In en, this message translates to:
  /// **'Taking the photo.'**
  String get guideCapturing;

  /// Switch: take the photo by itself when the page is steady and in frame.
  ///
  /// In en, this message translates to:
  /// **'Auto-capture'**
  String get autoCapture;

  /// No description provided for @torchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on torch'**
  String get torchOn;

  /// No description provided for @torchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off torch'**
  String get torchOff;

  /// No description provided for @cameraView.
  ///
  /// In en, this message translates to:
  /// **'Camera view'**
  String get cameraView;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'I can\'t use the camera. Allow camera access in Settings, or choose a photo from the gallery.'**
  String get cameraUnavailable;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Do you have a fever, or does your body feel very hot?'**
  String get msg_q_fever;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'For how many days have you had the fever?'**
  String get msg_q_fever_days;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Have you had fits, or shaking of the body you could not stop?'**
  String get msg_q_fits;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are you unable to drink anything, or is the baby unable to breastfeed?'**
  String get msg_q_cannot_drink;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are you vomiting everything you eat or drink?'**
  String get msg_q_vomits_everything;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are you very sleepy, confused, or hard to wake?'**
  String get msg_q_very_sleepy;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are you bleeding without a clear reason, from the nose or gums, or in vomit or stool?'**
  String get msg_q_bleeding;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Have your eyes or skin turned yellow?'**
  String get msg_q_yellow_eyes;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are you breathing very fast, or struggling to breathe?'**
  String get msg_q_hard_breathing;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are your palms, lips or inner eyelids very pale?'**
  String get msg_q_very_pale;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Is your urine very dark, like cola or tea?'**
  String get msg_q_dark_urine;

  /// CLINICAL DRAFT from the Ibà service: English only until Dr. Amos signs off.
  ///
  /// In en, this message translates to:
  /// **'Are you too weak to sit up or stand without help?'**
  String get msg_q_too_weak;
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
