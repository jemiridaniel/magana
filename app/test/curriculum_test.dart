import 'dart:convert';
import 'dart:io';

import 'package:app/api.dart';
import 'package:app/curriculum.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/quiz.dart';
import 'package:app/screens/quiz.dart';
import 'package:app/voice_answers.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;
import 'quiz_test.dart' show FakeVoice, openQuiz;

final en = lookupAppLocalizations(const Locale('en'));

int words(String s) => RegExp(r'\S+').allMatches(s).length;

/// A teacher's quiz as the backend sends it (/learner/quizzes).
const plantQuiz = {
  'id': 'a1b2c3d4e5f6',
  'title': 'Parts of a plant',
  'level': 'p5',
  'subject': 'basic_science',
  'sample': false,
  'teacher_made': true,
  'questions': [
    {
      'id': 'q1',
      'question': 'Which part of a plant makes food for the plant?',
      'options': ['The leaf', 'The root', 'The flower'],
      'answer': 0,
      'explanation': 'Well done! Leaves make food using sunlight.',
      'picture': 'A drawing of a plant with its leaf, stem and root.',
      'translations': {'yo': 'Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?'},
    },
  ],
};

MaganaApi teacherApi(List<http.Request> sent) => MaganaApi(
  headers: () =>
      ProfileController(tier: Tier.classroom, teacherSession: true).headers,
  client: MockClient((req) async {
    sent.add(req);
    return http.Response(
      jsonEncode({
        'quizzes': [plantQuiz],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

void main() {
  // Voice answers as shipped: English only (lib/voice_answers.dart).
  setUp(() => voiceAnswersReady = {'en'});
  tearDown(() => voiceAnswersReady = {'en'});

  test(
    'the app curriculum matches assets/curriculum.json (and so the backend)',
    () {
      final j =
          jsonDecode(File('assets/curriculum.json').readAsStringSync()) as Map;
      expect(
        [for (final l in j['levels'] as List) l['id']],
        [for (final l in classLevels) l.id],
      );
      expect(
        [for (final l in j['levels'] as List) l['name']],
        [for (final l in classLevels) l.name],
      );
      expect(
        [for (final l in j['levels'] as List) l['band']],
        [for (final l in classLevels) l.band.id],
      );
      expect(j['subjects'], subjectNames);
      expect(j['bands'], {for (final b in Band.values) b.id: bandNames[b]});
      expect(j['band_subjects'], {
        for (final b in Band.values) b.id: bandSubjects[b],
      });
    },
  );

  group('sample packs', () {
    for (final band in Band.values) {
      for (final subject in samplePacks[band]!) {
        test('${band.id} $subject: 10 sample questions that fit the band', () {
          final j = jsonDecode(
            File(samplePackAsset(band, subject)).readAsStringSync(),
          ) as Map<String, dynamic>;
          final quiz = Quiz.fromJson(j);
          expect(quiz.sample, isTrue);
          expect(quiz.band, band);
          expect(bandSubjects[band], contains(quiz.subject));
          expect(j['source'], contains('Magana team'));
          expect(j['review'], startsWith('Sample: to be reviewed by a'));
          expect(quiz.questions, hasLength(10));
          expect({for (final q in quiz.questions) q.id}, hasLength(10));
          for (final q in quiz.questions) {
            expect(q.answer, inInclusiveRange(0, q.options.length - 1));
            if (band.primary) {
              // Primary mode: two or three options, 15 words or fewer.
              expect(q.options.length, inInclusiveRange(2, 3), reason: q.id);
              expect(words(q.question), lessThanOrEqualTo(15), reason: q.id);
            } else {
              expect(q.options.length, 4, reason: q.id);
            }
            expect(q.explanation, isNotEmpty);
          }
          // The right answer isn't always the same letter.
          expect(
            {for (final q in quiz.questions) q.answer}.length,
            greaterThan(1),
          );
        });
      }
    }
  });

  testWidgets('Primary: slower voice, 2 or 3 options, encouraging words', (
    tester,
  ) async {
    final (speaker, _) = await openQuiz(
      tester,
      tier: Tier.classroom,
      classLevel: 'p2',
      pack: 'Mathematics practice',
    );
    expect(speaker.rates, [primaryQuizRate]);
    // Primary: tapping only, in every language; the options are still read out.
    expect(
      speaker.said.first,
      endsWith('A, 5. B, 6. C, 4. ${en.quizVoicePrimaryOff}'),
    );
    expect(find.bySemanticsLabel(RegExp('^Say ')), findsNothing);
    expect(find.textContaining(en.quizSamples), findsWidgets);
    expect(speaker.said.first, startsWith('${en.quizSamples} · '));
    // "What is 2 plus 3?": the answer is on A.
    expect(find.text('What is 2 plus 3?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^B\. ')));
    await tester.pumpAndSettle();
    expect(speaker.said.last, startsWith('Good try! The answer is A, 5.'));
    expect(find.text(en.quizSampleNote), findsOneWidget);
    // Leaving puts the learner's own speed back.
    Navigator.of(tester.element(find.byType(QuizScreen))).pop();
    await tester.pumpAndSettle();
    expect(speaker.rates.last, 1.0);
  });

  testWidgets('JSS and SSS: four options, the usual words, normal speed', (
    tester,
  ) async {
    final (speaker, _) = await openQuiz(
      tester,
      classLevel: 'jss2',
      pack: 'Mathematics practice',
    );
    expect(speaker.rates, isEmpty);
    expect(find.bySemanticsLabel(RegExp(r'^D\. ')), findsOneWidget);
  });

  Future<FakeSpeaker> openList(
    WidgetTester tester, {
    required MaganaApi api,
    required ProfileController profile,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    voiceInput = (_) => FakeVoice();
    final speaker = FakeSpeaker();
    await tester.pumpWidget(
      MaganaApp(
        api: api,
        speaker: speaker,
        language: LanguageController(),
        profile: profile,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^${en.practiceQuiz}')));
    await tester.pumpAndSettle();
    return speaker;
  }

  Future<void> openSession(WidgetTester tester, String code) async {
    await tester.tap(find.bySemanticsLabel(en.quizSessionOpen));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.bySemanticsLabel(en.quizSessionStart));
    await tester.pumpAndSettle();
  }

  for (final tier in Tier.values) {
    testWidgets(
      "${tier.name}: on their own, sample packs only; the server isn't asked",
      (tester) async {
        final sent = <http.Request>[];
        await openList(
          tester,
          api: teacherApi(sent),
          profile: ProfileController(
            tier: tier,
            consentAt: DateTime(2026),
            teacherSession:
                tier == Tier.classroom, // Classroom needs one to open
            classLevel: 'p5',
          ),
        );
        expect(sent, isEmpty);
        expect(find.text('Parts of a plant'), findsNothing);
        expect(find.bySemanticsLabel(en.quizSessionOpen), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^${en.quizSubjectTitle('English')}')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets("a teacher's session code opens that session's quizzes only", (
    tester,
  ) async {
    final sent = <http.Request>[];
    final profile = ProfileController(
      tier: Tier.guided,
      consentAt: DateTime(2026),
      classLevel: 'p5',
    );
    final speaker = await openList(
      tester,
      api: teacherApi(sent),
      profile: profile,
    );
    await openSession(tester, 'k7qm 2p');
    expect(sent.single.url.path, '/learner/quizzes');
    expect(sent.single.url.queryParameters, {'session_code': 'K7QM2P'});
    expect(sent.single.headers['X-Magana-Teacher-Session'], 'yes');
    expect(sent.single.url.queryParameters.containsKey('level'), isFalse);
    expect(find.text('Parts of a plant'), findsOneWidget);
    expect(find.textContaining(en.quizSessionActive('K7QM2P')), findsOneWidget);

    // Open it: the picture is described before the options; primary feedback.
    speaker.said.clear();
    await tester.tap(find.bySemanticsLabel(RegExp('^Parts of a plant')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(
      speaker.said.first,
      contains('Picture: A drawing of a plant with its leaf, stem and root.'),
    );
    expect(find.text(en.quizTeacherNote), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^A\. The leaf')));
    await tester.pumpAndSettle();
    expect(
      speaker.said.last,
      'Well done! You chose A. Well done! Leaves make food using sunlight.',
    );

    // Ending the session: back to sample packs only, never saved.
    Navigator.of(tester.element(find.byType(QuizScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(en.quizSessionEnd));
    await tester.pumpAndSettle();
    expect(find.text('Parts of a plant'), findsNothing);
    expect((profile.sessionCode, profile.teacherSession), (null, false));
  });

  testWidgets('a wrong session code is said, and the session closes', (
    tester,
  ) async {
    final profile = ProfileController(tier: Tier.standard, classLevel: 'p5');
    final speaker = await openList(
      tester,
      api: MaganaApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'detail': {'code': 'session_code_invalid'},
            }),
            422,
          ),
        ),
      ),
      profile: profile,
    );
    await openSession(tester, 'nope');
    expect(speaker.said.last, en.msg_session_code_invalid);
    expect(find.text(en.msg_session_code_invalid), findsOneWidget);
    expect(profile.sessionCode, isNull);
  });

  testWidgets('a checked translation is read in the app language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final voice = FakeVoice();
    voiceInput = (_) => voice;
    final speaker = FakeSpeaker();
    final quiz = Quiz.fromJson(plantQuiz);
    await tester.pumpWidget(
      MaganaApp(
        api: MaganaApi(),
        speaker: speaker,
        language: LanguageController(const Locale('yo')),
        profile: ProfileController(tier: Tier.standard, classLevel: 'p5'),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Navigator).first)).push(
      MaterialPageRoute(builder: (_) => QuizScreen(load: () async => quiz)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?'),
      findsOneWidget,
    );
  });

  testWidgets('an adult not in school sees every band', (tester) async {
    final (_, _) = await openQuiz(
      tester,
      classLevel: ProfileController.notInSchool,
      pack: 'Biology practice',
    );
    // Opened from a list that held all four bands; back to it.
    Navigator.of(tester.element(find.byType(QuizScreen))).pop();
    await tester.pumpAndSettle();
    for (final band in Band.values) {
      expect(find.text(bandNames[band]!), findsOneWidget);
    }
  });

  testWidgets('the quiz list is accessible', (tester) async {
    final handle = tester.ensureSemantics();
    final (_, _) = await openQuiz(tester, classLevel: 'p5', pack: 'English');
    Navigator.of(tester.element(find.byType(QuizScreen))).pop();
    await tester.pumpAndSettle();
    expectAccessible(tester, 'Quiz list');
    handle.dispose();
  });

  testWidgets('without a class, Settings picks the practice level', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final profile = ProfileController(
      tier: Tier.guided,
      consentAt: DateTime(2026),
      classLevel: 'jss1',
    );
    await tester.pumpWidget(
      MaganaApp(
        api: MaganaApi(),
        speaker: FakeSpeaker(),
        language: LanguageController(),
        profile: profile,
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(Pattern label) async {
      await tester.ensureVisible(find.bySemanticsLabel(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(label).first);
      await tester.pumpAndSettle();
    }

    await tap(RegExp('^${en.settings}'));
    await tap(RegExp('^${en.settingsClass}. JSS 1'));
    expect(find.text(en.joinTitle), findsOneWidget);
    await tap(en.joinNoCode);
    // Guided learners are in school: no "not in school".
    expect(find.bySemanticsLabel(en.classNotInSchool), findsNothing);
    await tap(RegExp('^JSS 2'));
    expect(profile.classLevel, 'jss2');
    expect(find.text(en.settings), findsWidgets); // back in Settings
    expect(
      (await SharedPreferences.getInstance()).getString('class_level'),
      'jss2',
    );
  });

  test('the learner app never links to the teacher portal', () {
    final urls = RegExp(r'''https?://[^\s'"]+''');
    final found = <String>[
      for (final f in [
        ...Directory('lib').listSync(recursive: true).whereType<File>(),
      ])
        if (f.path.endsWith('.dart') || f.path.endsWith('.arb'))
          for (final m in urls.allMatches(f.readAsStringSync()))
            if (RegExp(r'portal|teacher|:3000|/quizzes').hasMatch(m[0]!))
              '${f.path}: ${m[0]}',
    ];
    expect(found, isEmpty);
  });

  test('who is offered "Say": English, adults or JSS/SSS, never Primary', () {
    voiceAnswersReady = {'en'}; // as shipped
    VoiceOff? off(
      String lang,
      Tier tier,
      String? level, {
      bool primaryQuiz = false,
    }) => voiceAnswersOff(
      language: lang,
      tier: tier,
      level: levelById(level),
      primaryQuiz: primaryQuiz,
    );
    expect(off('en', Tier.standard, null), isNull); // an adult not in school
    expect(off('en', Tier.standard, 'sss2'), isNull);
    expect(off('en', Tier.guided, 'jss1'), isNull);
    expect(off('en', Tier.classroom, 'jss1'), isNull); // a 12-year-old in JSS 1
    expect(off('en', Tier.classroom, 'p5'), VoiceOff.primary);
    expect(off('en', Tier.guided, 'p6'), VoiceOff.primary);
    expect(
      off('en', Tier.standard, null, primaryQuiz: true),
      VoiceOff.primary,
    ); // a Primary pack
    for (final lang in ['ha', 'yo', 'ig']) {
      expect(off(lang, Tier.standard, 'sss2'), VoiceOff.language);
    }
  });
}
