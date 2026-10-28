import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/splash.dart';
import 'package:app/messages.dart';
import 'package:app/screens/capture.dart';
import 'package:app/speech.dart';
import 'package:app/touch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';

class FakeSpeaker extends Speaker {
  final said = <String>[];
  String language = 'en';
  @override
  Future<Spoken> utter(String text) async {
    said.add(text);
    return interrupt.contains(text) || interruptOnce.remove(text)
        ? Spoken.cutOff
        : Spoken.finished;
  }

  /// Cut off the first time only, like TalkBack announcing a new screen.
  final interruptOnce = <String>{};

  /// Utterances that TalkBack "speaks over" in tests.
  final interrupt = <String>{};
  @override
  Future<void> stop() async {}

  /// Speech rates set, in order (primary quizzes slow the voice).
  final rates = <double>[];
  double _rate = 1.0;
  @override
  double get rate => _rate;
  @override
  Future<void> setRate(double rate) async => rates.add(_rate = rate);
  @override
  Future<void> setLanguage(String code) async => language = code;
}

const readJson = {
  'tips': <String>[],
  'lines': [
    {'text': 'Food tests', 'confidence': 0.96, 'top': 40, 'label': 'line 1'},
    {
      'text': 'Take 2 tablets every 4 to 6 hours',
      'confidence': 0.52,
      'top': 110,
      'label': 'line 2',
    },
  ],
  'warnings': [
    {'block_index': 1, 'code': 'low_confidence'},
  ],
};

/// Shape of the backend's table output (reader.Table / safety.CellWarning).
const tableJson = {
  ...readJson,
  'tables': [
    {
      'top': 200,
      'label': 'table 1',
      'header': true,
      'rows': [
        [
          {'text': 'Test', 'confidence': 0.99, 'row': 0, 'col': 0},
          {'text': 'Result', 'confidence': 0.99, 'row': 0, 'col': 1},
        ],
        [
          {'text': 'Haemoglobin', 'confidence': 0.9, 'row': 1, 'col': 0},
          {'text': '11.2 g/dL', 'confidence': 0.6, 'row': 1, 'col': 1},
        ],
      ],
    },
  ],
  'cell_warnings': [
    {'table_index': 0, 'row': 1, 'col': 1, 'code': 'low_confidence'},
  ],
};

MaganaApi fakeApi(Map<String, Object?> body) => MaganaApi(
  client: MockClient((req) async {
    expect(req.url.path, '/read');
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

Future<LanguageController> pumpApp(
  WidgetTester tester,
  FakeSpeaker speaker, {
  Map<String, Object?> body = readJson,
  Size size = const Size(390, 844),
  String language = 'en',
  ProfileController? profile,
  TouchToHear? touch,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final controller = LanguageController(Locale(language));
  await tester.pumpWidget(
    MaganaApp(
      api: fakeApi(body),
      speaker: speaker,
      language: controller,
      profile: profile ?? ProfileController(tier: Tier.standard),
      touch: touch,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Opens Capture with a fake picker, takes a photo and lands on the Reader.
Future<void> captureToReader(
  WidgetTester tester, {
  String takePhoto = 'Take photo',
}) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator));
  nav.push(
    MaterialPageRoute(
      builder: (_) => CaptureScreen(
        findCameras: () async => [],
        picker: (_) async => XFile.fromData(utf8.encode('png'), name: 'p.png'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(takePhoto));
  await tester.pumpAndSettle();
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('parses lines, server warnings and table rows in page order', () {
    final r = ReadResult.fromJson(tableJson);
    expect(r.items.map((i) => (i.kind, i.number, i.total)), [
      (ItemKind.line, 1, 2),
      (ItemKind.line, 2, 2),
      (ItemKind.row, 1, 1),
    ]);
    expect(r.items.map((i) => i.unsure), [false, true, true]);
    // Header names each cell; values are kept exactly as printed.
    expect(r.items[2].cells.map((c) => (c.header, c.value, c.unclear)), [
      ('Test', 'Haemoglobin', false),
      ('Result', '11.2 g/dL', false), // low_confidence, not a number code
    ]);
  });

  testWidgets('every Home control is at least 64 px and labelled', (
    tester,
  ) async {
    await pumpApp(tester, FakeSpeaker());
    for (final b
        in find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate()) {
      final size = b.size!;
      expect(
        size.height >= 64 && size.width >= 64,
        isTrue,
        reason: '${b.widget} is $size',
      );
    }
    expect(find.bySemanticsLabel(RegExp('^Read a page')), findsOneWidget);
    expect(find.bySemanticsLabel('Speak a command'), findsOneWidget);
    // The name and the greeting are one heading (TalkBack audit: the logo was a second stop).
    expect(find.bySemanticsLabel(RegExp(r'^Magana\s+Hello')), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets(
    'Capture speaks framing guidance, then Reader reads lines with warnings',
    (tester) async {
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker);
      await captureToReader(tester);

      // Home says what it is first (board 10), then Capture its guidance.
      expect(speaker.said.take(2), ['Magana. 9 choices.', en.framingGuidance]);
      // The fake speaker finishes instantly, so the whole page has been read.
      expect(find.text('Take 2 tablets every 4 to 6 hours'), findsOneWidget);
      expect(
        speaker.said,
        contains(
          "Page read. 2 lines. 1 line is hard to read. Say “what's unclear” to hear where.",
        ),
      );
      expect(speaker.said, contains('Food tests'));
      expect(
        speaker.said,
        contains('Take 2 tablets every 4 to 6 hours. ${en.unclearMark}'),
      );
      expect(speaker.said.last, en.endOfPageHint);
      // The full warning is said on request (and shown for the line, below).
      await tester.ensureVisible(find.bySemanticsLabel(en.whatsUnclear));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(en.whatsUnclear));
      await tester.pump();
      expect(speaker.said.last, en.msg_low_confidence(en.whereLine(2)));

      await tester.tap(find.bySemanticsLabel('Previous line'));
      await tester.pump();
      expect(find.text('Food tests'), findsOneWidget);
      expect(speaker.said.last, 'Food tests');

      await tester.tap(find.bySemanticsLabel('Next line'));
      await tester.pump();
      expect(find.text(en.msg_low_confidence(en.whereLine(2))), findsOneWidget);

      speaker.said.clear();
      await tester.tap(find.bySemanticsLabel('Repeat this line'));
      await tester.pump();
      expect(speaker.said.single, startsWith('Take 2 tablets'));
    },
  );

  testWidgets('a line cut off once is said again, then reading goes on', (
    tester,
  ) async {
    final speaker = FakeSpeaker()..interruptOnce.add('Food tests');
    await pumpApp(tester, speaker);
    await captureToReader(tester);
    await tester.pump(Speaker.retryDelay);
    await tester.pumpAndSettle();
    expect(speaker.said.where((s) => s == 'Food tests'), hasLength(2));
    expect(speaker.said, contains(startsWith('Take 2 tablets')));
    expect(speaker.said.last, en.endOfPageHint);
  });

  testWidgets('TalkBack speaking over a line pauses there, never skips it', (
    tester,
  ) async {
    final speaker = FakeSpeaker()..interrupt.add('Food tests');
    await pumpApp(tester, speaker);
    await captureToReader(tester);
    await tester.pump(Speaker.retryDelay);
    await tester.pumpAndSettle();
    // Said twice (TalkBack cut it off twice), then paused there.
    expect(speaker.said.where((s) => s == 'Food tests'), hasLength(2));
    expect(speaker.said.last, 'Food tests');
    expect(speaker.said, isNot(contains(startsWith('Take 2 tablets'))));
    expect(find.text('Food tests'), findsOneWidget);
    expect(find.bySemanticsLabel(en.playLabel), findsOneWidget);
    // Play carries on from the line that was cut off.
    speaker.interrupt.clear();
    await tester.tap(find.bySemanticsLabel(en.playLabel));
    await tester.pump();
    expect(speaker.said.reversed.skip(2).first, 'Food tests');
    expect(speaker.said, contains(startsWith('Take 2 tablets')));
  });

  testWidgets('table rows are read with column names and a row warning', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker, body: tableJson);
    await captureToReader(tester);
    expect(
      speaker.said,
      contains(
        'Row 1 of 1. Test: Haemoglobin. Result: 11.2 g/dL. ${en.unclearMark}',
      ),
    );
    expect(find.text('Haemoglobin'), findsOneWidget);
  });

  testWidgets('choosing Hausa changes the greeting, the voice and the Reader', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    final language = await pumpApp(tester, speaker);
    await tester.tap(
      find.bySemanticsLabel('App language: English. Change language'),
    );
    await tester.pumpAndSettle();
    // Design 3b: touching a language lets you hear it; "Use Hausa" applies it.
    await tester.tap(find.bySemanticsLabel(RegExp('^Hausa')));
    await tester.pumpAndSettle();
    expect(language.value, const Locale('en'));
    await tester.tap(find.bySemanticsLabel('Use Hausa'));
    await tester.pumpAndSettle();

    final ha = lookupAppLocalizations(const Locale('ha'));
    expect(language.value, const Locale('ha'));
    expect(speaker.language, 'ha');
    expect(find.text('Sannu'), findsOneWidget);
    expect(speaker.said.last, ha.languageChanged('Hausa'));
    expect(
      (await SharedPreferences.getInstance()).getString('app_language'),
      'ha',
    );

    await captureToReader(tester, takePhoto: ha.takePhoto);
    expect(
      speaker.said,
      contains('Take 2 tablets every 4 to 6 hours. ${ha.unclearMark}'),
    );
    expect(find.text(ha.yourPage), findsOneWidget);
  });

  test('every language has every string', () {
    for (final code in ['en', 'ha', 'yo', 'ig']) {
      final l = lookupAppLocalizations(Locale(code));
      expect(l.readPage, isNotEmpty);
      expect(l.unsureSummary(2), isNotEmpty);
    }
  });

  testWidgets('Capture stays put and explains when no text is found', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    await pumpApp(
      tester,
      speaker,
      body: {
        'tips': ['too_dark'],
        'lines': [],
        'warnings': [],
      },
    );
    await captureToReader(tester);
    expect(find.textContaining("It's quite dark"), findsOneWidget);
    expect(speaker.said.last, contains("couldn't find any text"));
  });

  testWidgets('an unreliable number is said and shown as "unclear number"', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    const text = 'Do not take more than @ in 24 hours';
    await pumpApp(
      tester,
      speaker,
      body: {
        'tips': <String>[],
        'lines': [
          {
            'text': text,
            'top': 10,
            'words': [
              for (final w in text.split(' ')) {'text': w, 'confidence': 0.9},
            ],
          },
        ],
        'warnings': [
          {'block_index': 0, 'code': 'unreadable_number', 'word_index': 5},
        ],
      },
    );
    await captureToReader(tester);
    // Said at the spot as "unclear number", never the digit OCR guessed; counted in the summary.
    expect(
      speaker.said,
      contains('Do not take more than unclear number in 24 hours'),
    );
    expect(speaker.said.where((s) => s.contains('@')), isEmpty);
    expect(speaker.said.any((s) => s.contains(en.summaryNumbers(1))), isTrue);
    expect(
      find.textContaining('Do not take more than [unclear number] in 24 hours'),
      findsOneWidget,
    );
  });

  testWidgets('a faint region is announced where it sits on the page', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    await pumpApp(
      tester,
      speaker,
      body: {
        ...readJson,
        'faint_regions': [
          {'code': 'faint_region', 'top': 60, 'bottom': 90, 'where': 'top'},
        ],
      },
    );
    await captureToReader(tester);
    final faint = en.msg_faint_region(en.whereTop);
    final order = speaker.said
        .where((s) => s == 'Food tests' || s == faint || s.startsWith('Take 2'))
        .toList();
    expect(order, ['Food tests', faint, startsWith('Take 2')]);
  });

  test('backend error codes are said in the app language', () async {
    final ha = lookupAppLocalizations(const Locale('ha'));
    final api = MaganaApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': {'code': 'not_allowed_for_tier'},
          }),
          403,
        ),
      ),
    );
    await expectLater(
      api.read(Uint8List(0)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'not_allowed_for_tier',
        ),
      ),
    );
    expect(messageFor(ha, 'not_allowed_for_tier'), ha.msg_not_allowed_for_tier);
    expect(messageFor(ha, 'too_dark'), ha.msg_too_dark);
    expect(messageFor(ha, 'something_new'), ha.readFailed);
  });

  testWidgets('every button and switch can be activated by screen readers', (
    tester,
  ) async {
    // TalkBack, Switch Access, Voice Access and VoiceOver activate a control
    // through its semantics tap action, not by touching the screen.
    final handle = tester.ensureSemantics();
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker);

    expectAccessible(tester, 'Home');
    await tester.tap(
      find.bySemanticsLabel('App language: English. Change language'),
    );
    await tester.pumpAndSettle();
    expectAccessible(tester, 'Language sheet');
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          findCameras: () async => [],
          picker: (_) async =>
              XFile.fromData(utf8.encode('png'), name: 'p.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectAccessible(tester, 'Capture');
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    expectAccessible(tester, 'Reader');
    handle.dispose();
  });

  testWidgets('5 Reader (table): every control labelled, actionable, 64 px', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, FakeSpeaker(), body: tableJson);
    await captureToReader(tester);
    expectAccessible(tester, 'Reader (table)');
    handle.dispose();
  });

  testWidgets('the stacked lockup shows until start-up work is done', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaganaApp(
        api: fakeApi(readJson),
        speaker: FakeSpeaker(),
        language: LanguageController(),
        profile: ProfileController(tier: Tier.standard),
        ready: ready.future,
        firstFrameShown: () async {},
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Magana'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    ready.complete();
    await tester.pump(const Duration(milliseconds: 100));
    // Start-up is done, but the lockup stays for its short minimum.
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(splashMinimum);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('an unread line end is said after the line', (tester) async {
    final speaker = FakeSpeaker();
    await pumpApp(
      tester,
      speaker,
      body: {
        'tips': <String>[],
        'lines': [
          {'text': 'Do not take more', 'top': 10},
        ],
        'warnings': [
          {'block_index': 0, 'code': 'line_end_unclear'},
        ],
      },
    );
    await captureToReader(tester);
    expect(speaker.said, contains('Do not take more. ${en.unclearMark}'));
  });
}
