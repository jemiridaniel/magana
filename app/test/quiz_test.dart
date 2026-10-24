import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/quiz.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

final en = lookupAppLocalizations(const Locale('en'));

/// Plays back what the learner "says", one reply per listen.
class FakeVoice implements VoiceInput {
  FakeVoice({this.works = true});
  final bool works;
  final replies = <List<String>>[];
  int listens = 0;
  final languages = <String>[];

  @override
  Future<bool> init() async => works;

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    listens++;
    languages.add(language);
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
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final voice = FakeVoice(works: voiceWorks);
  voiceInput = () => voice;
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
    teacherSession: true,
  );
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp('^${en.practiceQuiz}')));
  // The questions load from the app's assets while a spinner shows.
  for (
    var i = 0;
    i < 20 && find.text(en.quizProgress(1, 10)).evaluate().isEmpty;
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
  List<String> words,
) async {
  voice.replies.add(words);
  await tap(tester, en.quizSayAnswer);
}

void main() {
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

  testWidgets('spoken answer marked right, read aloud, TalkBack labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, voice) = await openQuiz(tester);
    expect(find.text(en.quizProgress(1, 10)), findsOneWidget);
    expect(speaker.said.last, contains('Question 1 of 10'));
    expect(speaker.said.last, contains('B, Iodine solution.'));
    expect(speaker.said.last, endsWith(en.quizSayAnswer));
    expectAccessible(tester, 'Quiz');

    await say(tester, voice, ['bee']);
    expect(voice.listens, 1);
    expect(voice.languages, ['en']); // the quiz is in English
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

  testWidgets('wrong answer: says the right one and marks it', (tester) async {
    final (speaker, voice) = await openQuiz(tester);
    await say(tester, voice, ['option a']);
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

  testWidgets('unclear or silent: asks again and marks nothing', (
    tester,
  ) async {
    final (speaker, voice) = await openQuiz(tester);
    await say(tester, voice, ['banana bread']);
    expect(speaker.said.last, en.quizUnclear('banana bread'));
    await say(tester, voice, []);
    expect(speaker.said.last, en.quizNothingHeard);
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
    // Still answerable.
    await say(tester, voice, ['iodine']);
    expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
  });

  testWidgets('voice commands: repeat and next', (tester) async {
    final (speaker, voice) = await openQuiz(tester);
    final question = speaker.said.last;
    await say(tester, voice, ['repeat']);
    expect(speaker.said.last, question);
    await say(tester, voice, ['next']);
    expect(find.text(en.quizProgress(2, 10)), findsOneWidget);
  });

  testWidgets('no recogniser: says so, double tap still answers', (
    tester,
  ) async {
    final (speaker, voice) = await openQuiz(tester, voiceWorks: false);
    await tap(tester, en.quizSayAnswer);
    expect(speaker.said.last, en.quizNoVoice);
    expect(voice.listens, 0);
    await tap(tester, 'B. Iodine solution');
    expect(find.bySemanticsLabel(en.quizScoreLabel(1, 1)), findsOneWidget);
  });

  testWidgets('ten questions, then the result', (tester) async {
    final (speaker, voice) = await openQuiz(tester);
    for (var i = 0; i < 10; i++) {
      await say(tester, voice, ['A']);
      await tap(tester, i < 9 ? en.quizNext : en.quizFinish);
    }
    // Only the malaria question's answer is A.
    expect(find.text(en.quizResult(1, 10)), findsOneWidget);
    expect(speaker.said.last, en.quizResult(1, 10));
    await tap(tester, en.quizAgain);
    expect(find.text(en.quizProgress(1, 10)), findsOneWidget);
    expect(find.bySemanticsLabel(en.quizScoreLabel(0, 0)), findsOneWidget);
  });

  for (final tier in [Tier.guided, Tier.classroom]) {
    testWidgets('${tier.name}: the quiz is open to learners', (tester) async {
      await openQuiz(tester, tier: tier);
      expect(find.text(en.quizProgress(1, 10)), findsOneWidget);
    });
  }
}
