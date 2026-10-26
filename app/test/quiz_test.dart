import 'package:app/api.dart';
import 'package:app/help_check.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/platform.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/quiz.dart';
import 'package:app/voice_answers.dart' show voiceAnswersReady;
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

final en = lookupAppLocalizations(const Locale('en'));

/// Plays back what the learner "says", one reply per listen.
class FakeVoice extends VoiceInput {
  FakeVoice({this.works = true});
  final bool works;
  int inits = 0;

  /// Every recogniser failed while listening (not "heard nothing").
  bool fails = false;

  @override
  String get name => 'fake';
  final replies = <List<String>>[];
  int listens = 0;
  final languages = <String>[];
  final choices = <AnswerChoices?>[]; // what the quiz asked to choose between
  final tiers = <Tier>[]; // which account asked for a recogniser

  @override
  Future<bool> init() async {
    inits++;
    return works;
  }

  @override
  Future<List<String>> listen({
    String language = 'en',
    AnswerChoices? choices,
  }) async {
    listens++;
    languages.add(language);
    this.choices.add(choices);
    if (fails) throw VoiceStepFailed('every step failed');
    return replies.isEmpty ? const [] : replies.removeAt(0);
  }

  @override
  Future<void> stop() async {}
}

const starch = QuizQuestion(
  id: 'starch-test',
  question: 'Which reagent is used to test for starch?',
  options: [
    "Benedict's solution",
    'Iodine solution',
    'Biuret reagent',
    'Ethanol',
  ],
  answer: 1,
  explanation: 'Iodine solution turns blue-black when starch is present.',
);

const scurvy = QuizQuestion(
  id: 'scurvy',
  question: 'Lack of which vitamin causes scurvy?',
  options: ['Vitamin A', 'Vitamin B1', 'Vitamin C', 'Vitamin D'],
  answer: 2,
  explanation: '',
);

const cross = QuizQuestion(
  id: 'monohybrid',
  question: 'Ratio?',
  options: [
    '1 tall to 1 short',
    '2 tall to 1 short',
    '3 tall to 1 short',
    'All tall',
  ],
  answer: 2,
  explanation: '',
);

int? answered(Heard h) => h is Answered ? h.index : null;

Future<(FakeSpeaker, FakeVoice)> openQuiz(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  bool voiceWorks = true,
  String classLevel = 'sss2',
  String pack = 'Biology practice',
  MaganaApi? api,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final voice = FakeVoice(works: voiceWorks);
  voiceInput = (tier) => voice..tiers.add(tier);
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
    teacherSession: true,
    classLevel: classLevel,
  );
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: api ?? MaganaApi(headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(locale),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  final l = lookupAppLocalizations(locale);
  await tester.tap(find.bySemanticsLabel(RegExp('^${l.practiceQuiz}')));
  await tester.pumpAndSettle();
  speaker.said.clear(); // the list's own announcement
  final card = find.bySemanticsLabel(RegExp('^$pack'));
  await tester.ensureVisible(card.first);
  await tester.pumpAndSettle();
  await tester.tap(card.first);
  // The questions load from the app's assets while a spinner shows.
  for (
    var i = 0;
    i < 20 && find.textContaining(en.quizProgress(1, 10)).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  return (speaker, voice);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

Future<void> say(
  WidgetTester tester,
  FakeVoice voice,
  List<String> words, {
  String? button,
}) async {
  voice.replies.add(words);
  await tap(tester, button ?? en.quizSayAnswer('A, B, C or D'));
}

void main() {
  // Voice answers as shipped: English only (lib/voice_answers.dart).
  setUp(() => voiceAnswersReady = {'en'});
  tearDown(() => voiceAnswersReady = {'en'});

  group('marking rules', () {
    test('a letter on its own, with or without filler words', () {
      for (final (said, want) in [
        ('B', 1),
        ('b.', 1),
        ('bee', 1),
        ('option B', 1),
        ("I think it's C", 2),
        ('see', 2),
        ('Letter D please', 3),
        ('a', 0),
      ]) {
        expect(answered(hearOne(said, starch)), want, reason: said);
      }
    });

    test('the option itself, or a word only that option has', () {
      expect(answered(hearOne('iodine', starch)), 1);
      expect(answered(hearOne('Iodine solution', starch)), 1);
      expect(answered(hearOne('benedict', starch)), 0);
      expect(answered(hearOne('vitamin C', scurvy)), 2);
      expect(answered(hearOne('3 tall to 1 short', cross)), 2);
    });

    test('never guesses', () {
      for (final said in [
        '',
        'solution',
        'A or B',
        'banana',
        'vitamin',
        'B and C',
      ]) {
        expect(hearOne(said, starch), isA<Unclear>(), reason: said);
      }
      expect(hearOne('vitamin', scurvy), isA<Unclear>());
    });

    test('commands', () {
      expect(hearOne('repeat that', starch), isA<Command>());
      expect((hearOne('again', starch) as Command).kind, CommandKind.repeat);
      expect(
        (hearOne('next question', starch) as Command).kind,
        CommandKind.next,
      );
    });

    test('other guesses count only when they all agree', () {
      expect(answered(hear(['umm', 'bee', 'b'], starch)), 1);
      expect(hear(['umm', 'bee', 'see'], starch), isA<Unclear>());
      // The best guess wins over the others.
      expect(answered(hear(['D', 'bee'], starch)), 3);
      expect(hear([], starch), isA<Unclear>());
    });
  });

  test('question bank: 10 team-written questions, all well formed', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final quiz = await Quiz.load();
    expect(quiz.questions, hasLength(10));
    expect(quiz.questions.map((q) => q.id).toSet(), hasLength(10));
    for (final q in quiz.questions) {
      expect(q.options, hasLength(4), reason: q.id);
      expect(q.answer, inInclusiveRange(0, 3), reason: q.id);
      expect(q.explanation, isNotEmpty, reason: q.id);
      // Every option can be chosen by saying its letter or its full text.
      for (var i = 0; i < 4; i++) {
        expect(answered(hearOne(letters[i], q)), i, reason: q.id);
        expect(answered(hearOne(q.options[i], q)), i, reason: '${q.id} $i');
      }
    }
  });

  group('short spoken answers in each language', () {
    test('letters as Yorùbá, Hausa and Igbo speakers say them', () {
      for (final (said, want) in [
        ('bí', 1),
        ('Bí', 1),
        ('dí', 3),
        ('sí', 2),
        ('à', 0),
        ('bi', 1),
      ]) {
        expect(answered(hearOne(said, starch)), want, reason: said);
      }
    });

    const tf = QuizQuestion(
      id: 'tf',
      question: 'Iodine turns blue-black with starch.',
      options: ['True', 'False'],
      answer: 0,
      explanation: '',
      type: 'true_false',
    );

    test('true or false, in four languages', () {
      for (final (said, want) in [
        ('true', 0),
        ('false', 1),
        ('yes', 0),
        ('no', 1),
        ('bẹ́ẹ̀ni', 0),
        ('rárá', 1),
        ('i', 0),
        ("a'a", 1),
        ('ee', 0),
        ('mba', 1),
        ("I think it's false", 1),
        // The words themselves (added after the quiz-answer ASR test).
        ('gaskiya', 0),
        ('ƙarya', 1),
        ('òótọ́', 0),
        ('irọ́', 1),
        ('eziokwu', 0),
        ('ụgha', 1),
      ]) {
        expect(answered(hearOne(said, tf)), want, reason: said);
      }
      expect(hearOne('true false', tf), isA<Unclear>());
      expect(tf.spokenAnswer(0), 'True');
    });
  });

  testWidgets('spoken answer: confirmed first, then marked right', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, voice) = await openQuiz(tester);
    expect(find.textContaining(en.quizProgress(1, 10)), findsOneWidget);
    expect(speaker.said.last, contains('Question 1 of 10'));
    expect(speaker.said.last, contains('B, Iodine solution.'));
    expect(speaker.said.last, endsWith(en.quizSayAnswer('A, B, C or D')));
    expectAccessible(tester, 'Quiz');

    await say(tester, voice, ['bee']);
    expect(voice.listens, 1);
    expect(voice.languages, ['en']); // the quiz is in English
    // Not marked yet: "You said B. Is that right?"
    expect(speaker.said.last, en.quizConfirm('B'));
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
    expect(find.bySemanticsLabel(en.quizSayYesOrNo), findsOneWidget);
    expectAccessible(tester, 'Quiz confirming');

    await say(tester, voice, ['yes'], button: en.quizSayYesOrNo);
    final right =
        '${en.quizCorrect('B')} '
        'Iodine solution turns blue-black when starch is present.';
    expect(find.text(right), findsOneWidget);
    expect(speaker.said.last, right);
    expect(
      find.bySemanticsLabel('B. Iodine solution, ${en.quizYourAnswerRight}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a misheard answer is never marked wrong', (tester) async {
    final (speaker, voice) = await openQuiz(tester);
    // The learner meant B; the recogniser heard A.
    await say(tester, voice, ['A']);
    expect(speaker.said.last, en.quizConfirm('A'));
    await say(tester, voice, ['no'], button: en.quizSayYesOrNo);
    expect(speaker.said.last, en.quizSayAgain);
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(en.quizYourAnswerWrong)), findsNothing);
    // Second failed try: tap instead.
    await say(tester, voice, ['A']);
    await tap(tester, en.quizConfirmNo);
    expect(speaker.said.last, en.quizTapInstead);
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
    await tap(tester, 'B. Iodine solution');
    expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
  });

  testWidgets('wrong answer, confirmed by tapping Yes: says the right one', (
    tester,
  ) async {
    final (speaker, voice) = await openQuiz(tester);
    await say(tester, voice, ['option a']);
    await tap(tester, en.quizConfirmYes('A'));
    expect(
      speaker.said.last,
      startsWith(en.quizWrong('A', 'B, Iodine solution')),
    );
    expect(
      find.bySemanticsLabel(
        "A. Benedict's solution, ${en.quizYourAnswerWrong}",
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('B. Iodine solution, ${en.quizRightAnswer}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 1)), findsOneWidget);
    // Answered options stay enabled (full contrast); touching one again
    // repeats the verdict and changes nothing.
    final verdict = speaker.said.last;
    await tap(tester, 'B. Iodine solution, ${en.quizRightAnswer}');
    expect(speaker.said.last, verdict);
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 1)), findsOneWidget);
    expectAccessible(tester, 'Quiz after answering');
  });

  testWidgets('unclear, then silent: tap instead; marks nothing', (
    tester,
  ) async {
    final (speaker, voice) = await openQuiz(tester);
    await say(tester, voice, ['banana bread']);
    expect(speaker.said.last, en.quizUnclear('banana bread', 'A, B, C or D'));
    await say(tester, voice, []);
    expect(speaker.said.last, en.quizTapInstead); // second failed try
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
    // Still answerable by voice.
    await say(tester, voice, ['iodine']);
    await say(tester, voice, ['yes'], button: en.quizSayYesOrNo);
    expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
  });

  testWidgets('voice commands: repeat and next', (tester) async {
    final (speaker, voice) = await openQuiz(tester);
    final question = speaker.said.last;
    await say(tester, voice, ['repeat']);
    expect(speaker.said.last, question);
    await say(tester, voice, ['next']);
    expect(find.textContaining(en.quizProgress(2, 10)), findsOneWidget);
  });

  testWidgets(
    'no recogniser: checked before the Say button shows; it never appears',
    (tester) async {
      final (speaker, voice) = await openQuiz(tester, voiceWorks: false);
      expect(voice.inits, 1);
      expect(
        find.bySemanticsLabel(en.quizSayAnswer('A, B, C or D')),
        findsNothing,
      );
      // Said once, with the first question, and shown; never "I did not hear".
      expect(speaker.said.first, endsWith(en.quizVoiceUnavailable));
      expect(find.text(en.quizVoiceUnavailable), findsOneWidget);
      expect(
        speaker.said,
        isNot(contains(en.quizNothingHeard('A, B, C or D'))),
      );
      expect(voice.listens, 0);
      await tap(tester, 'B. Iodine solution');
      expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
      await tap(tester, en.quizNext);
      expect(speaker.said.last, endsWith(en.quizTapAnswer));
    },
  );

  testWidgets(
    'every recogniser fails while listening: "not available", not "did not hear"',
    (tester) async {
      final (speaker, voice) = await openQuiz(tester);
      voice.fails = true;
      await tap(tester, en.quizSayAnswer('A, B, C or D'));
      expect(speaker.said.last, en.quizVoiceUnavailable);
      expect(
        speaker.said,
        isNot(contains(en.quizNothingHeard('A, B, C or D'))),
      );
      expect(
        find.bySemanticsLabel(en.quizSayAnswer('A, B, C or D')),
        findsNothing,
      );
      await tap(tester, 'B. Iodine solution');
      expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
    },
  );

  testWidgets('"I did not hear an answer" only after really listening', (
    tester,
  ) async {
    final (speaker, voice) = await openQuiz(tester);
    await say(tester, voice, const []);
    expect(voice.listens, 1);
    expect(speaker.said.last, en.quizNothingHeard('A, B, C or D'));
  });

  group('on the web', () {
    setUp(() => runningOnWeb = true);
    tearDown(() => runningOnWeb = false);

    testWidgets('keys A to D answer, like tapping', (tester) async {
      final (speaker, _) = await openQuiz(tester);
      expect(
        speaker.said.first,
        endsWith(
          '${en.quizSayAnswer('A, B, C or D')}. ${en.quizKeysHint('A, B, C or D')}',
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
      expect(speaker.said.last, startsWith(en.quizCorrect('B')));
    });

    testWidgets('no voice: "tap or click, or press A, B, C or D"', (
      tester,
    ) async {
      final (speaker, _) = await openQuiz(tester, voiceWorks: false);
      expect(
        speaker.said.first,
        endsWith(en.quizVoiceUnavailableWeb('A, B, C or D')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(en.quizScoreLabel(0, 1)), findsOneWidget);
      await tap(tester, en.quizNext);
      expect(speaker.said.last, endsWith(en.quizKeysHint('A, B, C or D')));
    });
  });

  testWidgets('ten questions, then the result', (tester) async {
    final (speaker, voice) = await openQuiz(tester);
    for (var i = 0; i < 10; i++) {
      await say(tester, voice, ['A']);
      await say(tester, voice, ['yes'], button: en.quizSayYesOrNo);
      await tap(tester, i < 9 ? en.quizNext : en.quizFinish);
    }
    // Only the malaria question's answer is A.
    expect(find.text(en.quizResult(1, 10)), findsOneWidget);
    expect(speaker.said.last, en.quizResult(1, 10));
    await tap(tester, en.quizAgain);
    expect(find.textContaining(en.quizProgress(1, 10)), findsOneWidget);
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
  });

  testWidgets(
    'after the result: "Did you do this quiz on your own?" (board 8)',
    (tester) async {
      helpCheckEnabled = true;
      addTearDown(() => helpCheckEnabled = false);
      final (_, voice) = await openQuiz(tester);
      for (var i = 0; i < 10; i++) {
        await say(tester, voice, ['A']);
        await say(tester, voice, ['yes'], button: en.quizSayYesOrNo);
        await tap(tester, i < 9 ? en.quizNext : en.quizFinish);
      }
      expect(find.text(en.helpCheckQuiz), findsOneWidget);
      await tester.tap(find.text(en.helpOwn));
      await tester.pumpAndSettle();
      final [record] = await HelpLog.load();
      expect((record.task, record.answer), (HelpTask.quiz, HelpAnswer.own));
    },
  );

  for (final tier in Tier.values) {
    testWidgets('${tier.name}: the recogniser is chosen for this account', (
      tester,
    ) async {
      final (_, voice) = await openQuiz(tester, tier: tier);
      expect(find.textContaining(en.quizProgress(1, 10)), findsOneWidget);
      await say(tester, voice, ['B']);
      expect(voice.tiers.toSet(), {tier});
    });
  }

  group('closed set', () {
    testWidgets(
      'the quiz asks the recogniser to choose between its own answers',
      (tester) async {
        final (_, voice) = await openQuiz(tester);
        await say(tester, voice, ['B']);
        expect(voice.choices.last?.kind, 'letters');
        expect(voice.choices.last?.count, 4);
        await say(tester, voice, ['yes'], button: en.quizSayYesOrNo);
        expect(voice.choices.last?.kind, 'yes_no'); // the confirm step
        expect(voice.languages.toSet(), {'en'});
      },
    );

    testWidgets('not sure: asked again, never "I did not hear an answer"', (
      tester,
    ) async {
      final (speaker, voice) = await openQuiz(tester);
      await say(tester, voice, [notSure]);
      expect(speaker.said.last, en.quizNotSure);
      expect(speaker.said, isNot(contains(startsWith('I did not hear'))));
      expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
    });

    testWidgets('a language not on the ready list: Say is hidden', (
      tester,
    ) async {
      voiceAnswersReady = {};
      final (speaker, voice) = await openQuiz(tester);
      expect(voice.inits, 0);
      expect(
        find.bySemanticsLabel(en.quizSayAnswer('A, B, C or D')),
        findsNothing,
      );
      expect(speaker.said.first, endsWith(en.quizVoiceNotReady('English')));
    });

    testWidgets(
      'a language under 80% in the closed-set test: tapping by default',
      (tester) async {
        final ha = lookupAppLocalizations(const Locale('ha'));
        final (speaker, voice) = await openQuiz(
          tester,
          locale: const Locale('ha'),
          pack: ha.quizSubjectTitle('Biology'),
        );
        expect(voice.inits, 0); // not even tried
        expect(
          find.bySemanticsLabel(ha.quizSayAnswer('A, B, C ko D')),
          findsNothing,
        );
        expect(speaker.said.first, endsWith(ha.quizVoiceNotReady('Hausa')));
        await tester.tap(find.bySemanticsLabel(RegExp(r'^B\. ')));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(ha.quizScoreLabel(1, 1)), findsOneWidget);
      },
    );
  });
}
