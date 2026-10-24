import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/screens/capture.dart';
import 'package:app/speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSpeaker extends Speaker {
  final said = <String>[];
  String language = 'en';
  @override
  Future<void> say(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> setRate(double rate) async {}
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
    {
      'block_index': 1,
      'spoken':
          "I'm not sure about line 2. Please check it or retake the photo.",
    },
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
    {
      'table_index': 0,
      'row': 1,
      'col': 1,
      'spoken': "I'm not sure about row 2, column 2 of table 1.",
    },
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
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final controller = LanguageController(Locale(language));
  await tester.pumpWidget(
    MaganaApp(api: fakeApi(body), speaker: speaker, language: controller),
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
    expect(r.items[2].cells, [
      ('Test', 'Haemoglobin'),
      ('Result', '11.2 g/dL'),
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
    expect(find.bySemanticsLabel('Hold to speak a command'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Magana'),
      findsOneWidget,
    ); // the logo, announced once
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('layout is a centred column of at most 480 px on wide screens', (
    tester,
  ) async {
    await pumpApp(tester, FakeSpeaker(), size: const Size(1280, 900));
    final scaffold = tester.getRect(find.byType(Scaffold).first);
    expect(scaffold.width, maxContentWidth);
    expect(scaffold.center.dx, 640);
  });

  testWidgets(
    'Capture speaks framing guidance, then Reader reads lines with warnings',
    (tester) async {
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker);
      await captureToReader(tester);

      expect(speaker.said.first, en.framingGuidance);
      // The fake speaker finishes instantly, so the whole page has been read.
      expect(find.text('Take 2 tablets every 4 to 6 hours'), findsOneWidget);
      expect(
        speaker.said,
        contains(
          "Page read. 2 lines. I'm not sure about 1 of them. I'll tell you when we get there.",
        ),
      );
      expect(speaker.said, contains('Food tests'));
      expect(
        speaker.said,
        contains('Take 2 tablets every 4 to 6 hours. ${en.unsureLine(2)}'),
      );
      expect(speaker.said.last, en.endOfPageHint);

      await tester.tap(find.bySemanticsLabel('Previous line'));
      await tester.pump();
      expect(find.text('Food tests'), findsOneWidget);
      expect(speaker.said.last, 'Food tests');

      await tester.tap(find.bySemanticsLabel('Next line'));
      await tester.pump();
      expect(find.text(en.unsureLine(2)), findsOneWidget);

      speaker.said.clear();
      await tester.tap(find.bySemanticsLabel('Repeat this line'));
      await tester.pump();
      expect(speaker.said.single, startsWith('Take 2 tablets'));
    },
  );

  testWidgets('table rows are read with column names and a row warning', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker, body: tableJson);
    await captureToReader(tester);
    expect(
      speaker.said,
      contains(
        'Row 1 of 1. Test: Haemoglobin. Result: 11.2 g/dL. ${en.unsureRow(1)}',
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
    await tester.tap(find.bySemanticsLabel('Hausa'));
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
      contains('Take 2 tablets every 4 to 6 hours. ${ha.unsureLine(2)}'),
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
        'tips': ["It's quite dark. Turn on the torch or move to more light."],
        'lines': [],
        'warnings': [],
      },
    );
    await captureToReader(tester);
    expect(find.textContaining("It's quite dark"), findsOneWidget);
    expect(speaker.said.last, contains("couldn't find any text"));
  });
}
