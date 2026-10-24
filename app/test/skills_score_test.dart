import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/lessons.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/speech.dart';
import 'package:app/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

final en = lookupAppLocalizations(const Locale('en'));
final now = DateTime(2026, 10, 24, 12);

List<TaskRecord> tasks(TaskKind kind, int n, {int daysAgo = 1}) => [
  for (var i = 0; i < n; i++)
    (kind: kind, at: now.subtract(Duration(days: daysAgo))),
];

String stored(TaskKind kind, int daysAgo) =>
    '${kind.name}|${DateTime.now().subtract(Duration(days: daysAgo)).toIso8601String()}';

Future<FakeSpeaker> openApp(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
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
  return speaker;
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pump();
  await settle(tester);
}

/// Lets asset and storage loads finish while a spinner shows.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

const basics = 'Phone basics: moving around with TalkBack';
const photos = 'Taking clear photos of pages';
const money = 'Money: reading a bank statement safely';

void main() {
  group('Independence Score', () {
    test('nothing done yet: 0, areas follow the tier', () {
      final s = IndependenceScore.from([], Tier.standard, now: now);
      expect(s.overall, 0);
      expect(s.byArea.keys, Area.values);
      expect(IndependenceScore.from([], Tier.guided, now: now).byArea.keys, [
        Area.learning,
        Area.skills,
      ]);
    });

    test('tasks in the last 30 days against each target, capped at 100', () {
      final s = IndependenceScore.from(
        [
          ...tasks(TaskKind.readSchool, 4),
          ...tasks(TaskKind.quiz, 1),
          ...tasks(TaskKind.readSchool, 9, daysAgo: 40), // too old
          ...tasks(TaskKind.readMedicine, 3),
          ...tasks(TaskKind.readReport, 3),
          ...tasks(TaskKind.readStatement, 1),
        ],
        Tier.standard,
        now: now,
      );
      expect(s.byArea, {
        Area.learning: 50,
        Area.health: 100,
        Area.money: 25,
        Area.skills: 0,
      });
      expect(s.overall, 44); // (50 + 100 + 25 + 0) / 4
    });

    test('this week counts only the last 7 days', () {
      final s = IndependenceScore.from(
        [
          ...tasks(TaskKind.readSchool, 2, daysAgo: 2),
          ...tasks(TaskKind.readSchool, 5, daysAgo: 10),
          ...tasks(TaskKind.lesson, 1, daysAgo: 0),
        ],
        Tier.guided,
        now: now,
      );
      expect(s.thisWeek, {TaskKind.readSchool: 2, TaskKind.lesson: 1});
    });

    test('task log keeps 90 days on this phone', () async {
      SharedPreferences.setMockInitialValues({
        'tasks': [stored(TaskKind.quiz, 100), stored(TaskKind.quiz, 3), 'junk'],
      });
      await TaskLog.record(TaskKind.readStatement);
      final log = await TaskLog.load();
      expect(log.map((r) => r.kind), [TaskKind.quiz, TaskKind.readStatement]);
    });
  });

  test('three sample lessons; the money one is 18+', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final lessons = await Lesson.load();
    expect(lessons.map((l) => l.title), [basics, photos, money]);
    for (final l in lessons) {
      expect(l.steps.length, greaterThanOrEqualTo(4), reason: l.id);
      expect(l.practice, isNotNull, reason: l.id);
    }
    expect(lessons.last.feature, Feature.everydayMoney);
  });

  testWidgets('skills: play a lesson to the end, it counts once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final speaker = await openApp(tester);
    // Built now: TalkBack no longer says "Coming soon".
    for (final chip in [en.skills, en.myScore]) {
      expect(tester.getSemantics(find.bySemanticsLabel(chip)).hint, isEmpty);
    }
    await tap(tester, en.skills);
    expect(find.bySemanticsLabel('${en.nextLesson(3)}. $basics'), findsOne);
    expect(find.bySemanticsLabel('$money. ${en.lessonNotStarted}'), findsOne);
    expect(find.bySemanticsLabel(en.practiseWithChampion), findsOne);
    expectAccessible(tester, 'Skills');

    await tap(tester, en.playLesson);
    expect(speaker.said, contains(startsWith('To press the item')));
    expect(speaker.said.last, en.lessonFinished);
    expect(find.text(en.lessonStepOf(6, 6)), findsOne);
    expect(find.bySemanticsLabel(en.practiseNow), findsOne);
    expectAccessible(tester, 'Lesson');

    await tap(tester, en.back);
    expect(find.bySemanticsLabel('$basics. ${en.lessonDone}'), findsOne);
    expect(find.bySemanticsLabel('${en.nextLesson(3)}. $photos'), findsOne);

    // Replaying a finished lesson does not count it again.
    await tap(tester, '$basics. ${en.lessonDone}');
    await tap(tester, en.playLesson);
    expect((await TaskLog.load()).map((r) => r.kind), [TaskKind.lesson]);
    handle.dispose();
  });

  testWidgets('lesson controls: next, previous, pause', (tester) async {
    final speaker = await openApp(tester);
    await tap(tester, en.skills);
    await tap(tester, '$photos. ${en.lessonNotStarted}');
    expect(speaker.said.last, photos);
    expect(find.text(en.lessonStepOf(1, 6)), findsOne);
    await tap(tester, en.nextStep);
    expect(find.text(en.lessonStepOf(2, 6)), findsOne);
    expect(speaker.said.last, startsWith('Find good light'));
    await tap(tester, en.previousStep);
    expect(find.text(en.lessonStepOf(1, 6)), findsOne);
    await tap(tester, en.nextStep);
    await tap(tester, en.back);
    // Progress is kept.
    expect(
      find.bySemanticsLabel('$photos. ${en.lessonStepOf(2, 6)}'),
      findsOne,
    );
  });

  testWidgets('TalkBack speaking over a step pauses the lesson there', (
    tester,
  ) async {
    final speaker = await openApp(tester);
    final lessons = await tester.runAsync(Lesson.load);
    final step3 = lessons!.first.steps[2];
    speaker.interrupt.add(step3);
    await tap(tester, en.skills);
    await tap(tester, en.playLesson);
    await tester.pump(Speaker.retryDelay);
    await tester.pumpAndSettle();
    expect(speaker.said.where((s) => s == step3), hasLength(2));
    expect(speaker.said.last, step3);
    expect(find.text(en.lessonStepOf(3, 6)), findsOne);
    expect(find.bySemanticsLabel(en.playLesson), findsOne); // paused
    expect(await TaskLog.load(), isEmpty); // not finished
  });

  testWidgets('guided (13-17): no money lesson, no Champions', (tester) async {
    await openApp(tester, tier: Tier.guided);
    await tap(tester, en.skills);
    expect(find.bySemanticsLabel(RegExp('^$basics')), findsOne);
    expect(find.bySemanticsLabel(RegExp('^Money')), findsNothing);
    expect(find.bySemanticsLabel(en.practiseWithChampion), findsNothing);
  });

  testWidgets('my score: from the real task log, spoken and labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final speaker = await openApp(
      tester,
      prefs: {
        'tasks': [
          for (var i = 0; i < 5; i++) stored(TaskKind.readSchool, 1),
          stored(TaskKind.readMedicine, 2),
          stored(TaskKind.readMedicine, 20), // not this week
        ],
      },
    );
    await tap(tester, en.myScore);
    // learning 50, health 50, money 0, skills 0 → 25
    expect(
      find.bySemanticsLabel('${en.scoreTitle}: ${en.scoreOutOf(25)}'),
      findsOne,
    );
    expect(find.bySemanticsLabel(en.areaScoreLabel('Learning', 50)), findsOne);
    expect(
      find.bySemanticsLabel(en.areaScoreLabel('Health papers', 50)),
      findsOne,
    );
    expect(find.text(en.weekReadSchool(5)), findsOne);
    expect(find.text(en.weekReadMedicine(1)), findsOne);
    expect(
      speaker.said.last,
      startsWith('${en.scoreTitle}: ${en.scoreOutOf(25)}.'),
    );
    expectAccessible(tester, 'Score');
    handle.dispose();
  });

  testWidgets('my score: nothing yet this week; guided sees two areas', (
    tester,
  ) async {
    await openApp(tester, tier: Tier.guided);
    await tap(tester, en.myScore);
    expect(find.text(en.scoreNothingThisWeek), findsOne);
    expect(
      find.bySemanticsLabel(RegExp('^(Money|Health papers):')),
      findsNothing,
    );
    expect(find.bySemanticsLabel(en.areaScoreLabel('Skills', 0)), findsOne);
  });

  testWidgets('champions: sample profile, steps from real progress', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openApp(tester, prefs: {'lesson_talkback-basics_done': true});
    await tap(tester, en.skills);
    await tap(tester, en.practiseWithChampion);
    expect(find.bySemanticsLabel(RegExp('^${en.championSample}')), findsOne);
    expect(find.text(en.championNotYet), findsOne);
    expect(
      find.bySemanticsLabel('${en.champStepBasics}, ${en.stepDone}'),
      findsOne,
    );
    expect(
      find.bySemanticsLabel('${en.champStepPhotos}, ${en.stepNotDone}'),
      findsOne,
    );
    expect(
      find.bySemanticsLabel('${en.champStepScore}, ${en.stepNotDone}'),
      findsOne,
    );
    expect(find.bySemanticsLabel(RegExp('^Call')), findsNothing);
    expectAccessible(tester, 'Champions');
    handle.dispose();
  });

  test('L3: the starting score is remembered, shown after a week', () async {
    SharedPreferences.setMockInitialValues({});
    final day0 = DateTime(2026, 10, 1);
    expect(await ScoreHistory.since(12, now: day0), isNull); // remembered
    expect(
      await ScoreHistory.since(30, now: day0.add(const Duration(days: 6))),
      isNull,
    );
    expect(
      await ScoreHistory.since(30, now: day0.add(const Duration(days: 15))),
      (start: 12, weeks: 2),
    );
  });

  testWidgets('L3: up from where you started; share with my teacher', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final speaker = await openApp(
      tester,
      prefs: {
        'score_start': 10,
        'score_start_at': DateTime.now()
            .subtract(const Duration(days: 15))
            .toIso8601String(),
        'tasks': [for (var i = 0; i < 5; i++) stored(TaskKind.readSchool, 1)],
      },
    );
    await tap(tester, en.myScore);
    // learning 50 of 4 areas -> 13
    final since = en.scoreUpSince(10, 2);
    expect(find.text(since), findsOneWidget);
    expect(speaker.said.last, contains('$since.'));
    expect(find.text(en.shareScoreNote), findsOneWidget);
    expectAccessible(tester, 'Score with history');
    await tap(tester, en.shareScore);
    expect(await ScoreHistory.sharing(), isTrue);
    handle.dispose();
  });
}
