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

  /// The web app or portal couldn't reach the API although the browser is online: the EC2 server is stopped or restarting.
  ///
  /// In en, this message translates to:
  /// **'Magana’s server is sleeping. Please try again later.'**
  String get serverSleeping;

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

  /// Said instead of a word with a digit inside on a Hausa, Yorùbá or Igbo page: the digit is an unclear letter, never a number.
  ///
  /// In en, this message translates to:
  /// **'unclear letter'**
  String get unclearLetter;

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
  /// **'I couldn\'t explain this page safely. Here it is read again.'**
  String get msg_numbers_unconfirmed;

  /// No description provided for @msg_class_code_wrong.
  ///
  /// In en, this message translates to:
  /// **'That class code isn\'t right. Check it with your teacher.'**
  String get msg_class_code_wrong;

  /// No description provided for @msg_code_locked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Please wait 5 minutes, then try again.'**
  String get msg_code_locked;

  /// No description provided for @msg_teacher_code_needed.
  ///
  /// In en, this message translates to:
  /// **'Only your teacher can move you to another class. Ask them to enter their teacher code.'**
  String get msg_teacher_code_needed;

  /// No description provided for @msg_teacher_code_wrong.
  ///
  /// In en, this message translates to:
  /// **'That teacher code isn\'t right. Ask your teacher to check it.'**
  String get msg_teacher_code_wrong;

  /// No description provided for @msg_class_has_no_accounts.
  ///
  /// In en, this message translates to:
  /// **'This class only has lessons your teacher runs. Ask your teacher.'**
  String get msg_class_has_no_accounts;

  /// No description provided for @msg_not_linked.
  ///
  /// In en, this message translates to:
  /// **'This phone isn\'t in a class now. You can still read pages.'**
  String get msg_not_linked;

  /// No description provided for @msg_class_joined.
  ///
  /// In en, this message translates to:
  /// **'You\'re in the class.'**
  String get msg_class_joined;

  /// No description provided for @msg_class_changed.
  ///
  /// In en, this message translates to:
  /// **'Your class has changed.'**
  String get msg_class_changed;

  /// No description provided for @msg_explain_wrong_language.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t explain this in your language, so I\'ll read the page exactly instead.'**
  String get msg_explain_wrong_language;

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

  /// No description provided for @quizProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {n} of {total}'**
  String quizProgress(int n, int total);

  /// No description provided for @quizScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'{correct} right out of {answered} answered'**
  String quizScoreLabel(int correct, int answered);

  /// letters is this question's letters, e.g. 'A, B or C' (two or three for primary classes)
  ///
  /// In en, this message translates to:
  /// **'Say {letters}'**
  String quizSayAnswer(String letters);

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

  /// No description provided for @quizUnclear.
  ///
  /// In en, this message translates to:
  /// **'I heard “{heard}”. Please say {letters}.'**
  String quizUnclear(String heard, String letters);

  /// No description provided for @quizNothingHeard.
  ///
  /// In en, this message translates to:
  /// **'I did not hear an answer. Say {letters}, or double tap an answer.'**
  String quizNothingHeard(String letters);

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

  /// No description provided for @skillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short spoken lessons, at your pace'**
  String get skillsSubtitle;

  /// No description provided for @nextLesson.
  ///
  /// In en, this message translates to:
  /// **'Next lesson · {minutes} min'**
  String nextLesson(int minutes);

  /// No description provided for @playLesson.
  ///
  /// In en, this message translates to:
  /// **'Play lesson'**
  String get playLesson;

  /// No description provided for @pauseLesson.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseLesson;

  /// No description provided for @practiseNow.
  ///
  /// In en, this message translates to:
  /// **'Practise now'**
  String get practiseNow;

  /// No description provided for @lessonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lessonDone;

  /// No description provided for @lessonStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String lessonStepOf(int step, int total);

  /// No description provided for @lessonNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get lessonNotStarted;

  /// No description provided for @allLessonsDone.
  ///
  /// In en, this message translates to:
  /// **'You have finished every lesson. Well done!'**
  String get allLessonsDone;

  /// No description provided for @practiseWithChampion.
  ///
  /// In en, this message translates to:
  /// **'Practise with a Magana Champion'**
  String get practiseWithChampion;

  /// No description provided for @skillsNote.
  ///
  /// In en, this message translates to:
  /// **'Sample lessons written by the Magana team, to be reviewed by rehabilitation trainers. Lessons are in English for now.'**
  String get skillsNote;

  /// No description provided for @previousStep.
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get previousStep;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get nextStep;

  /// No description provided for @lessonFinished.
  ///
  /// In en, this message translates to:
  /// **'Lesson finished.'**
  String get lessonFinished;

  /// No description provided for @scoreTitle.
  ///
  /// In en, this message translates to:
  /// **'My Independence Score'**
  String get scoreTitle;

  /// No description provided for @scoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks you finished in Magana'**
  String get scoreSubtitle;

  /// No description provided for @scoreOutOf.
  ///
  /// In en, this message translates to:
  /// **'{score} out of 100'**
  String scoreOutOf(int score);

  /// No description provided for @scoreByArea.
  ///
  /// In en, this message translates to:
  /// **'By area'**
  String get scoreByArea;

  /// No description provided for @areaLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get areaLearning;

  /// No description provided for @areaHealth.
  ///
  /// In en, this message translates to:
  /// **'Health papers'**
  String get areaHealth;

  /// No description provided for @areaMoney.
  ///
  /// In en, this message translates to:
  /// **'Money and letters'**
  String get areaMoney;

  /// No description provided for @areaSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get areaSkills;

  /// No description provided for @areaScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'{area}: {score} out of 100'**
  String areaScoreLabel(String area, int score);

  /// No description provided for @scoreThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get scoreThisWeek;

  /// No description provided for @scoreNothingThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet this week. Read a page or take a quiz to start.'**
  String get scoreNothingThisWeek;

  /// No description provided for @weekReadSchool.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page of schoolwork read} other{{count} pages of schoolwork read}}'**
  String weekReadSchool(num count);

  /// No description provided for @weekReadMedicine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medicine label read} other{{count} medicine labels read}}'**
  String weekReadMedicine(num count);

  /// No description provided for @weekReadReport.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medical report read} other{{count} medical reports read}}'**
  String weekReadReport(num count);

  /// No description provided for @weekReadStatement.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bank statement or receipt read} other{{count} bank statements or receipts read}}'**
  String weekReadStatement(num count);

  /// No description provided for @weekQuiz.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 quiz finished} other{{count} quizzes finished}}'**
  String weekQuiz(num count);

  /// No description provided for @weekLesson.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 lesson finished} other{{count} lessons finished}}'**
  String weekLesson(num count);

  /// No description provided for @scoreHow.
  ///
  /// In en, this message translates to:
  /// **'Your score counts real tasks you finished in Magana in the last 30 days. It stays on this phone; only you see it.'**
  String get scoreHow;

  /// No description provided for @championsTitle.
  ///
  /// In en, this message translates to:
  /// **'Magana Champions'**
  String get championsTitle;

  /// No description provided for @championsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn from people who have been there'**
  String get championsSubtitle;

  /// No description provided for @championSample.
  ///
  /// In en, this message translates to:
  /// **'Sample profile'**
  String get championSample;

  /// No description provided for @championDetail.
  ///
  /// In en, this message translates to:
  /// **'Blind since age 12 · Kano · Hausa, English'**
  String get championDetail;

  /// No description provided for @championNotYet.
  ///
  /// In en, this message translates to:
  /// **'This is a sample profile. Champions will be matched to you through partner organisations. Calls are not available yet.'**
  String get championNotYet;

  /// No description provided for @becomeChampion.
  ///
  /// In en, this message translates to:
  /// **'Become a Champion'**
  String get becomeChampion;

  /// No description provided for @becomeChampionBody.
  ///
  /// In en, this message translates to:
  /// **'Help others in your community and earn a certificate.'**
  String get becomeChampionBody;

  /// No description provided for @champStepBasics.
  ///
  /// In en, this message translates to:
  /// **'Finish Phone basics'**
  String get champStepBasics;

  /// No description provided for @champStepPhotos.
  ///
  /// In en, this message translates to:
  /// **'Finish Taking clear photos'**
  String get champStepPhotos;

  /// No description provided for @champStepScore.
  ///
  /// In en, this message translates to:
  /// **'Reach an Independence Score of 60'**
  String get champStepScore;

  /// No description provided for @champStepTraining.
  ///
  /// In en, this message translates to:
  /// **'Join a 2-hour Champion training'**
  String get champStepTraining;

  /// No description provided for @champStepHelp.
  ///
  /// In en, this message translates to:
  /// **'Help your first 3 people'**
  String get champStepHelp;

  /// No description provided for @stepDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get stepDone;

  /// No description provided for @stepNotDone.
  ///
  /// In en, this message translates to:
  /// **'not done yet'**
  String get stepNotDone;

  /// No description provided for @championsPartnerNote.
  ///
  /// In en, this message translates to:
  /// **'Champion training will be run with partner organisations. It is not open yet.'**
  String get championsPartnerNote;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved readings, kept for 30 days'**
  String get librarySubtitle;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. After Magana reads a page, choose Save to my library.'**
  String get libraryEmpty;

  /// No description provided for @libraryDeletesIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{deleted today} =1{deleted tomorrow} other{deleted in {count} days}}'**
  String libraryDeletesIn(num count);

  /// No description provided for @librarySavedOn.
  ///
  /// In en, this message translates to:
  /// **'Saved {date}'**
  String librarySavedOn(String date);

  /// No description provided for @libraryPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Saved readings stay on this phone and are deleted after 30 days. Photos are never saved.'**
  String get libraryPrivacy;

  /// No description provided for @saveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to my library'**
  String get saveToLibrary;

  /// No description provided for @savedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Saved to my library. It stays on this phone for 30 days.'**
  String get savedToLibrary;

  /// No description provided for @deleteFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Delete from my library'**
  String get deleteFromLibrary;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this reading from your library?'**
  String get deleteConfirm;

  /// No description provided for @deleteYes.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteYes;

  /// No description provided for @deletedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Deleted from your library.'**
  String get deletedFromLibrary;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s medicines'**
  String get remindersTitle;

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Times set with your pharmacist'**
  String get remindersSubtitle;

  /// No description provided for @remindersCard.
  ///
  /// In en, this message translates to:
  /// **'Medicine reminders'**
  String get remindersCard;

  /// No description provided for @remindersCardDetail.
  ///
  /// In en, this message translates to:
  /// **'Times for your medicines'**
  String get remindersCardDetail;

  /// No description provided for @remindersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet. Add the times your pharmacist or doctor gave you.'**
  String get remindersEmpty;

  /// No description provided for @doseTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get doseTaken;

  /// No description provided for @doseDue.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get doseDue;

  /// No description provided for @doseLater.
  ///
  /// In en, this message translates to:
  /// **'Later today'**
  String get doseLater;

  /// medicine and amount are exactly what the user typed
  ///
  /// In en, this message translates to:
  /// **'{time}, {state}. {medicine}. {amount}'**
  String doseLabel(String time, String state, String medicine, String amount);

  /// No description provided for @iTookIt.
  ///
  /// In en, this message translates to:
  /// **'I\'ve taken it'**
  String get iTookIt;

  /// No description provided for @remindLater.
  ///
  /// In en, this message translates to:
  /// **'Remind in 15 min'**
  String get remindLater;

  /// No description provided for @remindLaterSet.
  ///
  /// In en, this message translates to:
  /// **'I will remind you again in 15 minutes.'**
  String get remindLaterSet;

  /// No description provided for @markedTaken.
  ///
  /// In en, this message translates to:
  /// **'Marked as taken.'**
  String get markedTaken;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder'**
  String get addReminder;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name, as on the label'**
  String get medicineName;

  /// No description provided for @medicineAmount.
  ///
  /// In en, this message translates to:
  /// **'How much, as your pharmacist said (for example, 2 tablets)'**
  String get medicineAmount;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reminderTime;

  /// No description provided for @earlierHour.
  ///
  /// In en, this message translates to:
  /// **'One hour earlier'**
  String get earlierHour;

  /// No description provided for @laterHour.
  ///
  /// In en, this message translates to:
  /// **'One hour later'**
  String get laterHour;

  /// No description provided for @earlierMinutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes earlier'**
  String get earlierMinutes;

  /// No description provided for @laterMinutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes later'**
  String get laterMinutes;

  /// No description provided for @saveReminder.
  ///
  /// In en, this message translates to:
  /// **'Save reminder'**
  String get saveReminder;

  /// No description provided for @medicineNameNeeded.
  ///
  /// In en, this message translates to:
  /// **'Type the medicine name first.'**
  String get medicineNameNeeded;

  /// No description provided for @reminderSaved.
  ///
  /// In en, this message translates to:
  /// **'Reminder saved for {time}.'**
  String reminderSaved(String time);

  /// No description provided for @deleteReminder.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder'**
  String get deleteReminder;

  /// No description provided for @deleteReminderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the {time} reminder for {medicine}?'**
  String deleteReminderConfirm(String time, String medicine);

  /// No description provided for @reminderNotice.
  ///
  /// In en, this message translates to:
  /// **'Your phone rings and vibrates at each time, as a notification. Magana reminds you at the times you set. It never changes a dose.'**
  String get reminderNotice;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Magana, so reminders only show when Magana is open. You can turn them on in your phone\'s settings.'**
  String get notificationsOff;

  /// No description provided for @missedDose.
  ///
  /// In en, this message translates to:
  /// **'Missed a dose? Ask a pharmacist'**
  String get missedDose;

  /// No description provided for @reminderNotifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for your medicine'**
  String get reminderNotifyTitle;

  /// No description provided for @exactTitle.
  ///
  /// In en, this message translates to:
  /// **'Ring on time?'**
  String get exactTitle;

  /// No description provided for @exactBody.
  ///
  /// In en, this message translates to:
  /// **'To ring at the exact minute, your phone needs to allow Magana to set alarms and reminders. The next screen has one switch: turn it on, then go back.'**
  String get exactBody;

  /// No description provided for @exactOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the setting'**
  String get exactOpen;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @remindersMayBeLate.
  ///
  /// In en, this message translates to:
  /// **'On this phone, reminders may ring up to an hour late. To ring on time, allow alarms and reminders for Magana.'**
  String get remindersMayBeLate;

  /// No description provided for @allowOnTime.
  ///
  /// In en, this message translates to:
  /// **'Allow on-time reminders'**
  String get allowOnTime;

  /// CLINICAL DRAFT, pending Dr. Amos: asked so a blind user can answer
  ///
  /// In en, this message translates to:
  /// **'Have you felt or tasted blood, or has anyone told you that you are bleeding, from your nose, gums, vomit or stool?'**
  String get msg_q_bleeding_no_sight;

  /// No description provided for @msg_q_yellow_eyes_no_sight.
  ///
  /// In en, this message translates to:
  /// **'Has anyone told you that your eyes or skin look yellow?'**
  String get msg_q_yellow_eyes_no_sight;

  /// CLINICAL DRAFT, pending Dr. Amos
  ///
  /// In en, this message translates to:
  /// **'Has anyone told you that you look very pale? Do you feel very weak, dizzy or out of breath when you stand?'**
  String get msg_q_very_pale_no_sight;

  /// CLINICAL DRAFT, pending Dr. Amos
  ///
  /// In en, this message translates to:
  /// **'Has someone near you seen that your urine is very dark, like cola or tea?'**
  String get msg_q_dark_urine_no_sight;

  /// CLINICAL DRAFT, pending Dr. Amos: a danger sign answered I can't tell
  ///
  /// In en, this message translates to:
  /// **'Please ask someone near you to check, or go to a clinic.'**
  String get msg_ask_someone_to_check;

  /// CLINICAL DRAFT, pending Dr. Amos: never counts as No
  ///
  /// In en, this message translates to:
  /// **'I can\'t tell'**
  String get cantTell;

  /// No description provided for @appLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguageTitle;

  /// No description provided for @languageSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Menus, buttons, help and Magana\'s voice all switch to the language you choose.'**
  String get languageSheetBody;

  /// No description provided for @languageVoiceTip.
  ///
  /// In en, this message translates to:
  /// **'You can also say “change language to Igbo” after pressing Speak a command on Home.'**
  String get languageVoiceTip;

  /// No description provided for @useLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use {language}'**
  String useLanguage(String language);

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build})'**
  String settingsVersion(String version, String build);

  /// No description provided for @settingsVersionNote.
  ///
  /// In en, this message translates to:
  /// **'Tell the Magana team this version when you report a problem.'**
  String get settingsVersionNote;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// No description provided for @reportHow.
  ///
  /// In en, this message translates to:
  /// **'Tell the Magana team three things: the name of the screen, what you did, and what Magana said.'**
  String get reportHow;

  /// No description provided for @speakCommand.
  ///
  /// In en, this message translates to:
  /// **'Speak a command'**
  String get speakCommand;

  /// No description provided for @listeningCommand.
  ///
  /// In en, this message translates to:
  /// **'Listening… Tap to stop'**
  String get listeningCommand;

  /// No description provided for @commandNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'I heard “{heard}”, but I don\'t know that command. Say help to hear what you can say.'**
  String commandNotUnderstood(String heard);

  /// No description provided for @commandNothingHeard.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t hear a command. Try again, or say help.'**
  String get commandNothingHeard;

  /// No description provided for @commandHelp.
  ///
  /// In en, this message translates to:
  /// **'You can say: {commands}. Say commands in English for now.'**
  String commandHelp(String commands);

  /// No description provided for @changeLanguageCommand.
  ///
  /// In en, this message translates to:
  /// **'change language'**
  String get changeLanguageCommand;

  /// No description provided for @voiceCommandsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice commands are not available on this phone. Use the buttons instead.'**
  String get voiceCommandsUnavailable;

  /// No description provided for @explainTitle.
  ///
  /// In en, this message translates to:
  /// **'Explain'**
  String get explainTitle;

  /// No description provided for @explainFrom.
  ///
  /// In en, this message translates to:
  /// **'From: {source}'**
  String explainFrom(String source);

  /// No description provided for @explainPreviewBanner.
  ///
  /// In en, this message translates to:
  /// **'Preview. N-ATLAS, which will explain pages in your language, is not connected yet. For now Magana reads the page text exactly as printed.'**
  String get explainPreviewBanner;

  /// No description provided for @answerLanguage.
  ///
  /// In en, this message translates to:
  /// **'Answer language, currently {language}'**
  String answerLanguage(String language);

  /// No description provided for @youSaid.
  ///
  /// In en, this message translates to:
  /// **'You said'**
  String get youSaid;

  /// No description provided for @basedOnPage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Based on: 1 line of your page} other{Based on: {count} lines and rows of your page}}'**
  String basedOnPage(num count);

  /// No description provided for @readExactlyNote.
  ///
  /// In en, this message translates to:
  /// **'Numbers and words from the page are read exactly as printed.'**
  String get readExactlyNote;

  /// No description provided for @saySimpler.
  ///
  /// In en, this message translates to:
  /// **'Say it simpler'**
  String get saySimpler;

  /// No description provided for @giveExample.
  ///
  /// In en, this message translates to:
  /// **'Give an example'**
  String get giveExample;

  /// No description provided for @explainDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Magana can make mistakes. Check important answers with your teacher.'**
  String get explainDisclaimer;

  /// No description provided for @askAQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get askAQuestion;

  /// No description provided for @explainNoPage.
  ///
  /// In en, this message translates to:
  /// **'Explanations are about a page. Read a page first, then choose Explain this.'**
  String get explainNoPage;

  /// No description provided for @explainThis.
  ///
  /// In en, this message translates to:
  /// **'Explain this'**
  String get explainThis;

  /// No description provided for @explainQuestionPreview.
  ///
  /// In en, this message translates to:
  /// **'When N-ATLAS is connected, Magana will answer your question from this page. For now, here is the page.'**
  String get explainQuestionPreview;

  /// No description provided for @msg_explain_preview.
  ///
  /// In en, this message translates to:
  /// **'This is a preview. Explanations in your language come when N-ATLAS is connected. Here is the page, read exactly as printed.'**
  String get msg_explain_preview;

  /// No description provided for @msg_explained.
  ///
  /// In en, this message translates to:
  /// **'Here is the explanation.'**
  String get msg_explained;

  /// No description provided for @msg_explain_bad_source.
  ///
  /// In en, this message translates to:
  /// **'There is no page text to explain. Please read a page first.'**
  String get msg_explain_bad_source;

  /// No description provided for @jumpWithinPage.
  ///
  /// In en, this message translates to:
  /// **'Jump within page'**
  String get jumpWithinPage;

  /// No description provided for @jumpStart.
  ///
  /// In en, this message translates to:
  /// **'Start of the page'**
  String get jumpStart;

  /// No description provided for @jumpTable.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String jumpTable(int number);

  /// No description provided for @jumpWarnings.
  ///
  /// In en, this message translates to:
  /// **'Next thing I\'m not sure about'**
  String get jumpWarnings;

  /// No description provided for @jumpNotYet.
  ///
  /// In en, this message translates to:
  /// **'Jumping to diagrams is not available yet.'**
  String get jumpNotYet;

  /// No description provided for @paperLetter.
  ///
  /// In en, this message translates to:
  /// **'Letters & forms'**
  String get paperLetter;

  /// No description provided for @paperLetterDetail.
  ///
  /// In en, this message translates to:
  /// **'Notices, forms, religious texts'**
  String get paperLetterDetail;

  /// No description provided for @noteLetter.
  ///
  /// In en, this message translates to:
  /// **'Magana reads what is printed. It does not give legal or financial advice, and never asks for your PIN or password.'**
  String get noteLetter;

  /// No description provided for @readAnyPaper.
  ///
  /// In en, this message translates to:
  /// **'Read any paper'**
  String get readAnyPaper;

  /// No description provided for @readAnyPaperDetail.
  ///
  /// In en, this message translates to:
  /// **'Magana works out what kind of paper it is'**
  String get readAnyPaperDetail;

  /// No description provided for @detectedPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper type: {paper}.'**
  String detectedPaper(String paper);

  /// No description provided for @weekReadLetter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 letter or form read} other{{count} letters or forms read}}'**
  String weekReadLetter(num count);

  /// No description provided for @readAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get readAgain;

  /// No description provided for @askAboutResult.
  ///
  /// In en, this message translates to:
  /// **'What does this mean?'**
  String get askAboutResult;

  /// No description provided for @resultAnswer.
  ///
  /// In en, this message translates to:
  /// **'Only your health worker can explain what this result means for you. I can save your question for your next visit, or ask a nurse to call you.'**
  String get resultAnswer;

  /// No description provided for @youAsked.
  ///
  /// In en, this message translates to:
  /// **'You asked: “{question}”'**
  String youAsked(String question);

  /// No description provided for @saveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Save question'**
  String get saveQuestion;

  /// No description provided for @questionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. You will find it in Talk to a health worker.'**
  String get questionSaved;

  /// No description provided for @askANurse.
  ///
  /// In en, this message translates to:
  /// **'Ask a nurse'**
  String get askANurse;

  /// No description provided for @savedQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Questions for your next visit'**
  String get savedQuestionsTitle;

  /// No description provided for @removeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove: {question}'**
  String removeQuestion(String question);

  /// No description provided for @questionAbout.
  ///
  /// In en, this message translates to:
  /// **'{question} (about {where})'**
  String questionAbout(String question, String where);

  /// No description provided for @fromTheStatement.
  ///
  /// In en, this message translates to:
  /// **'From the statement, exactly as printed'**
  String get fromTheStatement;

  /// No description provided for @findTransaction.
  ///
  /// In en, this message translates to:
  /// **'Find a transaction'**
  String get findTransaction;

  /// No description provided for @findPrompt.
  ///
  /// In en, this message translates to:
  /// **'Say or type a word, date or amount from the transaction.'**
  String get findPrompt;

  /// No description provided for @findField.
  ///
  /// In en, this message translates to:
  /// **'Word, date or amount'**
  String get findField;

  /// No description provided for @findSearch.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findSearch;

  /// No description provided for @findSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak instead'**
  String get findSpeak;

  /// No description provided for @findNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No row has “{query}”.'**
  String findNoMatch(String query);

  /// No description provided for @sayYesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Say yes, no, or I can\'t tell'**
  String get sayYesOrNo;

  /// No description provided for @voiceAnswerUnclear.
  ///
  /// In en, this message translates to:
  /// **'I heard “{heard}”. Please say yes, no, or I can\'t tell.'**
  String voiceAnswerUnclear(String heard);

  /// No description provided for @scoreUpSince.
  ///
  /// In en, this message translates to:
  /// **'Up from {start} when you started, {weeks, plural, =1{1 week ago} other{{weeks} weeks ago}}'**
  String scoreUpSince(int start, num weeks);

  /// No description provided for @scoreSince.
  ///
  /// In en, this message translates to:
  /// **'{start} when you started, {weeks, plural, =1{1 week ago} other{{weeks} weeks ago}}'**
  String scoreSince(int start, num weeks);

  /// No description provided for @shareScore.
  ///
  /// In en, this message translates to:
  /// **'Share my score with my teacher'**
  String get shareScore;

  /// No description provided for @shareScoreNote.
  ///
  /// In en, this message translates to:
  /// **'Your teacher will see your score, never your pages or questions, once your class is connected to the Magana teacher portal.'**
  String get shareScoreNote;

  /// CLINICAL/PRIVACY DRAFT, pending Dr. Amos: off by default
  ///
  /// In en, this message translates to:
  /// **'Say the medicine name when locked'**
  String get sayNameWhenLocked;

  /// No description provided for @sayNameNote.
  ///
  /// In en, this message translates to:
  /// **'Off: the lock screen says only “Magana reminder”. On: the lock screen shows the medicine and how much, and Magana says them aloud at each time, so people near you may see or hear them.'**
  String get sayNameNote;

  /// No description provided for @reminderGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Magana reminder'**
  String get reminderGenericTitle;

  /// No description provided for @reminderGenericBody.
  ///
  /// In en, this message translates to:
  /// **'Open Magana to hear which medicine.'**
  String get reminderGenericBody;

  /// No description provided for @msg_bad_api_key.
  ///
  /// In en, this message translates to:
  /// **'This copy of Magana can\'t reach the reading service. Please update the app.'**
  String get msg_bad_api_key;

  /// No description provided for @msg_explain_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Explanations aren\'t available right now. Here is the page, read exactly as printed.'**
  String get msg_explain_unavailable;

  /// No description provided for @msg_asr_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition on the server is not set up; the phone\'s own is used.'**
  String get msg_asr_unavailable;

  /// No description provided for @msg_audio_too_long.
  ///
  /// In en, this message translates to:
  /// **'That recording is too long. Please say a short answer.'**
  String get msg_audio_too_long;

  /// No description provided for @msg_unreadable_audio.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t hear that recording. Please try again.'**
  String get msg_unreadable_audio;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Magana'**
  String get aboutTitle;

  /// No description provided for @aboutModels.
  ///
  /// In en, this message translates to:
  /// **'Language models'**
  String get aboutModels;

  /// No description provided for @aboutModelsNote.
  ///
  /// In en, this message translates to:
  /// **'Magana uses these open models under the N-ATLaS Terms of Use, version 1.0. The credit lines below are quoted as the terms require.'**
  String get aboutModelsNote;

  /// No description provided for @aboutExplain.
  ///
  /// In en, this message translates to:
  /// **'Explanations in your language'**
  String get aboutExplain;

  /// No description provided for @aboutSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get aboutSpeech;

  /// No description provided for @openSourceLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get openSourceLicences;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Questions or problems: email {email}'**
  String aboutContact(String email);

  /// No description provided for @msg_explain_not_available.
  ///
  /// In en, this message translates to:
  /// **'Explain isn\'t available yet. Here is the page, read exactly as printed.'**
  String get msg_explain_not_available;

  /// No description provided for @quizConfirm.
  ///
  /// In en, this message translates to:
  /// **'You said {answer}. Is that right?'**
  String quizConfirm(String answer);

  /// No description provided for @quizConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, {answer}'**
  String quizConfirmYes(String answer);

  /// No description provided for @quizConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No, ask me again'**
  String get quizConfirmNo;

  /// No description provided for @quizSayYesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Say yes or no'**
  String get quizSayYesOrNo;

  /// No description provided for @quizSayAgain.
  ///
  /// In en, this message translates to:
  /// **'Please say your answer again.'**
  String get quizSayAgain;

  /// No description provided for @quizTapInstead.
  ///
  /// In en, this message translates to:
  /// **'I\'m having trouble hearing you. Please double tap your answer instead.'**
  String get quizTapInstead;

  /// No description provided for @quizSayTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'Say true or false'**
  String get quizSayTrueFalse;

  /// No description provided for @msg_too_many_requests.
  ///
  /// In en, this message translates to:
  /// **'Magana is busy right now. Please wait a minute and try again.'**
  String get msg_too_many_requests;

  /// No description provided for @remindersNeedApp.
  ///
  /// In en, this message translates to:
  /// **'Reminders need the Android or iPhone app. In a web browser Magana can\'t ring at the right time.'**
  String get remindersNeedApp;

  /// No description provided for @quizVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice answers aren\'t available on this device yet. Tap an answer instead.'**
  String get quizVoiceUnavailable;

  /// No description provided for @quizVoiceUnavailableWeb.
  ///
  /// In en, this message translates to:
  /// **'Voice answers aren\'t available on this device yet. Tap or click an answer, or press {letters} on your keyboard.'**
  String quizVoiceUnavailableWeb(String letters);

  /// No description provided for @quizKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Tap or click an answer, or press {letters} on your keyboard.'**
  String quizKeysHint(String letters);

  /// No description provided for @quizKeysHintTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'Tap or click true or false, or press A for true or B for false.'**
  String get quizKeysHintTrueFalse;

  /// No description provided for @quizTapAnswer.
  ///
  /// In en, this message translates to:
  /// **'Tap an answer.'**
  String get quizTapAnswer;

  /// Web only: the one full-screen button shown until the first press, because browsers won't speak before it.
  ///
  /// In en, this message translates to:
  /// **'Start Magana'**
  String get startMagana;

  /// No description provided for @classTitle.
  ///
  /// In en, this message translates to:
  /// **'Which class are you in?'**
  String get classTitle;

  /// No description provided for @classBody.
  ///
  /// In en, this message translates to:
  /// **'Magana picks practice questions for your class. A teacher can change it later.'**
  String get classBody;

  /// No description provided for @classNotInSchool.
  ///
  /// In en, this message translates to:
  /// **'I\'m not in school'**
  String get classNotInSchool;

  /// No description provided for @classGroupPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary school'**
  String get classGroupPrimary;

  /// No description provided for @classGroupJss.
  ///
  /// In en, this message translates to:
  /// **'Junior secondary'**
  String get classGroupJss;

  /// No description provided for @classGroupSss.
  ///
  /// In en, this message translates to:
  /// **'Senior secondary'**
  String get classGroupSss;

  /// No description provided for @classroomChooseClass.
  ///
  /// In en, this message translates to:
  /// **'Teacher: choose the class for this session'**
  String get classroomChooseClass;

  /// No description provided for @classroomNeedsClass.
  ///
  /// In en, this message translates to:
  /// **'Choose the class first.'**
  String get classroomNeedsClass;

  /// No description provided for @settingsClass.
  ///
  /// In en, this message translates to:
  /// **'My class'**
  String get settingsClass;

  /// No description provided for @settingsChangeClass.
  ///
  /// In en, this message translates to:
  /// **'Change class (teacher)'**
  String get settingsChangeClass;

  /// No description provided for @quizYourClass.
  ///
  /// In en, this message translates to:
  /// **'Your class: {name}'**
  String quizYourClass(String name);

  /// No description provided for @quizFromTeacher.
  ///
  /// In en, this message translates to:
  /// **'From your teacher'**
  String get quizFromTeacher;

  /// No description provided for @quizSamples.
  ///
  /// In en, this message translates to:
  /// **'Sample questions'**
  String get quizSamples;

  /// No description provided for @quizCount.
  ///
  /// In en, this message translates to:
  /// **'{n} questions'**
  String quizCount(int n);

  /// No description provided for @quizChooseClassHint.
  ///
  /// In en, this message translates to:
  /// **'Choose your class to get questions for it. A teacher can set it in Settings.'**
  String get quizChooseClassHint;

  /// No description provided for @quizSampleNote.
  ///
  /// In en, this message translates to:
  /// **'Sample questions written by the Magana team. They are not past questions, and a teacher will check them. The questions are in English.'**
  String get quizSampleNote;

  /// No description provided for @quizTeacherNote.
  ///
  /// In en, this message translates to:
  /// **'Made by your teacher.'**
  String get quizTeacherNote;

  /// No description provided for @quizSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'{subject} practice'**
  String quizSubjectTitle(String subject);

  /// Primary 1–6: encouraging
  ///
  /// In en, this message translates to:
  /// **'Well done! You chose {letter}.'**
  String quizCorrectPrimary(String letter);

  /// Primary 1–6: encouraging; answer is the letter and option text
  ///
  /// In en, this message translates to:
  /// **'Good try! The answer is {answer}.'**
  String quizWrongPrimary(String answer);

  /// No description provided for @quizPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture: {description}'**
  String quizPicture(String description);

  /// Joins the last two answer letters: A, B or C
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get quizOr;

  /// No description provided for @quizSessionOpen.
  ///
  /// In en, this message translates to:
  /// **'Teacher: open your class session'**
  String get quizSessionOpen;

  /// No description provided for @quizSessionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Only the teacher should open a class session. Type the session code from the teacher portal.'**
  String get quizSessionPrompt;

  /// No description provided for @quizSessionCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Session code'**
  String get quizSessionCodeLabel;

  /// No description provided for @quizSessionStart.
  ///
  /// In en, this message translates to:
  /// **'Open session'**
  String get quizSessionStart;

  /// No description provided for @quizSessionActive.
  ///
  /// In en, this message translates to:
  /// **'Class session {code}'**
  String quizSessionActive(String code);

  /// No description provided for @quizSessionEnd.
  ///
  /// In en, this message translates to:
  /// **'End class session'**
  String get quizSessionEnd;

  /// No description provided for @quizSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No quizzes from your teacher in this session yet.'**
  String get quizSessionEmpty;

  /// No description provided for @msg_session_code_invalid.
  ///
  /// In en, this message translates to:
  /// **'That session code isn\'t right. Check it in the teacher portal.'**
  String get msg_session_code_invalid;

  /// No description provided for @msg_paper_lines.
  ///
  /// In en, this message translates to:
  /// **'Health and money papers aren\'t explained by AI. Each line is read exactly, in your language only where a checked translation exists.'**
  String get msg_paper_lines;

  /// CLINICAL DRAFT, pending Dr. Amos: said after a health-paper line read in English because no clinically approved template matched.
  ///
  /// In en, this message translates to:
  /// **'I can\'t translate this line safely. Please ask a pharmacist.'**
  String get msg_cant_translate_line_health;

  /// No description provided for @msg_cant_translate_line_money.
  ///
  /// In en, this message translates to:
  /// **'I can\'t translate this line safely. Please ask someone at your bank.'**
  String get msg_cant_translate_line_money;

  /// No description provided for @msg_numbers_left_out.
  ///
  /// In en, this message translates to:
  /// **'The exact numbers are on the page. Say ‘read again’ to hear them.'**
  String get msg_numbers_left_out;

  /// No description provided for @explainReadAgain.
  ///
  /// In en, this message translates to:
  /// **'Read the page again'**
  String get explainReadAgain;

  /// No description provided for @quizNotSure.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure what you said. Please say your answer again.'**
  String get quizNotSure;

  /// No description provided for @quizVoiceNotReady.
  ///
  /// In en, this message translates to:
  /// **'Voice answers in {language} aren\'t reliable enough yet. Tap an answer instead.'**
  String quizVoiceNotReady(String language);

  /// No description provided for @quizVoiceNotReadyWeb.
  ///
  /// In en, this message translates to:
  /// **'Voice answers in {language} aren\'t reliable enough yet. Tap or click an answer, or press {letters} on your keyboard.'**
  String quizVoiceNotReadyWeb(String language, String letters);

  /// No description provided for @quizVoicePrimaryOff.
  ///
  /// In en, this message translates to:
  /// **'In primary classes, tap your answer. Voice answers come later.'**
  String get quizVoicePrimaryOff;

  /// No description provided for @quizVoicePrimaryOffWeb.
  ///
  /// In en, this message translates to:
  /// **'In primary classes, tap or click your answer, or press {letters} on your keyboard.'**
  String quizVoicePrimaryOffWeb(String letters);

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Who is using Magana?'**
  String get whoTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'This helps Magana choose the right lessons and quizzes for you.'**
  String get whoBody;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'I’m in school'**
  String get whoInSchool;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Primary or secondary. You’ll join your class with a code from your teacher.'**
  String get whoInSchoolDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'I’ve finished school'**
  String get whoFinished;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Practise for JAMB or WAEC, improve your reading, or learn new skills.'**
  String get whoFinishedDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'University or other'**
  String get whoOther;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Read your own books, notes and papers. No class needed.'**
  String get whoOtherDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Join your class'**
  String get joinTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Ask your teacher for the 6-digit class code.'**
  String get joinBody;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Class code'**
  String get classCodeLabel;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Teacher code'**
  String get teacherCodeLabel;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'{label}: {typed}, {count} of 6 digits'**
  String codeGroup(String label, String typed, int count);

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'No digits yet. Type 6 digits.'**
  String get codeEmpty;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'You typed {typed}. {left} more.'**
  String codeProgress(String typed, int left);

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'All 6 digits: {typed}.'**
  String codeComplete(String typed);

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Type all 6 digits first.'**
  String get codeNeedsSix;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get keypadDelete;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Read back'**
  String get keypadReadBack;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Under 18? Your teacher will ask a parent or guardian to agree before your class is linked. Until then you can still read pages.'**
  String get joinUnder18Note;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Join class'**
  String get joinButton;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'I don’t have a code yet'**
  String get joinNoCode;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'You’re in!'**
  String get joinedTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Teacher: {name}'**
  String joinedTeacher(String name);

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Is this the right class? If not, tell your teacher. Only your teacher can move you to a different class.'**
  String get joinedRightClass;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your parent or guardian to agree. Your teacher will ask them.'**
  String get joinedWaiting;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get startReading;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Change class'**
  String get changeClassTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Your class now'**
  String get changeClassNow;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Your teacher needs to do this'**
  String get teacherCodeNeededTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Ask your teacher to enter their teacher code. It’s on their Magana teacher page.'**
  String get teacherCodeBody;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Now the new class’s code'**
  String get newClassCodeTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmLabel;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Wrong code 3 times? Magana waits 5 minutes before you can try again.'**
  String get teacherCodeLockNote;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get goalsTitle;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Choose as many as you like.'**
  String get goalsBody;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Prepare for JAMB'**
  String get goalJamb;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Past-question style practice: English, Maths and more'**
  String get goalJambDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Prepare for WAEC or NECO resit'**
  String get goalWaec;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Practice by subject, at SS3 level'**
  String get goalWaecDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Practise reading'**
  String get goalReading;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Short passages and stories, read with you'**
  String get goalReadingDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Learn new skills'**
  String get goalSkills;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Phone skills, getting around, money basics'**
  String get goalSkillsDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Just read my papers'**
  String get goalPapers;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Letters, bills, medicine labels'**
  String get goalPapersDetail;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'You can change these any time in Settings. No teacher needed.'**
  String get goalsNote;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your parent or guardian to agree. Until then you can read pages.'**
  String get waitingBanner;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Your teacher removed this phone from the class. You can still read pages.'**
  String get removedNotice;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'My goals'**
  String get settingsGoals;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Not in a class'**
  String get settingsNoClass;

  /// Accounts and sign-in boards (A1–A5). Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'My practice level'**
  String get practiceLevelTitle;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t open that PDF. Please try another file.'**
  String get msg_unreadable_pdf;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'This PDF is locked. Type its password: it is often in the email that came with it.'**
  String get msg_pdf_password_needed;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'That password didn\'t open the PDF. Please check it and try again.'**
  String get msg_pdf_password_wrong;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'This PDF is too long. I can read up to 20 pages at a time.'**
  String get msg_pdf_too_long;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Read a PDF'**
  String get readPdf;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'A bank statement, result or letter sent to your phone'**
  String get readPdfDetail;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Read a PDF'**
  String get pdfTitle;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF on your phone. You can also open one from WhatsApp, Gmail or Files with “Open with Magana” or Share.'**
  String get pdfBody;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF'**
  String get pdfChoose;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Reading the PDF. Long statements take a little while.'**
  String get pdfReading;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'This PDF is locked'**
  String get pdfPasswordTitle;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Type its password. Banks often send it in the same email, or it\'s part of your phone number or date of birth.'**
  String get pdfPasswordBody;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'PDF password'**
  String get pdfPasswordLabel;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Magana uses this password only to open this file, then forgets it. It is never saved. Magana never asks for your bank PIN or app password.'**
  String get pdfPasswordNote;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Open the PDF'**
  String get pdfOpen;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Type the password first.'**
  String get pdfPasswordEmpty;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Read back'**
  String get pdfPasswordReadBack;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'You typed: {spelled}'**
  String pdfPasswordSays(String spelled);

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'No PDF chosen.'**
  String get pdfNotChosen;

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String pageOf(int page, int count);

  /// Read a PDF. Hausa, Yoruba and Igbo are drafts for native-speaker review.
  ///
  /// In en, this message translates to:
  /// **'A PDF was shared with Magana: {name}'**
  String pdfShared(String name);

  /// A row on a page had print no word covered (a dropped amount).
  ///
  /// In en, this message translates to:
  /// **'Part of {where} wasn\'t read: there\'s print I couldn\'t make out. Please check it or retake the photo.'**
  String msg_line_part_unclear(String where);

  /// Capture tip: the print in the photo is too small to read every number.
  ///
  /// In en, this message translates to:
  /// **'The print is very small or faint in this photo, so I may miss some of it. Move the phone closer, or open the PDF itself if you have it.'**
  String get msg_small_print;

  /// Handwriting (DRAFT, pending Dr. Amos for health papers).
  ///
  /// In en, this message translates to:
  /// **'This page looks handwritten. Handwriting is hard for me, so I may get words wrong. Numbers are only read when I\'m sure.'**
  String get msg_handwritten_page;

  /// Handwriting (DRAFT, pending Dr. Amos for health papers).
  ///
  /// In en, this message translates to:
  /// **'Some of this page looks handwritten. I may get those parts wrong. Numbers there are only read when I\'m sure.'**
  String get msg_mixed_page;

  /// Handwriting (DRAFT, pending Dr. Amos for health papers).
  ///
  /// In en, this message translates to:
  /// **'This looks like handwriting on a health paper. I won\'t read handwritten medicines or doses. Please ask the pharmacist or nurse to read it to you.'**
  String get msg_handwritten_prescription;

  /// Handwriting (DRAFT, pending Dr. Amos for health papers).
  ///
  /// In en, this message translates to:
  /// **'On {where}, a handwritten number. I won\'t guess it: please ask the pharmacist or nurse.'**
  String msg_handwritten_number(String where);

  /// A money page read from a photo whose amounts aren't all reliable.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read the amounts on this page reliably. Please open the PDF from your bank\'s app or email, or ask someone you trust.'**
  String get msg_money_amounts_unreliable;

  /// Only the parts that passed every check are read.
  ///
  /// In en, this message translates to:
  /// **'This reading is incomplete. I\'ll read only the parts I could check.'**
  String get msg_reading_incomplete;

  /// No description provided for @columnsNote.
  ///
  /// In en, this message translates to:
  /// **'{count} columns. Left first, then right.'**
  String columnsNote(int count);

  /// No description provided for @columnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} columns · read left, then right'**
  String columnsSubtitle(int count);

  /// No description provided for @columnPosition.
  ///
  /// In en, this message translates to:
  /// **'Column {column} of {columns} · Line {number} of {total}'**
  String columnPosition(int column, int columns, int number, int total);

  /// No description provided for @columnStart.
  ///
  /// In en, this message translates to:
  /// **'Column {column} of {columns}'**
  String columnStart(int column, int columns);

  /// No description provided for @columnLabel.
  ///
  /// In en, this message translates to:
  /// **'Column {column}'**
  String columnLabel(int column);

  /// No description provided for @headingSpoken.
  ///
  /// In en, this message translates to:
  /// **'Heading: {text}'**
  String headingSpoken(String text);

  /// No description provided for @headingLabel.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get headingLabel;

  /// No description provided for @nextColumn.
  ///
  /// In en, this message translates to:
  /// **'Next column'**
  String get nextColumn;

  /// No description provided for @lastColumn.
  ///
  /// In en, this message translates to:
  /// **'This is the last column.'**
  String get lastColumn;

  /// No description provided for @jumpHeadings.
  ///
  /// In en, this message translates to:
  /// **'Headings'**
  String get jumpHeadings;

  /// No description provided for @jumpColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get jumpColumns;

  /// No description provided for @jumpTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get jumpTables;

  /// No description provided for @noHeadings.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t find any headings on this page.'**
  String get noHeadings;

  /// No description provided for @noColumns.
  ///
  /// In en, this message translates to:
  /// **'This page has one column.'**
  String get noColumns;

  /// No description provided for @noTables.
  ///
  /// In en, this message translates to:
  /// **'This page has no tables.'**
  String get noTables;

  /// No description provided for @mapNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get mapNow;

  /// No description provided for @mapNext.
  ///
  /// In en, this message translates to:
  /// **'next'**
  String get mapNext;

  /// No description provided for @letterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word may be wrong.} other{{count} words may be wrong.}}'**
  String letterCount(int count);

  /// No description provided for @letterCheckWords.
  ///
  /// In en, this message translates to:
  /// **'These words may be missing a special letter: {words}.'**
  String letterCheckWords(String words);

  /// No description provided for @spellWord.
  ///
  /// In en, this message translates to:
  /// **'Spell word'**
  String get spellWord;

  /// No description provided for @spellNone.
  ///
  /// In en, this message translates to:
  /// **'No marked words on this line.'**
  String get spellNone;

  /// No description provided for @askSomeone.
  ///
  /// In en, this message translates to:
  /// **'Ask someone'**
  String get askSomeone;

  /// No description provided for @askSomeoneText.
  ///
  /// In en, this message translates to:
  /// **'Ask someone who reads {language} to check the marked words.'**
  String askSomeoneText(String language);

  /// No description provided for @languagePage.
  ///
  /// In en, this message translates to:
  /// **'{language} page'**
  String languagePage(String language);

  /// No description provided for @msg_letters_ha.
  ///
  /// In en, this message translates to:
  /// **'Hausa page. I can miss letters like ƙ, ɗ and ɓ. Marked words may have one of these. Spell a word or check it with someone.'**
  String get msg_letters_ha;

  /// No description provided for @msg_letters_yo.
  ///
  /// In en, this message translates to:
  /// **'Yorùbá page. I can miss letters like ẹ, ọ and ṣ, and tone marks. Marked words may have one of these. Spell a word or check it with someone.'**
  String get msg_letters_yo;

  /// No description provided for @msg_letters_ig.
  ///
  /// In en, this message translates to:
  /// **'Igbo page. I can miss letters like ị, ọ and ụ. Marked words may have one of these. Spell a word or check it with someone.'**
  String get msg_letters_ig;

  /// No description provided for @msg_cut_off_top.
  ///
  /// In en, this message translates to:
  /// **'Part of the page is cut off at the top.'**
  String get msg_cut_off_top;

  /// No description provided for @msg_cut_off_bottom.
  ///
  /// In en, this message translates to:
  /// **'Part of the page is cut off at the bottom.'**
  String get msg_cut_off_bottom;

  /// No description provided for @msg_cut_off_left.
  ///
  /// In en, this message translates to:
  /// **'Part of the page is cut off at the left.'**
  String get msg_cut_off_left;

  /// No description provided for @msg_cut_off_right.
  ///
  /// In en, this message translates to:
  /// **'Part of the page is cut off at the right.'**
  String get msg_cut_off_right;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet. Reading on this phone.'**
  String get offlineBanner;

  /// No description provided for @offlineBannerSlow.
  ///
  /// In en, this message translates to:
  /// **'Magana\'s server isn\'t answering. Reading on this phone.'**
  String get offlineBannerSlow;

  /// No description provided for @offlineNote.
  ///
  /// In en, this message translates to:
  /// **'Basic reading only. Tables, columns and Explain need internet.'**
  String get offlineNote;

  /// No description provided for @offlineQueued.
  ///
  /// In en, this message translates to:
  /// **'I\'ll keep this page and do a full reading when you\'re back online.'**
  String get offlineQueued;

  /// No description provided for @fullReadingWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'Full reading when online'**
  String get fullReadingWhenOnline;

  /// No description provided for @queueDropped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The oldest waiting page was removed: up to 20 pages can wait.} other{The {count} oldest waiting pages were removed: up to 20 pages can wait.}}'**
  String queueDropped(int count);

  /// No description provided for @fullReadingsReady.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A full reading is ready in My library.} other{{count} full readings are ready in My library.}}'**
  String fullReadingsReady(int count);

  /// No description provided for @cueTiltToward.
  ///
  /// In en, this message translates to:
  /// **'Tilt the top of the phone toward you'**
  String get cueTiltToward;

  /// No description provided for @cueTiltAway.
  ///
  /// In en, this message translates to:
  /// **'Tilt the top of the phone away from you'**
  String get cueTiltAway;

  /// No description provided for @cueBlurry.
  ///
  /// In en, this message translates to:
  /// **'Blurry. Hold still'**
  String get cueBlurry;

  /// No description provided for @readerCommandHelp.
  ///
  /// In en, this message translates to:
  /// **'You can say: next, back, repeat, pause, read, next column, headings or spell. Say commands in English for now.'**
  String get readerCommandHelp;

  /// No description provided for @msg_explain_language_coming.
  ///
  /// In en, this message translates to:
  /// **'Explain in {language} is coming. You can hear it in English.'**
  String msg_explain_language_coming(String language);

  /// No description provided for @explainInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Hear it in English'**
  String get explainInEnglish;

  /// No description provided for @msg_progress_shared.
  ///
  /// In en, this message translates to:
  /// **'Your totals were shared with your teacher.'**
  String get msg_progress_shared;

  /// No description provided for @helpCheckPage.
  ///
  /// In en, this message translates to:
  /// **'Did you read this page on your own?'**
  String get helpCheckPage;

  /// No description provided for @helpCheckPdf.
  ///
  /// In en, this message translates to:
  /// **'Did you read this PDF on your own?'**
  String get helpCheckPdf;

  /// No description provided for @helpCheckQuiz.
  ///
  /// In en, this message translates to:
  /// **'Did you do this quiz on your own?'**
  String get helpCheckQuiz;

  /// No description provided for @helpCheckHow.
  ///
  /// In en, this message translates to:
  /// **'Say “yes”, “some help” or “skip”, or tap.'**
  String get helpCheckHow;

  /// No description provided for @helpOwn.
  ///
  /// In en, this message translates to:
  /// **'Yes, on my own'**
  String get helpOwn;

  /// No description provided for @helpOwnDetail.
  ///
  /// In en, this message translates to:
  /// **'No sighted help'**
  String get helpOwnDetail;

  /// No description provided for @helpSome.
  ///
  /// In en, this message translates to:
  /// **'I needed some help'**
  String get helpSome;

  /// No description provided for @helpSomeDetail.
  ///
  /// In en, this message translates to:
  /// **'Someone helped with part of it'**
  String get helpSomeDetail;

  /// No description provided for @helpSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get helpSkip;

  /// No description provided for @helpSkipDetail.
  ///
  /// In en, this message translates to:
  /// **'Don’t ask today'**
  String get helpSkipDetail;

  /// No description provided for @helpCheckNoteClass.
  ///
  /// In en, this message translates to:
  /// **'Asked once a day at most. Your teacher sees only the totals, never what you read.'**
  String get helpCheckNoteClass;

  /// No description provided for @helpCheckNotePhone.
  ///
  /// In en, this message translates to:
  /// **'Asked once a day at most. Your answers stay on this phone.'**
  String get helpCheckNotePhone;

  /// No description provided for @helpCheckNotHeard.
  ///
  /// In en, this message translates to:
  /// **'Please say yes, some help or skip, or tap your answer.'**
  String get helpCheckNotHeard;

  /// No description provided for @helpCheckThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you.'**
  String get helpCheckThanks;
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
