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

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.'**
  String get msg_go_to_clinic_now;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Thank you. A nurse will call you within 2 hours.'**
  String get msg_nurse_call_within_2_hours;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Thank you. A nurse will call you back during working hours.'**
  String get msg_nurse_call_working_hours;

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

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Do you have a fever, or does your body feel very hot?'**
  String get msg_q_fever;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'For how many days have you had the fever?'**
  String get msg_q_fever_days;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Have you had fits, or shaking of the body you could not stop?'**
  String get msg_q_fits;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are you unable to drink anything, or is the baby unable to breastfeed?'**
  String get msg_q_cannot_drink;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are you vomiting everything you eat or drink?'**
  String get msg_q_vomits_everything;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are you very sleepy, confused, or hard to wake?'**
  String get msg_q_very_sleepy;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are you bleeding without a clear reason, from the nose or gums, or in vomit or stool?'**
  String get msg_q_bleeding;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Have your eyes or skin turned yellow?'**
  String get msg_q_yellow_eyes;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are you breathing very fast, or struggling to breathe?'**
  String get msg_q_hard_breathing;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are your palms, lips or inner eyelids very pale?'**
  String get msg_q_very_pale;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Is your urine very dark, like cola or tea?'**
  String get msg_q_dark_urine;

  /// CLINICAL DRAFT, pending Dr. Amos's sign-off. Wording from the Ibà service (iba-natlas questions.py). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Are you too weak to sit up or stand without help?'**
  String get msg_q_too_weak;

  /// Ink carries on past the text the app could read on this line.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read the end of {where}. Please check it or retake the photo.'**
  String msg_line_end_unclear(String where);

  /// One-word camera cue: move the phone toward the top of the page (its top edge is cut off).
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get cueHigher;

  /// One-word camera cue: move the phone toward the bottom of the page.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get cueLower;

  /// One-word camera cue: move the phone left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get cueLeft;

  /// One-word camera cue: move the phone right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get cueRight;

  /// One-word camera cue: the page fits; keep the phone still for the photo.
  ///
  /// In en, this message translates to:
  /// **'Hold still'**
  String get cueHoldStill;

  /// One-word camera cue: the page is small in view; bring the phone closer.
  ///
  /// In en, this message translates to:
  /// **'Closer'**
  String get cueCloser;

  /// One-word camera cue: the page is bigger than the view; lift the phone further away.
  ///
  /// In en, this message translates to:
  /// **'Further'**
  String get cueFurther;

  /// One-word camera cue: too dark.
  ///
  /// In en, this message translates to:
  /// **'More light'**
  String get cueMoreLight;

  /// One-word camera cue: no page in view.
  ///
  /// In en, this message translates to:
  /// **'No page'**
  String get cueNoPage;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String stepOf(int n, int total);

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguageTitle;

  /// No description provided for @chooseLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Magana will speak to you in this language. You can change it any time from the Home screen.'**
  String get chooseLanguageBody;

  /// No description provided for @languageHearsHint.
  ///
  /// In en, this message translates to:
  /// **'Each option is read aloud in its own language when you touch it.'**
  String get languageHearsHint;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Spoken in each language's own voice when its option is touched during onboarding.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @ageTitle.
  ///
  /// In en, this message translates to:
  /// **'How old are you?'**
  String get ageTitle;

  /// No description provided for @ageBody.
  ///
  /// In en, this message translates to:
  /// **'We ask so Magana is safe and right for you.'**
  String get ageBody;

  /// No description provided for @ageAdult.
  ///
  /// In en, this message translates to:
  /// **'I am 18 or older'**
  String get ageAdult;

  /// No description provided for @ageAdultDetail.
  ///
  /// In en, this message translates to:
  /// **'Use everything in Magana, including health and money papers.'**
  String get ageAdultDetail;

  /// No description provided for @ageTeen.
  ///
  /// In en, this message translates to:
  /// **'I am 13 to 17'**
  String get ageTeen;

  /// No description provided for @ageTeenDetail.
  ///
  /// In en, this message translates to:
  /// **'A parent, guardian or teacher agrees first. Magana helps with school subjects only.'**
  String get ageTeenDetail;

  /// No description provided for @ageChild.
  ///
  /// In en, this message translates to:
  /// **'I am under 13'**
  String get ageChild;

  /// No description provided for @ageChildDetail.
  ///
  /// In en, this message translates to:
  /// **'Your teacher will use Magana with you in class.'**
  String get ageChildDetail;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Photos of your pages are deleted after reading. We never share your details.'**
  String get privacyNote;

  /// No description provided for @hearAgain.
  ///
  /// In en, this message translates to:
  /// **'Hear this page again'**
  String get hearAgain;

  /// No description provided for @readyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready'**
  String get readyTitle;

  /// No description provided for @readyBody.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone over any printed page and Magana will read it to you.'**
  String get readyBody;

  /// No description provided for @startLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask a parent, guardian or teacher'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'Please read or listen to this together.'**
  String get consentBody;

  /// No description provided for @consentPoint1.
  ///
  /// In en, this message translates to:
  /// **'Magana helps with school subjects only.'**
  String get consentPoint1;

  /// No description provided for @consentPoint2.
  ///
  /// In en, this message translates to:
  /// **'No health or money papers, no WhatsApp and no open chat.'**
  String get consentPoint2;

  /// No description provided for @consentPoint3.
  ///
  /// In en, this message translates to:
  /// **'Photos are deleted after reading.'**
  String get consentPoint3;

  /// No description provided for @consentConfirm.
  ///
  /// In en, this message translates to:
  /// **'I am the parent, guardian or teacher, and I agree'**
  String get consentConfirm;

  /// No description provided for @classroomTitle.
  ///
  /// In en, this message translates to:
  /// **'Magana in class'**
  String get classroomTitle;

  /// No description provided for @classroomBody.
  ///
  /// In en, this message translates to:
  /// **'Your teacher starts Magana with you in class. When the lesson ends, close the app.'**
  String get classroomBody;

  /// No description provided for @classroomStart.
  ///
  /// In en, this message translates to:
  /// **'Teacher: start the class session'**
  String get classroomStart;

  /// No description provided for @classroomConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you the teacher?'**
  String get classroomConfirmTitle;

  /// No description provided for @classroomConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, start the session'**
  String get classroomConfirmYes;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @msg_unknown_tier.
  ///
  /// In en, this message translates to:
  /// **'Please set up Magana again: your age group wasn\'t recognised.'**
  String get msg_unknown_tier;

  /// No description provided for @readPageSubtitleSchool.
  ///
  /// In en, this message translates to:
  /// **'Schoolwork, notes, textbooks and tests'**
  String get readPageSubtitleSchool;

  /// No description provided for @everydaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Health and money papers · 18+'**
  String get everydaySubtitle;

  /// No description provided for @paperMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine label'**
  String get paperMedicine;

  /// No description provided for @paperMedicineDetail.
  ///
  /// In en, this message translates to:
  /// **'Labels and prescriptions'**
  String get paperMedicineDetail;

  /// No description provided for @paperReport.
  ///
  /// In en, this message translates to:
  /// **'Medical report'**
  String get paperReport;

  /// No description provided for @paperReportDetail.
  ///
  /// In en, this message translates to:
  /// **'Test results and discharge notes'**
  String get paperReportDetail;

  /// No description provided for @paperStatement.
  ///
  /// In en, this message translates to:
  /// **'Bank statement'**
  String get paperStatement;

  /// No description provided for @paperStatementDetail.
  ///
  /// In en, this message translates to:
  /// **'Statements, receipts and bills'**
  String get paperStatementDetail;

  /// No description provided for @talkToNurse.
  ///
  /// In en, this message translates to:
  /// **'Talk to a nurse'**
  String get talkToNurse;

  /// No description provided for @talkToNurseDetail.
  ///
  /// In en, this message translates to:
  /// **'With the Ibà quick check'**
  String get talkToNurseDetail;

  /// No description provided for @everydayPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Private papers are read on your phone and not saved. Magana never asks for your PIN or password.'**
  String get everydayPrivacy;

  /// No description provided for @readExactly.
  ///
  /// In en, this message translates to:
  /// **'Read exactly as printed'**
  String get readExactly;

  /// No description provided for @noteMedicine.
  ///
  /// In en, this message translates to:
  /// **'Magana reads what is printed. It does not give medical advice. If anything on the label is unclear, ask your pharmacist before taking it.'**
  String get noteMedicine;

  /// No description provided for @noteReport.
  ///
  /// In en, this message translates to:
  /// **'Numbers and ranges are read exactly as printed. Magana does not interpret results: only your health worker can explain what they mean for you.'**
  String get noteReport;

  /// No description provided for @noteStatement.
  ///
  /// In en, this message translates to:
  /// **'Amounts are read exactly as printed. This statement is not saved. Magana never asks for your PIN or password. If an amount is unclear, check it with your bank or a trusted person.'**
  String get noteStatement;

  /// No description provided for @askPharmacistOrNurse.
  ///
  /// In en, this message translates to:
  /// **'Ask a pharmacist or nurse'**
  String get askPharmacistOrNurse;

  /// No description provided for @adultsOnly.
  ///
  /// In en, this message translates to:
  /// **'This is for adults (18 and over).'**
  String get adultsOnly;

  /// No description provided for @healthWorkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk to a health worker'**
  String get healthWorkerTitle;

  /// No description provided for @healthWorkerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A nurse or pharmacist calls you back'**
  String get healthWorkerSubtitle;

  /// No description provided for @helpWithTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you need help with?'**
  String get helpWithTitle;

  /// No description provided for @reasonMedicine.
  ///
  /// In en, this message translates to:
  /// **'Understanding my medicine'**
  String get reasonMedicine;

  /// No description provided for @reasonResults.
  ///
  /// In en, this message translates to:
  /// **'Understanding my results'**
  String get reasonResults;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// No description provided for @callLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language for the call'**
  String get callLanguage;

  /// No description provided for @answerIbaFirst.
  ///
  /// In en, this message translates to:
  /// **'Answer a few quick questions first (Ibà)'**
  String get answerIbaFirst;

  /// No description provided for @requestCallback.
  ///
  /// In en, this message translates to:
  /// **'Request a call back'**
  String get requestCallback;

  /// No description provided for @emergencyBold.
  ///
  /// In en, this message translates to:
  /// **'Emergency?'**
  String get emergencyBold;

  /// No description provided for @emergencyText.
  ///
  /// In en, this message translates to:
  /// **'Do not wait for a call back. Call 112 now.'**
  String get emergencyText;

  /// No description provided for @call112.
  ///
  /// In en, this message translates to:
  /// **'Call 112'**
  String get call112;

  /// No description provided for @quickCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick health check'**
  String get quickCheckTitle;

  /// No description provided for @quickCheckProgress.
  ///
  /// In en, this message translates to:
  /// **'Powered by Ibà · question {n} of {total}'**
  String quickCheckProgress(int n, int total);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @moreDays.
  ///
  /// In en, this message translates to:
  /// **'One more day'**
  String get moreDays;

  /// No description provided for @fewerDays.
  ///
  /// In en, this message translates to:
  /// **'One day fewer'**
  String get fewerDays;

  /// No description provided for @nextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextLabel;

  /// No description provided for @quickCheckNote.
  ///
  /// In en, this message translates to:
  /// **'Your answers help the nurse decide how soon to call you. Ibà does not diagnose. If you have danger signs, Magana tells you to go to a clinic now.'**
  String get quickCheckNote;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your result'**
  String get resultTitle;

  /// No description provided for @checkingAnswers.
  ///
  /// In en, this message translates to:
  /// **'Checking your answers.'**
  String get checkingAnswers;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backHome;

  /// No description provided for @msg_callback_booked.
  ///
  /// In en, this message translates to:
  /// **'Your call back is booked. A nurse or pharmacist will call you.'**
  String get msg_callback_booked;

  /// Said when no nurse desk is connected: never promise a call nobody will make.
  ///
  /// In en, this message translates to:
  /// **'Call backs are not available yet. If you need help now, go to a clinic or call 112.'**
  String get msg_callback_unavailable;

  /// Shown when Ibà is unreachable and Magana asks its own danger-sign questions.
  ///
  /// In en, this message translates to:
  /// **'Built-in safety check · question {n} of {total}'**
  String quickCheckProgressFallback(int n, int total);

  /// CLINICAL DRAFT. Quick-check result before any call is booked: never says a call is coming.
  ///
  /// In en, this message translates to:
  /// **'A nurse should call you within 2 hours. Request a call back now. If you get worse, go to a clinic or call 112.'**
  String get resultUrgent;

  /// CLINICAL DRAFT. Quick-check result before any call is booked: never says a call is coming.
  ///
  /// In en, this message translates to:
  /// **'A nurse can call you back during working hours. Request a call back. If you get worse, go to a clinic or call 112.'**
  String get resultRoutine;

  /// No description provided for @quizTitle.
  ///
  /// In en, this message translates to:
  /// **'Biology practice'**
  String get quizTitle;

  /// No description provided for @quizProgress.
  ///
  /// In en, this message translates to:
  /// **'WAEC-style · Question {n} of {total}'**
  String quizProgress(int n, int total);

  /// No description provided for @quizScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'{correct} right out of {answered} answered'**
  String quizScoreLabel(int correct, int answered);

  /// No description provided for @quizSayAnswer.
  ///
  /// In en, this message translates to:
  /// **'Say A, B, C or D'**
  String get quizSayAnswer;

  /// No description provided for @quizListening.
  ///
  /// In en, this message translates to:
  /// **'Listening… Tap to stop'**
  String get quizListening;

  /// No description provided for @quizCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct! You chose {letter}.'**
  String quizCorrect(String letter);

  /// answer is the letter and option text, e.g. 'B, Iodine solution'
  ///
  /// In en, this message translates to:
  /// **'Not quite. You chose {letter}. The answer is {answer}.'**
  String quizWrong(String letter, String answer);

  /// Never guess: repeat what was heard and ask again
  ///
  /// In en, this message translates to:
  /// **'I heard “{heard}”. Please say A, B, C or D.'**
  String quizUnclear(String heard);

  /// No description provided for @quizNothingHeard.
  ///
  /// In en, this message translates to:
  /// **'I did not hear an answer. Say A, B, C or D, or double tap an answer.'**
  String get quizNothingHeard;

  /// No description provided for @quizNoVoice.
  ///
  /// In en, this message translates to:
  /// **'Spoken answers are not available on this phone. Double tap an answer instead.'**
  String get quizNoVoice;

  /// No description provided for @quizRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat question'**
  String get quizRepeat;

  /// No description provided for @quizNext.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get quizNext;

  /// No description provided for @quizFinish.
  ///
  /// In en, this message translates to:
  /// **'See my result'**
  String get quizFinish;

  /// No description provided for @quizYourAnswerRight.
  ///
  /// In en, this message translates to:
  /// **'your answer, correct'**
  String get quizYourAnswerRight;

  /// No description provided for @quizYourAnswerWrong.
  ///
  /// In en, this message translates to:
  /// **'your answer, not correct'**
  String get quizYourAnswerWrong;

  /// No description provided for @quizRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'correct answer'**
  String get quizRightAnswer;

  /// No description provided for @quizResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice finished'**
  String get quizResultTitle;

  /// No description provided for @quizResult.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} out of {total} right.'**
  String quizResult(int correct, int total);

  /// No description provided for @quizAgain.
  ///
  /// In en, this message translates to:
  /// **'Practise again'**
  String get quizAgain;

  /// No description provided for @quizSource.
  ///
  /// In en, this message translates to:
  /// **'Questions written by the Magana team in the style of WAEC Biology. They are not past questions. The questions are in English.'**
  String get quizSource;
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
