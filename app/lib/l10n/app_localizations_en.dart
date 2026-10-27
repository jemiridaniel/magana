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
      'Lay the page flat in good light and hold the phone about one forearm above it. I\'ll tell you how to move, and take the photo when the whole page is steady. You can also tap Take photo.';

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
  String get serverSleeping =>
      'Magana’s server is sleeping. Please try again later.';

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
  String get firstLine => 'This is the first line.';

  @override
  String get firstRow => 'This is the first row.';

  @override
  String get endOfPage => 'End of page.';

  @override
  String get endOfPageHint =>
      'End of page. Tap Repeat, or go back to read another page.';

  @override
  String whereLine(int number) {
    return 'line $number';
  }

  @override
  String whereRow(int number) {
    return 'row $number';
  }

  @override
  String whereCell(int row, int col) {
    return 'row $row, column $col';
  }

  @override
  String get whereTop => 'near the top of the page';

  @override
  String get whereMiddle => 'in the middle of the page';

  @override
  String get whereBottom => 'near the bottom of the page';

  @override
  String get unclearNumber => 'unclear number';

  @override
  String get unclearLetter => 'unclear letter';

  @override
  String get faintPrint => 'Faint print';

  @override
  String get msg_too_dark =>
      'It\'s quite dark. Turn on the torch or move to more light.';

  @override
  String get msg_blurry =>
      'The photo looks blurry. Hold the phone still and try again.';

  @override
  String msg_low_confidence(String where) {
    return 'I\'m not sure about $where. Please check it or retake the photo.';
  }

  @override
  String msg_low_confidence_number(String where) {
    return 'I can\'t read a number on $where clearly. Please check it or retake the photo.';
  }

  @override
  String msg_unreadable_number(String where) {
    return 'I can\'t read a number on $where clearly. Please check it or retake the photo.';
  }

  @override
  String msg_number_mismatch(String where) {
    return 'I can\'t read a number on $where clearly. Please check it or retake the photo.';
  }

  @override
  String msg_faint_region(String where) {
    return 'There is faint print $where that I can\'t read. Try more light, or retake the photo.';
  }

  @override
  String get msg_unknown_mode => 'Choose schoolwork, health or money.';

  @override
  String get msg_not_allowed_for_tier =>
      'This isn\'t available on this account.';

  @override
  String get msg_consent_required =>
      'Learners aged 13 to 17 need a parent\'s or guardian\'s consent first.';

  @override
  String get msg_teacher_session_required =>
      'Learners under 13 can only use Magana in a teacher-run session.';

  @override
  String get msg_unreadable_image =>
      'I couldn\'t open that photo. Please try again.';

  @override
  String get msg_numbers_unconfirmed =>
      'I couldn\'t explain this page safely. Here it is read again.';

  @override
  String get msg_class_code_wrong =>
      'That class code isn\'t right. Check it with your teacher.';

  @override
  String get msg_code_locked =>
      'Too many wrong codes. Please wait 5 minutes, then try again.';

  @override
  String get msg_teacher_code_needed =>
      'Only your teacher can move you to another class. Ask them to enter their teacher code.';

  @override
  String get msg_teacher_code_wrong =>
      'That teacher code isn\'t right. Ask your teacher to check it.';

  @override
  String get msg_class_has_no_accounts =>
      'This class only has lessons your teacher runs. Ask your teacher.';

  @override
  String get msg_not_linked =>
      'This phone isn\'t in a class now. You can still read pages.';

  @override
  String get msg_class_joined => 'You\'re in the class.';

  @override
  String get msg_class_changed => 'Your class has changed.';

  @override
  String get msg_explain_wrong_language =>
      'I couldn\'t explain this in your language, so I\'ll read the page exactly instead.';

  @override
  String get msg_go_to_clinic_now =>
      'This could be serious. Please go to the nearest clinic now, or call 112. Do not wait for a call back.';

  @override
  String get msg_nurse_call_within_2_hours =>
      'Thank you. A nurse will call you within 2 hours.';

  @override
  String get msg_nurse_call_working_hours =>
      'Thank you. A nurse will call you back during working hours.';

  @override
  String get autoCapture => 'Auto-capture';

  @override
  String get torchOn => 'Turn on torch';

  @override
  String get torchOff => 'Turn off torch';

  @override
  String get cameraView => 'Camera view';

  @override
  String get cameraUnavailable =>
      'I can\'t use the camera. Allow camera access in Settings, or choose a photo from the gallery.';

  @override
  String get msg_q_fever =>
      'Do you have a fever, or does your body feel very hot?';

  @override
  String get msg_q_fever_days => 'For how many days have you had the fever?';

  @override
  String get msg_q_fits =>
      'Have you had fits, or shaking of the body you could not stop?';

  @override
  String get msg_q_cannot_drink =>
      'Are you unable to drink anything, or is the baby unable to breastfeed?';

  @override
  String get msg_q_vomits_everything =>
      'Are you vomiting everything you eat or drink?';

  @override
  String get msg_q_very_sleepy =>
      'Are you very sleepy, confused, or hard to wake?';

  @override
  String get msg_q_bleeding =>
      'Are you bleeding without a clear reason, from the nose or gums, or in vomit or stool?';

  @override
  String get msg_q_yellow_eyes => 'Have your eyes or skin turned yellow?';

  @override
  String get msg_q_hard_breathing =>
      'Are you breathing very fast, or struggling to breathe?';

  @override
  String get msg_q_very_pale =>
      'Are your palms, lips or inner eyelids very pale?';

  @override
  String get msg_q_dark_urine => 'Is your urine very dark, like cola or tea?';

  @override
  String get msg_q_too_weak =>
      'Are you too weak to sit up or stand without help?';

  @override
  String msg_line_end_unclear(String where) {
    return 'I can\'t read the end of $where. Please check it or retake the photo.';
  }

  @override
  String get cueHigher => 'Higher';

  @override
  String get cueLower => 'Lower';

  @override
  String get cueLeft => 'Left';

  @override
  String get cueRight => 'Right';

  @override
  String get cueHoldStill => 'Hold still';

  @override
  String get cueCloser => 'Closer';

  @override
  String get cueFurther => 'Further';

  @override
  String get cueMoreLight => 'More light';

  @override
  String get cueNoPage => 'No page';

  @override
  String stepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get chooseLanguageTitle => 'Choose your language';

  @override
  String get chooseLanguageBody =>
      'Magana will speak to you in this language. You can change it any time from the Home screen.';

  @override
  String get languageHearsHint =>
      'Each option is read aloud in its own language when you touch it.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get welcome => 'Welcome';

  @override
  String get ageTitle => 'How old are you?';

  @override
  String get ageBody => 'We ask so Magana is safe and right for you.';

  @override
  String get ageAdult => 'I am 18 or older';

  @override
  String get ageAdultDetail =>
      'Use everything in Magana, including health and money papers.';

  @override
  String get ageTeen => 'I am 13 to 17';

  @override
  String get ageTeenDetail =>
      'A parent, guardian or teacher agrees first. Magana helps with school subjects only.';

  @override
  String get ageChild => 'I am under 13';

  @override
  String get ageChildDetail =>
      'Your teacher will use Magana with you in class.';

  @override
  String get privacyNote =>
      'Photos of your pages are deleted after reading. We never share your details.';

  @override
  String get hearAgain => 'Hear this page again';

  @override
  String get readyTitle => 'You\'re ready';

  @override
  String get readyBody =>
      'Hold your phone over any printed page and Magana will read it to you.';

  @override
  String get startLabel => 'Start';

  @override
  String get consentTitle => 'Ask a parent, guardian or teacher';

  @override
  String get consentBody => 'Please read or listen to this together.';

  @override
  String get consentPoint1 => 'Magana helps with school subjects only.';

  @override
  String get consentPoint2 =>
      'No health or money papers, no WhatsApp and no open chat.';

  @override
  String get consentPoint3 => 'Photos are deleted after reading.';

  @override
  String get consentConfirm =>
      'I am the parent, guardian or teacher, and I agree';

  @override
  String get classroomTitle => 'Magana in class';

  @override
  String get classroomBody =>
      'Your teacher starts Magana with you in class. When the lesson ends, close the app.';

  @override
  String get classroomStart => 'Teacher: start the class session';

  @override
  String get classroomConfirmTitle => 'Are you the teacher?';

  @override
  String get classroomConfirmYes => 'Yes, start the session';

  @override
  String get cancel => 'Cancel';

  @override
  String get back => 'Back';

  @override
  String get msg_unknown_tier =>
      'Please set up Magana again: your age group wasn\'t recognised.';

  @override
  String get readPageSubtitleSchool => 'Schoolwork, notes, textbooks and tests';

  @override
  String get everydaySubtitle => 'Health and money papers · 18+';

  @override
  String get paperMedicine => 'Medicine label';

  @override
  String get paperMedicineDetail => 'Labels and prescriptions';

  @override
  String get paperReport => 'Medical report';

  @override
  String get paperReportDetail => 'Test results and discharge notes';

  @override
  String get paperStatement => 'Bank statement';

  @override
  String get paperStatementDetail => 'Statements, receipts and bills';

  @override
  String get talkToNurse => 'Talk to a nurse';

  @override
  String get talkToNurseDetail => 'With the Ibà quick check';

  @override
  String get everydayPrivacy =>
      'Private papers are read on your phone and not saved. Magana never asks for your PIN or password.';

  @override
  String get readExactly => 'Read exactly as printed';

  @override
  String get noteMedicine =>
      'Magana reads what is printed. It does not give medical advice. If anything on the label is unclear, ask your pharmacist before taking it.';

  @override
  String get noteReport =>
      'Numbers and ranges are read exactly as printed. Magana does not interpret results: only your health worker can explain what they mean for you.';

  @override
  String get noteStatement =>
      'Amounts are read exactly as printed. This statement is not saved. Magana never asks for your PIN or password. If an amount is unclear, check it with your bank or a trusted person.';

  @override
  String get askPharmacistOrNurse => 'Ask a pharmacist or nurse';

  @override
  String get adultsOnly => 'This is for adults (18 and over).';

  @override
  String get healthWorkerTitle => 'Talk to a health worker';

  @override
  String get healthWorkerSubtitle => 'A nurse or pharmacist calls you back';

  @override
  String get helpWithTitle => 'What do you need help with?';

  @override
  String get reasonMedicine => 'Understanding my medicine';

  @override
  String get reasonResults => 'Understanding my results';

  @override
  String get reasonOther => 'Something else';

  @override
  String get callLanguage => 'Language for the call';

  @override
  String get answerIbaFirst => 'Answer a few quick questions first (Ibà)';

  @override
  String get requestCallback => 'Request a call back';

  @override
  String get emergencyBold => 'Emergency?';

  @override
  String get emergencyText => 'Do not wait for a call back. Call 112 now.';

  @override
  String get call112 => 'Call 112';

  @override
  String get quickCheckTitle => 'Quick health check';

  @override
  String quickCheckProgress(int n, int total) {
    return 'Powered by Ibà · question $n of $total';
  }

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get moreDays => 'One more day';

  @override
  String get fewerDays => 'One day fewer';

  @override
  String get nextLabel => 'Next';

  @override
  String get quickCheckNote =>
      'Your answers help the nurse decide how soon to call you. Ibà does not diagnose. If you have danger signs, Magana tells you to go to a clinic now.';

  @override
  String get resultTitle => 'Your result';

  @override
  String get checkingAnswers => 'Checking your answers.';

  @override
  String get backHome => 'Back to home';

  @override
  String get msg_callback_booked =>
      'Your call back is booked. A nurse or pharmacist will call you.';

  @override
  String get msg_callback_unavailable =>
      'Call backs are not available yet. If you need help now, go to a clinic or call 112.';

  @override
  String quickCheckProgressFallback(int n, int total) {
    return 'Built-in safety check · question $n of $total';
  }

  @override
  String get resultUrgent =>
      'A nurse should call you within 2 hours. Request a call back now. If you get worse, go to a clinic or call 112.';

  @override
  String get resultRoutine =>
      'A nurse can call you back during working hours. Request a call back. If you get worse, go to a clinic or call 112.';

  @override
  String quizProgress(int n, int total) {
    return 'Question $n of $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct right out of $answered answered';
  }

  @override
  String quizSayAnswer(String letters) {
    return 'Say $letters';
  }

  @override
  String get quizListening => 'Listening… Tap to stop';

  @override
  String quizCorrect(String letter) {
    return 'Correct! You chose $letter.';
  }

  @override
  String quizWrong(String letter, String answer) {
    return 'Not quite. You chose $letter. The answer is $answer.';
  }

  @override
  String quizUnclear(String heard, String letters) {
    return 'I heard “$heard”. Please say $letters.';
  }

  @override
  String quizNothingHeard(String letters) {
    return 'I did not hear an answer. Say $letters, or double tap an answer.';
  }

  @override
  String get quizRepeat => 'Repeat question';

  @override
  String get quizNext => 'Next question';

  @override
  String get quizFinish => 'See my result';

  @override
  String get quizYourAnswerRight => 'your answer, correct';

  @override
  String get quizYourAnswerWrong => 'your answer, not correct';

  @override
  String get quizRightAnswer => 'correct answer';

  @override
  String get quizResultTitle => 'Practice finished';

  @override
  String quizResult(int correct, int total) {
    return 'You got $correct out of $total right.';
  }

  @override
  String get quizAgain => 'Practise again';

  @override
  String get skillsSubtitle => 'Short spoken lessons, at your pace';

  @override
  String nextLesson(int minutes) {
    return 'Next lesson · $minutes min';
  }

  @override
  String get playLesson => 'Play lesson';

  @override
  String get pauseLesson => 'Pause';

  @override
  String get practiseNow => 'Practise now';

  @override
  String get lessonDone => 'Done';

  @override
  String lessonStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get lessonNotStarted => 'Not started';

  @override
  String get allLessonsDone => 'You have finished every lesson. Well done!';

  @override
  String get practiseWithChampion => 'Practise with a Magana Champion';

  @override
  String get skillsNote =>
      'Sample lessons written by the Magana team, to be reviewed by rehabilitation trainers. Lessons are in English for now.';

  @override
  String get previousStep => 'Previous step';

  @override
  String get nextStep => 'Next step';

  @override
  String get lessonFinished => 'Lesson finished.';

  @override
  String get scoreTitle => 'My Independence Score';

  @override
  String get scoreSubtitle => 'Tasks you finished in Magana';

  @override
  String scoreOutOf(int score) {
    return '$score out of 100';
  }

  @override
  String get scoreByArea => 'By area';

  @override
  String get areaLearning => 'Learning';

  @override
  String get areaHealth => 'Health papers';

  @override
  String get areaMoney => 'Money and letters';

  @override
  String get areaSkills => 'Skills';

  @override
  String areaScoreLabel(String area, int score) {
    return '$area: $score out of 100';
  }

  @override
  String get scoreThisWeek => 'This week';

  @override
  String get scoreNothingThisWeek =>
      'No tasks yet this week. Read a page or take a quiz to start.';

  @override
  String weekReadSchool(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages of schoolwork read',
      one: '1 page of schoolwork read',
    );
    return '$_temp0';
  }

  @override
  String weekReadMedicine(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicine labels read',
      one: '1 medicine label read',
    );
    return '$_temp0';
  }

  @override
  String weekReadReport(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medical reports read',
      one: '1 medical report read',
    );
    return '$_temp0';
  }

  @override
  String weekReadStatement(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bank statements or receipts read',
      one: '1 bank statement or receipt read',
    );
    return '$_temp0';
  }

  @override
  String weekQuiz(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quizzes finished',
      one: '1 quiz finished',
    );
    return '$_temp0';
  }

  @override
  String weekLesson(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons finished',
      one: '1 lesson finished',
    );
    return '$_temp0';
  }

  @override
  String get scoreHow =>
      'Your score counts real tasks you finished in Magana in the last 30 days. It stays on this phone; only you see it.';

  @override
  String get championsTitle => 'Magana Champions';

  @override
  String get championsSubtitle => 'Learn from people who have been there';

  @override
  String get championSample => 'Sample profile';

  @override
  String get championDetail => 'Blind since age 12 · Kano · Hausa, English';

  @override
  String get championNotYet =>
      'This is a sample profile. Champions will be matched to you through partner organisations. Calls are not available yet.';

  @override
  String get becomeChampion => 'Become a Champion';

  @override
  String get becomeChampionBody =>
      'Help others in your community and earn a certificate.';

  @override
  String get champStepBasics => 'Finish Phone basics';

  @override
  String get champStepPhotos => 'Finish Taking clear photos';

  @override
  String get champStepScore => 'Reach an Independence Score of 60';

  @override
  String get champStepTraining => 'Join a 2-hour Champion training';

  @override
  String get champStepHelp => 'Help your first 3 people';

  @override
  String get stepDone => 'done';

  @override
  String get stepNotDone => 'not done yet';

  @override
  String get championsPartnerNote =>
      'Champion training will be run with partner organisations. It is not open yet.';

  @override
  String get librarySubtitle => 'Saved readings, kept for 30 days';

  @override
  String get libraryEmpty =>
      'Nothing saved yet. After Magana reads a page, choose Save to my library.';

  @override
  String libraryDeletesIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'deleted in $count days',
      one: 'deleted tomorrow',
      zero: 'deleted today',
    );
    return '$_temp0';
  }

  @override
  String librarySavedOn(String date) {
    return 'Saved $date';
  }

  @override
  String get libraryPrivacy =>
      'Saved readings stay on this phone and are deleted after 30 days. Photos are never saved.';

  @override
  String get saveToLibrary => 'Save to my library';

  @override
  String get savedToLibrary =>
      'Saved to my library. It stays on this phone for 30 days.';

  @override
  String get deleteFromLibrary => 'Delete from my library';

  @override
  String get deleteConfirm => 'Delete this reading from your library?';

  @override
  String get deleteYes => 'Delete';

  @override
  String get deletedFromLibrary => 'Deleted from your library.';

  @override
  String get remindersTitle => 'Today\'s medicines';

  @override
  String get remindersSubtitle => 'Times set with your pharmacist';

  @override
  String get remindersCard => 'Medicine reminders';

  @override
  String get remindersCardDetail => 'Times for your medicines';

  @override
  String get remindersEmpty =>
      'No reminders yet. Add the times your pharmacist or doctor gave you.';

  @override
  String get doseTaken => 'Taken';

  @override
  String get doseDue => 'Due now';

  @override
  String get doseLater => 'Later today';

  @override
  String doseLabel(String time, String state, String medicine, String amount) {
    return '$time, $state. $medicine. $amount';
  }

  @override
  String get iTookIt => 'I\'ve taken it';

  @override
  String get remindLater => 'Remind in 15 min';

  @override
  String get remindLaterSet => 'I will remind you again in 15 minutes.';

  @override
  String get markedTaken => 'Marked as taken.';

  @override
  String get addReminder => 'Add a reminder';

  @override
  String get medicineName => 'Medicine name, as on the label';

  @override
  String get medicineAmount =>
      'How much, as your pharmacist said (for example, 2 tablets)';

  @override
  String get reminderTime => 'Time';

  @override
  String get earlierHour => 'One hour earlier';

  @override
  String get laterHour => 'One hour later';

  @override
  String get earlierMinutes => '15 minutes earlier';

  @override
  String get laterMinutes => '15 minutes later';

  @override
  String get saveReminder => 'Save reminder';

  @override
  String get medicineNameNeeded => 'Type the medicine name first.';

  @override
  String reminderSaved(String time) {
    return 'Reminder saved for $time.';
  }

  @override
  String get deleteReminder => 'Delete reminder';

  @override
  String deleteReminderConfirm(String time, String medicine) {
    return 'Delete the $time reminder for $medicine?';
  }

  @override
  String get reminderNotice =>
      'Your phone rings and vibrates at each time, as a notification. Magana reminds you at the times you set. It never changes a dose.';

  @override
  String get notificationsOff =>
      'Notifications are off for Magana, so reminders only show when Magana is open. You can turn them on in your phone\'s settings.';

  @override
  String get missedDose => 'Missed a dose? Ask a pharmacist';

  @override
  String get reminderNotifyTitle => 'Time for your medicine';

  @override
  String get exactTitle => 'Ring on time?';

  @override
  String get exactBody =>
      'To ring at the exact minute, your phone needs to allow Magana to set alarms and reminders. The next screen has one switch: turn it on, then go back.';

  @override
  String get exactOpen => 'Open the setting';

  @override
  String get notNow => 'Not now';

  @override
  String get remindersMayBeLate =>
      'On this phone, reminders may ring up to an hour late. To ring on time, allow alarms and reminders for Magana.';

  @override
  String get allowOnTime => 'Allow on-time reminders';

  @override
  String get msg_q_bleeding_no_sight =>
      'Have you felt or tasted blood, or has anyone told you that you are bleeding, from your nose, gums, vomit or stool?';

  @override
  String get msg_q_yellow_eyes_no_sight =>
      'Has anyone told you that your eyes or skin look yellow?';

  @override
  String get msg_q_very_pale_no_sight =>
      'Has anyone told you that you look very pale? Do you feel very weak, dizzy or out of breath when you stand?';

  @override
  String get msg_q_dark_urine_no_sight =>
      'Has someone near you seen that your urine is very dark, like cola or tea?';

  @override
  String get msg_ask_someone_to_check =>
      'Please ask someone near you to check, or go to a clinic.';

  @override
  String get cantTell => 'I can\'t tell';

  @override
  String get appLanguageTitle => 'App language';

  @override
  String get languageSheetBody =>
      'Menus, buttons, help and Magana\'s voice all switch to the language you choose.';

  @override
  String get languageVoiceTip =>
      'You can also say “change language to Igbo” after pressing Speak a command on Home.';

  @override
  String useLanguage(String language) {
    return 'Use $language';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get settingsVersionNote =>
      'Tell the Magana team this version when you report a problem.';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get reportHow =>
      'Tell the Magana team three things: the name of the screen, what you did, and what Magana said.';

  @override
  String get speakCommand => 'Speak a command';

  @override
  String get listeningCommand => 'Listening… Tap to stop';

  @override
  String commandNotUnderstood(String heard) {
    return 'I heard “$heard”, but I don\'t know that command. Say help to hear what you can say.';
  }

  @override
  String get commandNothingHeard =>
      'I didn\'t hear a command. Try again, or say help.';

  @override
  String commandHelp(String commands) {
    return 'You can say: $commands. Say commands in English for now.';
  }

  @override
  String get changeLanguageCommand => 'change language';

  @override
  String get voiceCommandsUnavailable =>
      'Voice commands are not available on this phone. Use the buttons instead.';

  @override
  String get explainTitle => 'Explain';

  @override
  String explainFrom(String source) {
    return 'From: $source';
  }

  @override
  String get explainPreviewBanner =>
      'Preview. N-ATLAS, which will explain pages in your language, is not connected yet. For now Magana reads the page text exactly as printed.';

  @override
  String answerLanguage(String language) {
    return 'Answer language, currently $language';
  }

  @override
  String get youSaid => 'You said';

  @override
  String basedOnPage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Based on: $count lines and rows of your page',
      one: 'Based on: 1 line of your page',
    );
    return '$_temp0';
  }

  @override
  String get readExactlyNote =>
      'Numbers and words from the page are read exactly as printed.';

  @override
  String get saySimpler => 'Say it simpler';

  @override
  String get giveExample => 'Give an example';

  @override
  String get explainDisclaimer =>
      'Magana can make mistakes. Check important answers with your teacher.';

  @override
  String get askAQuestion => 'Ask a question';

  @override
  String get explainNoPage =>
      'Explanations are about a page. Read a page first, then choose Explain this.';

  @override
  String get explainThis => 'Explain this';

  @override
  String get explainQuestionPreview =>
      'When N-ATLAS is connected, Magana will answer your question from this page. For now, here is the page.';

  @override
  String get msg_explain_preview =>
      'This is a preview. Explanations in your language come when N-ATLAS is connected. Here is the page, read exactly as printed.';

  @override
  String get msg_explained => 'Here is the explanation.';

  @override
  String get msg_explain_bad_source =>
      'There is no page text to explain. Please read a page first.';

  @override
  String get jumpWithinPage => 'Jump within page';

  @override
  String get jumpStart => 'Start of the page';

  @override
  String jumpTable(int number) {
    return 'Table $number';
  }

  @override
  String get jumpWarnings => 'Next thing I\'m not sure about';

  @override
  String get jumpNotYet => 'Jumping to diagrams is not available yet.';

  @override
  String get paperLetter => 'Letters & forms';

  @override
  String get paperLetterDetail => 'Notices, forms, religious texts';

  @override
  String get noteLetter =>
      'Magana reads what is printed. It does not give legal or financial advice, and never asks for your PIN or password.';

  @override
  String get readAnyPaper => 'Read any paper';

  @override
  String get readAnyPaperDetail => 'Magana works out what kind of paper it is';

  @override
  String detectedPaper(String paper) {
    return 'Paper type: $paper.';
  }

  @override
  String weekReadLetter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count letters or forms read',
      one: '1 letter or form read',
    );
    return '$_temp0';
  }

  @override
  String get readAgain => 'Read again';

  @override
  String get askAboutResult => 'What does this mean?';

  @override
  String get resultAnswer =>
      'Only your health worker can explain what this result means for you. I can save your question for your next visit, or ask a nurse to call you.';

  @override
  String youAsked(String question) {
    return 'You asked: “$question”';
  }

  @override
  String get saveQuestion => 'Save question';

  @override
  String get questionSaved =>
      'Saved. You will find it in Talk to a health worker.';

  @override
  String get askANurse => 'Ask a nurse';

  @override
  String get savedQuestionsTitle => 'Questions for your next visit';

  @override
  String removeQuestion(String question) {
    return 'Remove: $question';
  }

  @override
  String questionAbout(String question, String where) {
    return '$question (about $where)';
  }

  @override
  String get fromTheStatement => 'From the statement, exactly as printed';

  @override
  String get findTransaction => 'Find a transaction';

  @override
  String get findPrompt =>
      'Say or type a word, date or amount from the transaction.';

  @override
  String get findField => 'Word, date or amount';

  @override
  String get findSearch => 'Find';

  @override
  String get findSpeak => 'Speak instead';

  @override
  String findNoMatch(String query) {
    return 'No row has “$query”.';
  }

  @override
  String get sayYesOrNo => 'Say yes, no, or I can\'t tell';

  @override
  String voiceAnswerUnclear(String heard) {
    return 'I heard “$heard”. Please say yes, no, or I can\'t tell.';
  }

  @override
  String scoreUpSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks ago',
      one: '1 week ago',
    );
    return 'Up from $start when you started, $_temp0';
  }

  @override
  String scoreSince(int start, num weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks ago',
      one: '1 week ago',
    );
    return '$start when you started, $_temp0';
  }

  @override
  String get shareScore => 'Share my score with my teacher';

  @override
  String get shareScoreNote =>
      'Your teacher will see your score, never your pages or questions, once your class is connected to the Magana teacher portal.';

  @override
  String get sayNameWhenLocked => 'Say the medicine name when locked';

  @override
  String get sayNameNote =>
      'Off: the lock screen says only “Magana reminder”. On: the lock screen shows the medicine and how much, and Magana says them aloud at each time, so people near you may see or hear them.';

  @override
  String get reminderGenericTitle => 'Magana reminder';

  @override
  String get reminderGenericBody => 'Open Magana to hear which medicine.';

  @override
  String get msg_bad_api_key =>
      'This copy of Magana can\'t reach the reading service. Please update the app.';

  @override
  String get msg_explain_unavailable =>
      'Explanations aren\'t available right now. Here is the page, read exactly as printed.';

  @override
  String get msg_asr_unavailable =>
      'Speech recognition on the server is not set up; the phone\'s own is used.';

  @override
  String get msg_audio_too_long =>
      'That recording is too long. Please say a short answer.';

  @override
  String get msg_unreadable_audio =>
      'I couldn\'t hear that recording. Please try again.';

  @override
  String get aboutTitle => 'About Magana';

  @override
  String get aboutModels => 'Language models';

  @override
  String get aboutModelsNote =>
      'Magana uses these open models under the N-ATLaS Terms of Use, version 1.0. The credit lines below are quoted as the terms require.';

  @override
  String get aboutExplain => 'Explanations in your language';

  @override
  String get aboutSpeech => 'Speech recognition';

  @override
  String get openSourceLicences => 'Open-source licences';

  @override
  String aboutContact(String email) {
    return 'Questions or problems: email $email';
  }

  @override
  String get msg_explain_not_available =>
      'Explain isn\'t available yet. Here is the page, read exactly as printed.';

  @override
  String quizConfirm(String answer) {
    return 'You said $answer. Is that right?';
  }

  @override
  String quizConfirmYes(String answer) {
    return 'Yes, $answer';
  }

  @override
  String get quizConfirmNo => 'No, ask me again';

  @override
  String get quizSayYesOrNo => 'Say yes or no';

  @override
  String get quizSayAgain => 'Please say your answer again.';

  @override
  String get quizTapInstead =>
      'I\'m having trouble hearing you. Please double tap your answer instead.';

  @override
  String get quizSayTrueFalse => 'Say true or false';

  @override
  String get msg_too_many_requests =>
      'Magana is busy right now. Please wait a minute and try again.';

  @override
  String get remindersNeedApp =>
      'Reminders need the Android or iPhone app. In a web browser Magana can\'t ring at the right time.';

  @override
  String get quizVoiceUnavailable =>
      'Voice answers aren\'t available on this device yet. Tap an answer instead.';

  @override
  String quizVoiceUnavailableWeb(String letters) {
    return 'Voice answers aren\'t available on this device yet. Tap or click an answer, or press $letters on your keyboard.';
  }

  @override
  String quizKeysHint(String letters) {
    return 'Tap or click an answer, or press $letters on your keyboard.';
  }

  @override
  String get quizKeysHintTrueFalse =>
      'Tap or click true or false, or press A for true or B for false.';

  @override
  String get quizTapAnswer => 'Tap an answer.';

  @override
  String get startMagana => 'Start Magana';

  @override
  String get classTitle => 'Which class are you in?';

  @override
  String get classBody =>
      'Magana picks practice questions for your class. A teacher can change it later.';

  @override
  String get classNotInSchool => 'I\'m not in school';

  @override
  String get classGroupPrimary => 'Primary school';

  @override
  String get classGroupJss => 'Junior secondary';

  @override
  String get classGroupSss => 'Senior secondary';

  @override
  String get classroomChooseClass =>
      'Teacher: choose the class for this session';

  @override
  String get classroomNeedsClass => 'Choose the class first.';

  @override
  String get settingsClass => 'My class';

  @override
  String get settingsChangeClass => 'Change class (teacher)';

  @override
  String quizYourClass(String name) {
    return 'Your class: $name';
  }

  @override
  String get quizFromTeacher => 'From your teacher';

  @override
  String get quizSamples => 'Sample questions';

  @override
  String quizCount(int n) {
    return '$n questions';
  }

  @override
  String get quizChooseClassHint =>
      'Choose your class to get questions for it. A teacher can set it in Settings.';

  @override
  String get quizSampleNote =>
      'Sample questions written by the Magana team. They are not past questions, and a teacher will check them. The questions are in English.';

  @override
  String get quizTeacherNote => 'Made by your teacher.';

  @override
  String quizSubjectTitle(String subject) {
    return '$subject practice';
  }

  @override
  String quizCorrectPrimary(String letter) {
    return 'Well done! You chose $letter.';
  }

  @override
  String quizWrongPrimary(String answer) {
    return 'Good try! The answer is $answer.';
  }

  @override
  String quizPicture(String description) {
    return 'Picture: $description';
  }

  @override
  String get quizOr => 'or';

  @override
  String get quizSessionOpen => 'Teacher: open your class session';

  @override
  String get quizSessionPrompt =>
      'Only the teacher should open a class session. Type the session code from the teacher portal.';

  @override
  String get quizSessionCodeLabel => 'Session code';

  @override
  String get quizSessionStart => 'Open session';

  @override
  String quizSessionActive(String code) {
    return 'Class session $code';
  }

  @override
  String get quizSessionEnd => 'End class session';

  @override
  String get quizSessionEmpty =>
      'No quizzes from your teacher in this session yet.';

  @override
  String get msg_session_code_invalid =>
      'That session code isn\'t right. Check it in the teacher portal.';

  @override
  String get msg_paper_lines =>
      'Health and money papers aren\'t explained by AI. Each line is read exactly, in your language only where a checked translation exists.';

  @override
  String get msg_cant_translate_line_health =>
      'I can\'t translate this line safely. Please ask a pharmacist.';

  @override
  String get msg_cant_translate_line_money =>
      'I can\'t translate this line safely. Please ask someone at your bank.';

  @override
  String get msg_numbers_left_out =>
      'The exact numbers are on the page. Say ‘read again’ to hear them.';

  @override
  String get explainReadAgain => 'Read the page again';

  @override
  String get quizNotSure =>
      'I\'m not sure what you said. Please say your answer again.';

  @override
  String quizVoiceNotReady(String language) {
    return 'Voice answers in $language aren\'t reliable enough yet. Tap an answer instead.';
  }

  @override
  String quizVoiceNotReadyWeb(String language, String letters) {
    return 'Voice answers in $language aren\'t reliable enough yet. Tap or click an answer, or press $letters on your keyboard.';
  }

  @override
  String get quizVoicePrimaryOff =>
      'In primary classes, tap your answer. Voice answers come later.';

  @override
  String quizVoicePrimaryOffWeb(String letters) {
    return 'In primary classes, tap or click your answer, or press $letters on your keyboard.';
  }

  @override
  String get whoTitle => 'Who is using Magana?';

  @override
  String get whoBody =>
      'This helps Magana choose the right lessons and quizzes for you.';

  @override
  String get whoInSchool => 'I’m in school';

  @override
  String get whoInSchoolDetail =>
      'Primary or secondary. You’ll join your class with a code from your teacher.';

  @override
  String get whoFinished => 'I’ve finished school';

  @override
  String get whoFinishedDetail =>
      'Practise for JAMB or WAEC, improve your reading, or learn new skills.';

  @override
  String get whoOther => 'University or other';

  @override
  String get whoOtherDetail =>
      'Read your own books, notes and papers. No class needed.';

  @override
  String get joinTitle => 'Join your class';

  @override
  String get joinBody => 'Ask your teacher for the 6-digit class code.';

  @override
  String get classCodeLabel => 'Class code';

  @override
  String get teacherCodeLabel => 'Teacher code';

  @override
  String codeGroup(String label, String typed, int count) {
    return '$label: $typed, $count of 6 digits';
  }

  @override
  String get codeEmpty => 'No digits yet. Type 6 digits.';

  @override
  String codeProgress(String typed, int left) {
    return 'You typed $typed. $left more.';
  }

  @override
  String codeComplete(String typed) {
    return 'All 6 digits: $typed.';
  }

  @override
  String get codeNeedsSix => 'Type all 6 digits first.';

  @override
  String get keypadDelete => 'Delete';

  @override
  String get keypadReadBack => 'Read back';

  @override
  String get joinUnder18Note =>
      'Under 18? Your teacher will ask a parent or guardian to agree before your class is linked. Until then you can still read pages.';

  @override
  String get joinButton => 'Join class';

  @override
  String get joinNoCode => 'I don’t have a code yet';

  @override
  String get joinedTitle => 'You’re in!';

  @override
  String joinedTeacher(String name) {
    return 'Teacher: $name';
  }

  @override
  String get joinedRightClass =>
      'Is this the right class? If not, tell your teacher. Only your teacher can move you to a different class.';

  @override
  String get joinedWaiting =>
      'Waiting for your parent or guardian to agree. Your teacher will ask them.';

  @override
  String get startReading => 'Start reading';

  @override
  String get changeClassTitle => 'Change class';

  @override
  String get changeClassNow => 'Your class now';

  @override
  String get teacherCodeNeededTitle => 'Your teacher needs to do this';

  @override
  String get teacherCodeBody =>
      'Ask your teacher to enter their teacher code. It’s on their Magana teacher page.';

  @override
  String get newClassCodeTitle => 'Now the new class’s code';

  @override
  String get confirmLabel => 'Confirm';

  @override
  String get teacherCodeLockNote =>
      'Wrong code 3 times? Magana waits 5 minutes before you can try again.';

  @override
  String get goalsTitle => 'What would you like to do?';

  @override
  String get goalsBody => 'Choose as many as you like.';

  @override
  String get goalJamb => 'Prepare for JAMB';

  @override
  String get goalJambDetail =>
      'Past-question style practice: English, Maths and more';

  @override
  String get goalWaec => 'Prepare for WAEC or NECO resit';

  @override
  String get goalWaecDetail => 'Practice by subject, at SS3 level';

  @override
  String get goalReading => 'Practise reading';

  @override
  String get goalReadingDetail => 'Short passages and stories, read with you';

  @override
  String get goalSkills => 'Learn new skills';

  @override
  String get goalSkillsDetail => 'Phone skills, getting around, money basics';

  @override
  String get goalPapers => 'Just read my papers';

  @override
  String get goalPapersDetail => 'Letters, bills, medicine labels';

  @override
  String get goalsNote =>
      'You can change these any time in Settings. No teacher needed.';

  @override
  String get saveLabel => 'Save';

  @override
  String get waitingBanner =>
      'Waiting for your parent or guardian to agree. Until then you can read pages.';

  @override
  String get removedNotice =>
      'Your teacher removed this phone from the class. You can still read pages.';

  @override
  String get settingsGoals => 'My goals';

  @override
  String get settingsNoClass => 'Not in a class';

  @override
  String get practiceLevelTitle => 'My practice level';

  @override
  String get msg_unreadable_pdf =>
      'I couldn\'t open that PDF. Please try another file.';

  @override
  String get msg_pdf_password_needed =>
      'This PDF is locked. Type its password: it is often in the email that came with it.';

  @override
  String get msg_pdf_password_wrong =>
      'That password didn\'t open the PDF. Please check it and try again.';

  @override
  String get msg_pdf_too_long =>
      'This PDF is too long. I can read up to 20 pages at a time.';

  @override
  String get readPdf => 'Read a PDF';

  @override
  String get readPdfDetail =>
      'A bank statement, result or letter sent to your phone';

  @override
  String get pdfTitle => 'Read a PDF';

  @override
  String get pdfBody =>
      'Choose a PDF on your phone. You can also open one from WhatsApp, Gmail or Files with “Open with Magana” or Share.';

  @override
  String get pdfChoose => 'Choose a PDF';

  @override
  String get pdfReading =>
      'Reading the PDF. Long statements take a little while.';

  @override
  String get pdfPasswordTitle => 'This PDF is locked';

  @override
  String get pdfPasswordBody =>
      'Type its password. Banks often send it in the same email, or it\'s part of your phone number or date of birth.';

  @override
  String get pdfPasswordLabel => 'PDF password';

  @override
  String get pdfPasswordNote =>
      'Magana uses this password only to open this file, then forgets it. It is never saved. Magana never asks for your bank PIN or app password.';

  @override
  String get pdfOpen => 'Open the PDF';

  @override
  String get pdfPasswordEmpty => 'Type the password first.';

  @override
  String get pdfPasswordReadBack => 'Read back';

  @override
  String pdfPasswordSays(String spelled) {
    return 'You typed: $spelled';
  }

  @override
  String get pdfNotChosen => 'No PDF chosen.';

  @override
  String pageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String pdfShared(String name) {
    return 'A PDF was shared with Magana: $name';
  }

  @override
  String msg_line_part_unclear(String where) {
    return 'Part of $where wasn\'t read: there\'s print I couldn\'t make out. Please check it or retake the photo.';
  }

  @override
  String get msg_small_print =>
      'The print is very small or faint in this photo, so I may miss some of it. Move the phone closer, or open the PDF itself if you have it.';

  @override
  String get msg_handwritten_page =>
      'This page looks handwritten. Handwriting is hard for me, so I may get words wrong. Numbers are only read when I\'m sure.';

  @override
  String get msg_mixed_page =>
      'Some of this page looks handwritten. I may get those parts wrong. Numbers there are only read when I\'m sure.';

  @override
  String get msg_handwritten_prescription =>
      'This looks like handwriting on a health paper. I won\'t read handwritten medicines or doses. Please ask the pharmacist or nurse to read it to you.';

  @override
  String msg_handwritten_number(String where) {
    return 'On $where, a handwritten number. I won\'t guess it: please ask the pharmacist or nurse.';
  }

  @override
  String get msg_money_amounts_unreliable =>
      'I can\'t read the amounts on this page reliably. Please open the PDF from your bank\'s app or email, or ask someone you trust.';

  @override
  String get msg_reading_incomplete =>
      'This reading is incomplete. I\'ll read only the parts I could check.';

  @override
  String columnsNote(int count) {
    return '$count columns. Left first, then right.';
  }

  @override
  String columnsSubtitle(int count) {
    return '$count columns · read left, then right';
  }

  @override
  String columnPosition(int column, int columns, int number, int total) {
    return 'Column $column of $columns · Line $number of $total';
  }

  @override
  String columnStart(int column, int columns) {
    return 'Column $column of $columns';
  }

  @override
  String columnLabel(int column) {
    return 'Column $column';
  }

  @override
  String headingSpoken(String text) {
    return 'Heading: $text';
  }

  @override
  String get headingLabel => 'Heading';

  @override
  String get nextColumn => 'Next column';

  @override
  String get lastColumn => 'This is the last column.';

  @override
  String get jumpHeadings => 'Headings';

  @override
  String get jumpColumns => 'Columns';

  @override
  String get jumpTables => 'Tables';

  @override
  String get noHeadings => 'I didn\'t find any headings on this page.';

  @override
  String get noColumns => 'This page has one column.';

  @override
  String get noTables => 'This page has no tables.';

  @override
  String get mapNow => 'now';

  @override
  String get mapNext => 'next';

  @override
  String letterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words may be wrong.',
      one: '1 word may be wrong.',
    );
    return '$_temp0';
  }

  @override
  String letterCheckWords(String words) {
    return 'These words may be missing a special letter: $words.';
  }

  @override
  String get spellWord => 'Spell word';

  @override
  String get spellNone => 'No marked words on this line.';

  @override
  String get askSomeone => 'Ask someone';

  @override
  String askSomeoneText(String language) {
    return 'Ask someone who reads $language to check the marked words.';
  }

  @override
  String languagePage(String language) {
    return '$language page';
  }

  @override
  String get msg_letters_ha =>
      'Hausa page. I can miss letters like ƙ, ɗ and ɓ. Marked words may have one of these. Spell a word or check it with someone.';

  @override
  String get msg_letters_yo =>
      'Yorùbá page. I can miss letters like ẹ, ọ and ṣ, and tone marks. Marked words may have one of these. Spell a word or check it with someone.';

  @override
  String get msg_letters_ig =>
      'Igbo page. I can miss letters like ị, ọ and ụ. Marked words may have one of these. Spell a word or check it with someone.';

  @override
  String get msg_cut_off_top => 'Part of the page is cut off at the top.';

  @override
  String get msg_cut_off_bottom => 'Part of the page is cut off at the bottom.';

  @override
  String get msg_cut_off_left => 'Part of the page is cut off at the left.';

  @override
  String get msg_cut_off_right => 'Part of the page is cut off at the right.';

  @override
  String get offlineBanner => 'No internet. Reading on this phone.';

  @override
  String get offlineBannerSlow =>
      'Magana\'s server isn\'t answering. Reading on this phone.';

  @override
  String get offlineNote =>
      'Basic reading only. Tables, columns and Explain need internet.';

  @override
  String get offlineQueued =>
      'I\'ll keep this page and do a full reading when you\'re back online.';

  @override
  String get fullReadingWhenOnline => 'Full reading when online';

  @override
  String queueDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count oldest waiting pages were removed: up to 20 pages can wait.',
      one: 'The oldest waiting page was removed: up to 20 pages can wait.',
    );
    return '$_temp0';
  }

  @override
  String fullReadingsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count full readings are ready in My library.',
      one: 'A full reading is ready in My library.',
    );
    return '$_temp0';
  }

  @override
  String get cueTiltToward => 'Tilt the top of the phone toward you';

  @override
  String get cueTiltAway => 'Tilt the top of the phone away from you';

  @override
  String get cueBlurry => 'Blurry. Hold still';

  @override
  String get readerCommandHelp =>
      'You can say: next, back, repeat, pause, read, next column, headings, spell or report a problem. Say commands in English for now.';

  @override
  String msg_explain_language_coming(String language) {
    return 'Explain in $language is coming. You can hear it in English.';
  }

  @override
  String get explainInEnglish => 'Hear it in English';

  @override
  String get msg_progress_shared =>
      'Your totals were shared with your teacher.';

  @override
  String get helpCheckPage => 'Did you read this page on your own?';

  @override
  String get helpCheckPdf => 'Did you read this PDF on your own?';

  @override
  String get helpCheckQuiz => 'Did you do this quiz on your own?';

  @override
  String get helpCheckHow => 'Say “yes”, “some help” or “skip”, or tap.';

  @override
  String get helpOwn => 'Yes, on my own';

  @override
  String get helpOwnDetail => 'No sighted help';

  @override
  String get helpSome => 'I needed some help';

  @override
  String get helpSomeDetail => 'Someone helped with part of it';

  @override
  String get helpSkip => 'Skip';

  @override
  String get helpSkipDetail => 'Don’t ask today';

  @override
  String get helpCheckNoteClass =>
      'Asked once a day at most. Your teacher sees only the totals, never what you read.';

  @override
  String get helpCheckNotePhone =>
      'Asked once a day at most. Your answers stay on this phone.';

  @override
  String get helpCheckNotHeard =>
      'Please say yes, some help or skip, or tap your answer.';

  @override
  String get helpCheckThanks => 'Thank you.';

  @override
  String get msg_report_sent =>
      'Thank you. Your report went to the Magana team.';

  @override
  String get msg_voice_note_adults_only =>
      'Voice notes are for adults only. Choose what went wrong from the list.';

  @override
  String get msg_voice_note_unreadable =>
      'I couldn\'t use that voice note. Please record it again or send the report without it.';

  @override
  String get msg_voice_note_too_long =>
      'That voice note is too long. Please keep it under 60 seconds.';

  @override
  String get reportGoesTo => 'Goes to the Magana team';

  @override
  String get reportWhat => 'What went wrong?';

  @override
  String get reportReadWrong => 'It read something wrong';

  @override
  String get reportHardToUse => 'It was hard to use';

  @override
  String get reportTooSlow => 'It was too slow';

  @override
  String get reportSomethingElse => 'Something else';

  @override
  String get reportRecord => 'Record a voice note (up to 60 seconds)';

  @override
  String reportRecording(int seconds) {
    return 'Stop recording · $seconds s';
  }

  @override
  String reportVoiceNote(int seconds) {
    return 'Voice note recorded: $seconds seconds.';
  }

  @override
  String get reportDeleteVoice => 'Delete voice note';

  @override
  String get reportIncludeText => 'Include this page’s text';

  @override
  String get reportIncludeTextNote =>
      'Off unless you switch it on. Photos are never sent.';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportChooseFirst => 'Choose what went wrong first.';

  @override
  String get reportNoMic =>
      'Magana can\'t use the microphone. You can still send the report.';

  @override
  String emailSupport(String email) {
    return 'Email $email';
  }

  @override
  String get msg_offline_no_confidence =>
      'This phone can\'t say how sure it is of each word, so every number is read as “unclear number”. Check important papers when you are online, or with a person.';

  @override
  String get msg_daily_limit =>
      'You\'ve read a lot of pages today. Magana can read more tomorrow. Pages you saved are in My library.';

  @override
  String get msg_edge_cut_left => 'Some words at the left edge are cut off.';

  @override
  String get msg_edge_cut_right => 'Some words at the right edge are cut off.';

  @override
  String get msg_faint_print =>
      'The print is faint, so I darkened it to read it. Check important numbers with a person.';

  @override
  String summaryNumbers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numbers are unclear.',
      one: '1 number is unclear.',
    );
    return '$_temp0';
  }

  @override
  String summaryLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines are hard to read.',
      one: '1 line is hard to read.',
    );
    return '$_temp0';
  }

  @override
  String get summaryAsk => 'Say “what\'s unclear” to hear where.';

  @override
  String get unclearMark => 'Unclear.';

  @override
  String get whatsUnclear => 'What\'s unclear?';

  @override
  String get whatsUnclearNone => 'Nothing on this page is unclear.';

  @override
  String get msg_barcode_skipped => 'I skipped a barcode on this page.';
}
