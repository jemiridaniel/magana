import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/offline/offline_reader.dart';
import 'package:app/papers.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/questions.dart';
import 'package:app/screens/capture.dart';
import 'package:app/screens/health_worker.dart';
import 'package:app/voice_answers.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;
import 'quiz_test.dart' show FakeVoice;
import 'white_paper_test.dart' show FakePhoto, FakeRecognizer, seen;

final en = lookupAppLocalizations(const Locale('en'));

Map<String, Object?> page(List<String> lines, {List<List<String>>? table}) => {
  'tips': <String>[],
  'lines': [
    for (final (i, t) in lines.indexed)
      {'text': t, 'confidence': 0.97, 'top': 40 + 60 * i},
  ],
  'warnings': <Object>[],
  if (table != null)
    'tables': [
      {
        'top': 400,
        'header': true,
        'rows': [
          for (final (r, row) in table.indexed)
            [
              for (final (c, cell) in row.indexed)
                {'text': cell, 'confidence': 0.97, 'row': r, 'col': c},
            ],
        ],
      },
    ],
};

final medicine = page([
  'Paracetamol 500 mg tablets',
  'Take 2 tablets every 6 hours',
  'Expiry 03/2027', // a type is said only with 3 clear signs (detectPaper)
]);
final report = page(
  ['Full blood count'],
  table: [
    ['Test', 'Result', 'Range'],
    ['Haemoglobin', '10.8 g/dL', '12.0 - 16.0 g/dL'],
  ],
);
final statement = page(
  [
    'Account statement',
    'Opening balance N45,200.00',
    'Closing balance N38,750.00',
  ],
  table: [
    ['Date', 'Description', 'Money out'],
    ['03 Oct 2026', 'Transfer to Ada', 'N2,000.00'],
    ['14 Oct 2026', 'POS purchase supermarket', 'N6,450.00'],
  ],
);
final letter = page(['Dear Sir', 'Your meeting is on Monday']);

class Backend {
  Backend(this.reply);
  Map<String, Object?> reply;
  final modes = <String>[];

  MockClient get client => MockClient((req) async {
    final body = utf8.decode(req.bodyBytes, allowMalformed: true);
    final m = RegExp(r'name="mode"\r\n\r\n(\w+)').firstMatch(body);
    if (m != null) modes.add(m[1]!);
    if (req.url.path == '/triage/questions') {
      return http.Response(
        jsonEncode({
          'source': 'iba',
          'questions': [
            {
              'id': 'fever',
              'type': 'yes_no',
              'text': 'Do you have a fever?',
              'cant_tell': true,
            },
            {
              'id': 'fever_days',
              'type': 'number',
              'ask_if': 'fever',
              'text': 'For how many days?',
              'cant_tell': true,
            },
            {
              'id': 'fits',
              'type': 'yes_no',
              'text': 'Have you had fits?',
              'cant_tell': true,
              'danger_sign': true,
            },
          ],
        }),
        200,
      );
    }
    if (req.url.path == '/triage/assess') {
      return http.Response(
        jsonEncode({
          'priority': 'urgent',
          'message': 'nurse_call_within_2_hours',
        }),
        200,
      );
    }
    return http.Response(jsonEncode(reply), 200);
  });
}

Future<(FakeSpeaker, Backend, FakeVoice)> start(
  WidgetTester tester,
  Map<String, Object?> reply, {
  Tier tier = Tier.standard,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final voice = FakeVoice();
  voiceInput = (tier) => voice..tiers.add(tier);
  dial = (_) async {};
  final backend = Backend(reply);
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
  );
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: backend.client, headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  return (speaker, backend, voice);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

/// Takes the photo through the fake picker from whatever Capture screen is open.
Future<void> takePhoto(WidgetTester tester) async {
  final capture = tester.widget<CaptureScreen>(find.byType(CaptureScreen));
  tester
      .state<NavigatorState>(find.byType(Navigator).last)
      .pushReplacement(
        MaterialPageRoute(
          builder: (_) => CaptureScreen(
            paper: capture.paper,
            detect: capture.detect,
            findCameras: () async => [],
            picker: (_) async =>
                XFile.fromData(utf8.encode('png'), name: 'p.png'),
          ),
        ),
      );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp('^Take photo')));
  await tester.pumpAndSettle();
}

Future<void> openPaper(WidgetTester tester, Pattern card) async {
  await tap(tester, RegExp('^${en.everydayPapers}'));
  await tap(tester, card);
  await takePhoto(tester);
}

void main() {
  group('read any paper: fixed word rules', () {
    Paper? kind(Map<String, Object?> json) =>
        detectPaper(ReadResult.fromJson(json));

    test('medicine, report, statement; a letter is no type at all', () {
      expect(kind(medicine), Paper.medicine);
      expect(kind(report), Paper.report);
      expect(kind(statement), Paper.statement);
      expect(kind(letter), isNull);
    });

    test('a type only when clear: never a guess (Nurse Balogun, build 7)', () {
      expect(kind(page(['Take one tablet'])), isNull);
      // A food container: "ml" and "expiry" are two medicine signs, not enough.
      expect(kind(page(['Groundnut oil 500 ml', 'Expiry 2027'])), isNull);
      // Three medicine signs but two statement signs too: not clear enough.
      expect(
        kind(page(['Tablets 500 mg', 'Expiry 2027', 'Account balance'])),
        isNull,
      );
      expect(kind(page(['Account balance, results and range'])), isNull);
      expect(kind(page(['Paracetamol 500 mg tablets', 'Expiry 2027'])), Paper.medicine);
    });
  });

  group('spoken quick-check answers', () {
    test('yes, no, can\'t tell, else asked again', () {
      expect(yesNo('Yes'), true);
      expect(yesNo('no.'), false);
      expect(yesNo("I can't tell"), 'cant_tell');
      expect(yesNo('mba'), false);
      expect(yesNo('yes no'), isNull);
      // English "I" inside an answer is not Hausa "i" (yes): heard in the ASR test.
      expect(yesNo("No, I haven't."), false);
      expect(yesNo('i'), true);
      expect(yesNo('maybe'), isNull);
    });

    test('days', () {
      expect(days('three days'), 3);
      expect(days('for 2 days'), 2);
      expect(days("don't know"), 'cant_tell');
      expect(days('two or three'), isNull);
      expect(days('99'), isNull);
    });
  });

  testWidgets('E0: Read any paper and Letters & forms', (tester) async {
    final handle = tester.ensureSemantics();
    final (speaker, backend, _) = await start(tester, medicine);
    await tap(tester, RegExp('^${en.everydayPapers}'));
    expect(
      find.bySemanticsLabel('${en.readAnyPaper}. ${en.readAnyPaperDetail}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('^${en.paperLetter}')), findsOneWidget);
    expectAccessible(tester, 'Everyday hub');

    await tap(tester, RegExp('^${en.readAnyPaper}'));
    await takePhoto(tester);
    expect(backend.modes.last, 'letter'); // strict checks whatever the paper
    expect(find.text(en.paperMedicine), findsOneWidget);
    expect(find.text(en.noteMedicine), findsOneWidget);
    expect(
      speaker.said,
      contains(startsWith(en.detectedPaper(en.paperMedicine))),
    );
    handle.dispose();
  });

  testWidgets('Read any paper, type unclear: no type said or shown, just read', (
    tester,
  ) async {
    // A food container (Nurse Balogun, build 7): two medicine-like words only.
    final (speaker, backend, _) = await start(
      tester,
      page(['Groundnut oil 500 ml', 'Expiry 2027']),
    );
    await tap(tester, RegExp('^${en.everydayPapers}'));
    await tap(tester, RegExp('^${en.readAnyPaper}'));
    await takePhoto(tester);
    expect(backend.modes.last, 'letter'); // still the strict checks
    for (final type in [
      en.paperMedicine,
      en.paperLetter,
      en.paperReport,
      en.paperStatement,
    ]) {
      expect(find.text(type), findsNothing);
      expect(speaker.said.where((s) => s.contains(en.detectedPaper(type))), isEmpty);
    }
    expect(find.text(en.yourPage), findsOneWidget);
    expect(speaker.said, contains('Groundnut oil 500 ml'));
  });

  testWidgets('letters: letter mode and the no-advice note', (tester) async {
    final (_, backend, _) = await start(tester, letter);
    await openPaper(tester, RegExp('^${en.paperLetter}'));
    expect(backend.modes.last, 'letter');
    expect(find.text(en.noteLetter), findsOneWidget);
  });

  testWidgets('E1: read again', (tester) async {
    final (speaker, _, _) = await start(tester, medicine);
    await openPaper(tester, RegExp('^${en.paperMedicine}'));
    speaker.said.clear();
    await tap(tester, en.readAgain);
    expect(speaker.said.first, 'Paracetamol 500 mg tablets');
  });

  testWidgets('E2: what does this mean: never interpreted, question saved', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, _, voice) = await start(tester, report);
    await openPaper(tester, RegExp('^${en.paperReport}'));
    voice.replies.add(['is my result bad']);
    await tap(tester, en.askAboutResult);
    expect(
      speaker.said.last,
      '${en.youAsked('is my result bad')} ${en.resultAnswer}',
    );
    expect(
      find.textContaining(en.resultAnswer, findRichText: true),
      findsOneWidget,
    );
    expectAccessible(tester, 'Report: what does this mean');
    await tap(tester, en.saveQuestion);
    expect(speaker.said.last, en.questionSaved);
    final saved = await SavedQuestions.load();
    expect(saved.single, startsWith('is my result bad (about '));

    await tap(tester, en.healthWorkerTitle); // Ibà off: no "Ask a nurse" (features.dart)
    expect(find.text(en.savedQuestionsTitle), findsOneWidget);
    expect(find.text(saved.single), findsOneWidget);
    expectAccessible(tester, 'Health worker with saved questions');
    await tap(tester, en.removeQuestion(saved.single));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.savedQuestionsTitle), findsNothing);
    handle.dispose();
  });

  testWidgets('E3: balances as printed, find a transaction', (tester) async {
    final handle = tester.ensureSemantics();
    // The phone's own reading agrees on every amount, so each one is said (amount_check.dart).
    pageRecognizer = FakeRecognizer(
      FakePhoto([
        for (final (i, t) in [
          'Opening balance N45,200.00',
          'Closing balance N38,750.00',
          '03 Oct 2026 Transfer to Ada N2,000.00',
          '14 Oct 2026 POS purchase supermarket N6,450.00',
        ].indexed)
          seen(t, 1.0, top: 100 + 100 * i),
      ]),
    );
    addTearDown(() => pageRecognizer = MlKitRecognizer());
    final (speaker, _, _) = await start(tester, statement);
    await openPaper(tester, RegExp('^${en.paperStatement}'));
    expect(
      find.text(
        '${en.fromTheStatement}: Opening balance N45,200.00. Closing balance N38,750.00',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expectAccessible(tester, 'Statement reader');
    await tap(tester, en.findTransaction);
    await tester.enterText(find.byType(TextField), '6450');
    await tap(tester, en.findSearch);
    expect(speaker.said.last, contains('POS purchase supermarket'));

    await tap(tester, en.findTransaction);
    await tester.enterText(find.byType(TextField), 'rent');
    await tap(tester, en.findSearch);
    expect(speaker.said.last, en.findNoMatch('rent'));
    handle.dispose();
  });

  testWidgets('E6: answer the quick check by voice', (tester) async {
    final handle = tester.ensureSemantics();
    final (speaker, backend, voice) = await start(tester, medicine);
    tester
        .state<NavigatorState>(find.byType(Navigator).last)
        .push(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
    await tester.pumpAndSettle();
    expectAccessible(tester, 'Quick check with voice');
    voice.replies.add(['maybe']);
    await tap(tester, en.sayYesOrNo);
    expect(speaker.said.last, en.voiceAnswerUnclear('maybe'));
    voice.replies.add(['yes']);
    await tap(tester, en.sayYesOrNo);
    expect(find.text('For how many days?'), findsOneWidget);
    voice.replies.add(['three days']);
    await tap(tester, en.sayYesOrNo);
    voice.replies.add(['no']);
    await tap(tester, en.sayYesOrNo);
    expect(find.text(en.resultTitle), findsOneWidget);
    handle.dispose();
  });

  testWidgets('under 18: no letters or read-any-paper', (tester) async {
    await start(tester, letter, tier: Tier.guided);
    expect(
      find.bySemanticsLabel(RegExp('^${en.everydayPapers}')),
      findsNothing,
    );
  });
}
