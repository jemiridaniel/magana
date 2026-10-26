// Board 8 "Did you need help?": asked once a day after a finished page, PDF or quiz; voice or
// tap; only the date, task and answer kept; class learners who share send daily totals.
import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/help_check.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/tasks.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, captureToReader;
import 'quiz_test.dart' show FakeVoice;

final en = lookupAppLocalizations(const Locale('en'));

/// Five lines: 80% is four of them.
final fiveLines = {
  'tips': <String>[],
  'lines': [
    for (var i = 1; i <= 5; i++)
      {'text': 'Line $i of the page.', 'confidence': 0.96, 'top': i * 40},
  ],
  'warnings': <Object>[],
};

const link = ClassLink(
  token: 'tok',
  status: 'active',
  className: 'SS2 Science',
  level: 'sss2',
);

Future<(FakeSpeaker, FakeVoice, List<Map>)> start(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  ClassLink? classLink,
  bool sharing = false,
}) async {
  SharedPreferences.setMockInitialValues({'share_score': sharing});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final voice = FakeVoice();
  voiceInput = (_) => voice;
  final sent = <Map>[];
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
    teacherSession: true,
    link: classLink,
  );
  final client = MockClient((req) async {
    if (req.url.path == '/learner/progress') {
      sent.add({'headers': req.headers, 'body': jsonDecode(req.body) as Map});
      return http.Response(jsonEncode({'code': 'progress_shared'}), 200);
    }
    if (req.url.path == '/learner/me') {
      return http.Response(
        jsonEncode({
          'status': 'active',
          'class': {'name': 'SS2 Science', 'level': 'sss2'},
        }),
        200,
      );
    }
    return http.Response(jsonEncode(fiveLines), 200);
  });
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: client, headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  return (speaker, voice, sent);
}

Finder sheet() => find.text(en.helpCheckPage);

void main() {
  setUp(() => helpCheckEnabled = true);
  tearDown(() => helpCheckEnabled = false);

  test(
    'spoken answers: yes, some help, skip; anything else is asked again',
    () {
      expect(matchHelpAnswer('Yes'), HelpAnswer.own);
      expect(matchHelpAnswer('yes on my own'), HelpAnswer.own);
      expect(matchHelpAnswer('yes, I needed some help'), HelpAnswer.someHelp);
      expect(matchHelpAnswer('some help'), HelpAnswer.someHelp);
      expect(matchHelpAnswer('skip'), HelpAnswer.skip);
      expect(matchHelpAnswer('not today'), HelpAnswer.skip);
      // The app languages (drafts for native review).
      expect(matchHelpAnswer('eh'), HelpAnswer.own);
      expect(matchHelpAnswer('taimako'), HelpAnswer.someHelp);
      expect(matchHelpAnswer('bẹ́ẹ̀ni'), HelpAnswer.own);
      expect(matchHelpAnswer('ìrànlọ́wọ́'), HelpAnswer.someHelp);
      expect(matchHelpAnswer('ee'), HelpAnswer.own);
      expect(matchHelpAnswer('wụfee'), HelpAnswer.skip);
      expect(matchHelpAnswer('banana'), isNull);
      expect(matchHelpAnswer('I think so'), isNull);
    },
  );

  test(
    'kept: date, task and answer only; once a day; 90 days; totals',
    () async {
      SharedPreferences.setMockInitialValues({});
      final day = DateTime(2026, 11, 2, 9);
      expect(await HelpLog.askedToday(now: day), isFalse);
      await HelpLog.record(HelpTask.page, HelpAnswer.own, now: day);
      expect(await HelpLog.askedToday(now: day), isTrue);
      expect(
        await HelpLog.askedToday(now: day.add(const Duration(days: 1))),
        isFalse,
      );
      await HelpLog.record(HelpTask.quiz, HelpAnswer.someHelp, now: day);
      await HelpLog.record(HelpTask.pdf, HelpAnswer.skip, now: day);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('help_answers'), [
        '2026-11-02|page|own',
        '2026-11-02|quiz|someHelp',
        '2026-11-02|pdf|skip',
      ]);
      expect((await HelpLog.totals())['2026-11-02'], (own: 1, helped: 1));
      // After 90 days the old answers go.
      await HelpLog.record(
        HelpTask.page,
        HelpAnswer.own,
        now: day.add(const Duration(days: 91)),
      );
      expect(prefs.getStringList('help_answers'), ['2027-02-01|page|own']);
    },
  );

  testWidgets(
    'after a finished page: the sheet, tap Yes, not asked again today',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (speaker, _, sent) = await start(tester);
      await captureToReader(tester);
      expect(sheet(), findsOneWidget);
      expect(speaker.said, contains('${en.helpCheckPage} ${en.helpCheckHow}'));
      expect(find.text(en.helpCheckNotePhone), findsOneWidget); // an adult
      expectAccessible(tester, 'Did you need help?');
      await tester.tap(find.text(en.helpOwn));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(speaker.said.last, en.helpCheckThanks);
      expect((await HelpLog.load()).single.answer, HelpAnswer.own);
      expect(sent, isEmpty); // adults: kept on the phone only
      // A second page today: not asked.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await captureToReader(tester);
      expect(sheet(), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('by voice: "some help"', (tester) async {
    final (_, voice, _) = await start(tester);
    voice.replies.add(['I needed some help']);
    await captureToReader(tester);
    expect(sheet(), findsNothing);
    expect((await HelpLog.load()).single.answer, HelpAnswer.someHelp);
  });

  testWidgets('a word it doesn\'t know is never an answer; tap still works', (
    tester,
  ) async {
    final (speaker, voice, _) = await start(tester);
    voice.replies.add(['banana']);
    await captureToReader(tester);
    expect(sheet(), findsOneWidget);
    expect(speaker.said.last, en.helpCheckNotHeard);
    expect(await HelpLog.load(), isEmpty);
    await tester.tap(find.text(en.helpSkip));
    await tester.pumpAndSettle();
    expect((await HelpLog.load()).single.answer, HelpAnswer.skip);
  });

  testWidgets('read to the end; closing the sheet counts as Skip', (
    tester,
  ) async {
    await start(tester);
    final voice = FakeVoice(works: false);
    voiceInput = (_) => voice;
    await captureToReader(tester);
    // Read to the end on its own: asked. (Closing the sheet counts as Skip.)
    expect(sheet(), findsOneWidget);
    Navigator.of(tester.element(sheet())).pop();
    await tester.pumpAndSettle();
    expect((await HelpLog.load()).single.answer, HelpAnswer.skip);
  });

  testWidgets('a Classroom session is never asked (nothing is kept)', (
    tester,
  ) async {
    await start(tester, tier: Tier.classroom);
    await captureToReader(tester);
    expect(sheet(), findsNothing);
    expect(await HelpLog.load(), isEmpty);
  });

  testWidgets(
    'a learner in a class who shares: daily totals only, never the page',
    (tester) async {
      final (_, _, sent) = await start(tester, classLink: link, sharing: true);
      sent.clear(); // anything sent at start-up
      await captureToReader(tester);
      expect(find.text(en.helpCheckNoteClass), findsOneWidget);
      await tester.tap(find.text(en.helpSome));
      await tester.pumpAndSettle();
      final last = sent.last;
      expect(last['headers']['x-magana-learner'], 'tok');
      final days = (last['body'] as Map)['days'] as Map;
      expect(days.values.single, {'pages': 1, 'own': 0, 'helped': 1});
      expect(jsonEncode(last['body']), isNot(contains('Line')));
    },
  );

  testWidgets('in a class but not sharing: nothing is sent', (tester) async {
    final (_, _, sent) = await start(tester, classLink: link);
    await captureToReader(tester);
    expect(find.text(en.helpCheckNotePhone), findsOneWidget);
    await tester.tap(find.text(en.helpOwn));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  });

  test('the payload: pages from the task log, answers by day', () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 11, 2, 12);
    await TaskLog.record(TaskKind.readSchool, now: now);
    await TaskLog.record(TaskKind.readSchool, now: now);
    await TaskLog.record(TaskKind.quiz, now: now);
    await HelpLog.record(HelpTask.page, HelpAnswer.own, now: now);
    await TaskLog.record(
      TaskKind.readSchool,
      now: now.subtract(const Duration(days: 40)),
    );
    expect(await ProgressShare.payload(now: now), {
      '2026-11-02': {'pages': 2, 'own': 1, 'helped': 0},
    });
  });
}
