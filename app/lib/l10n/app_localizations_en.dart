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
      'I can\'t confirm some numbers in this explanation, so I\'ll read the page exactly instead.';

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
  String get quizTitle => 'Biology practice';

  @override
  String quizProgress(int n, int total) {
    return 'WAEC-style · Question $n of $total';
  }

  @override
  String quizScoreLabel(int correct, int answered) {
    return '$correct right out of $answered answered';
  }

  @override
  String get quizSayAnswer => 'Say A, B, C or D';

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
  String quizUnclear(String heard) {
    return 'I heard “$heard”. Please say A, B, C or D.';
  }

  @override
  String get quizNothingHeard =>
      'I did not hear an answer. Say A, B, C or D, or double tap an answer.';

  @override
  String get quizNoVoice =>
      'Spoken answers are not available on this phone. Double tap an answer instead.';

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
  String get quizSource =>
      'Questions written by the Magana team in the style of WAEC Biology. They are not past questions. The questions are in English.';

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
  String get areaMoney => 'Money';

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
}
