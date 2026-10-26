// Read a PDF (backend pdfs.py): choose a file or open one shared with Magana; a
// locked PDF asks for its password, which is sent once and never kept; a reading of
// several pages says "Page 2 of 2" when it gets there.
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/api.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/platform/shared_pdf.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/pdf.dart';
import 'package:app/screens/reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7 made by the test'));

Map<String, dynamic> twoPages() => {
  'tips': [],
  'page_count': 2,
  'pages': [
    {'number': 1, 'source': 'text'},
    {'number': 2, 'source': 'text'},
  ],
  'lines': [
    {'text': 'Opening balance 50,250.50', 'top': 100, 'page': 1, 'words': []},
    {
      'text': 'Closing balance 64,198.00',
      'top': 100100,
      'page': 2,
      'words': [],
    },
  ],
  'tables': [
    {
      'top': 300,
      'page': 1,
      'header': true,
      'rows': [
        [
          {'text': 'Date', 'row': 0, 'col': 0},
          {'text': 'Debit', 'row': 0, 'col': 1},
          {'text': 'Balance', 'row': 0, 'col': 2},
        ],
        [
          {'text': '02 Sep 2026', 'row': 1, 'col': 0},
          {'text': '5,000.00', 'row': 1, 'col': 1},
          {'text': '45,250.50', 'row': 1, 'col': 2},
        ],
      ],
    },
  ],
  'faint_regions': [],
  'warnings': [],
  'cell_warnings': [],
};

/// A stand-in for POST /read-pdf: locked with "482915".
class FakePdfApi {
  final sent = <http.Request>[];
  String? password = '482915';
  List<String> tips = [];

  MockClient get client => MockClient((req) async {
    sent.add(req);
    final body = utf8.decode(req.bodyBytes, allowMalformed: true);
    final given = RegExp(r'name="password"\r\n\r\n([^\r]*)')
        .firstMatch(body)?[1];
    if (password != null && given != password) {
      return http.Response(
        jsonEncode({
          'detail': {
            'code': given == null
                ? 'pdf_password_needed'
                : 'pdf_password_wrong',
          },
        }),
        401,
      );
    }
    return http.Response(jsonEncode({...twoPages(), 'tips': tips}), 200);
  });

  String mode(int i) => RegExp(r'name="mode"\r\n\r\n([^\r]*)')
      .firstMatch(utf8.decode(sent[i].bodyBytes, allowMalformed: true))![1]!;

  bool sentPassword(int i) => utf8
      .decode(sent[i].bodyBytes, allowMalformed: true)
      .contains('name="password"');
}

Future<(FakeSpeaker, FakePdfApi, ProfileController)> start(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  SharedPdf? shared,
  bool locked = true,
  List<String> tips = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  takeSharedPdf = () async {
    final s = shared;
    shared = null;
    return s;
  };
  pickPdf = () async => SharedPdf(pdfBytes, 'statement.pdf');
  final profile = ProfileController(
    tier: tier,
    consentAt: DateTime(2026),
    classLevel: tier == Tier.standard ? ProfileController.notInSchool : 'sss2',
  );
  final speaker = FakeSpeaker();
  final backend = FakePdfApi();
  if (!locked) backend.password = null;
  backend.tips = tips;
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: backend.client, headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  return (speaker, backend, profile);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  final f = find.bySemanticsLabel(label).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Everyday papers: a locked PDF, its password, then every page', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, backend, _) = await start(tester);
    await tap(tester, RegExp('^Everyday papers'));
    await tap(tester, RegExp('^Read a PDF'));
    expectAccessible(tester, 'Read a PDF');

    await tap(tester, 'Choose a PDF');
    expect(backend.sentPassword(0), isFalse);
    expect(
      backend.mode(0),
      'letter',
    ); // worked out from the words, strict checks
    expect(find.text('This PDF is locked'), findsOneWidget);
    expect(
      speaker.said.last,
      startsWith('This PDF is locked. Type its password'),
    );
    expectAccessible(tester, 'PDF password');

    await tap(tester, 'Open the PDF');
    expect(speaker.said.last, 'Type the password first.');
    expect(backend.sent, hasLength(1));

    await tester.enterText(find.byType(TextField), '111111');
    await tap(tester, 'Open the PDF');
    expect(speaker.said.last, startsWith("That password didn't open the PDF"));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty, // not kept, even after a wrong try
    );

    await tester.enterText(find.byType(TextField), '482915');
    await tap(tester, 'Read back');
    expect(speaker.said.last, 'You typed: 4, 8, 2, 9, 1, 5');
    await tap(tester, 'Open the PDF');
    expect(backend.sentPassword(2), isTrue);

    // The reader: a bank statement, with each page announced as it starts.
    expect(find.byType(ReaderScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    final said = speaker.said.join(' | ');
    expect(said, contains('Page 1 of 2. Opening balance 50,250.50'));
    expect(
      said,
      contains('Date: 02 Sep 2026. Debit: 5,000.00. Balance: 45,250.50'),
    );
    expect(said, contains('Page 2 of 2. Closing balance 64,198.00'));
    handle.dispose();
  });

  testWidgets('a PDF shared with Magana opens Read a PDF straight away', (
    tester,
  ) async {
    final (_, backend, _) = await start(
      tester,
      shared: SharedPdf(pdfBytes, 'statement.pdf'),
      locked: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(backend.mode(backend.sent.length - 1), 'letter');
  });

  testWidgets('13–17: a shared PDF is read as schoolwork, never as a paper', (
    tester,
  ) async {
    final (_, backend, _) = await start(
      tester,
      tier: Tier.guided,
      shared: SharedPdf(pdfBytes, 'notes.pdf'),
      locked: false,
    );
    await tester.pumpAndSettle();
    expect(backend.mode(backend.sent.length - 1), 'school');
  });

  testWidgets('Classroom phones ignore shared PDFs', (tester) async {
    final (_, backend, _) = await start(
      tester,
      tier: Tier.classroom,
      shared: SharedPdf(pdfBytes, 'x.pdf'),
    );
    expect(find.byType(PdfScreen), findsNothing);
    expect(backend.sent, isEmpty);
  });

  testWidgets('a money page held back says so first, and shows it', (
    tester,
  ) async {
    final (speaker, _, _) = await start(
      tester,
      shared: SharedPdf(pdfBytes, 'photo-statement.pdf'),
      locked: false,
      tips: ['money_amounts_unreliable', 'reading_incomplete'],
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    final said = speaker.said.join(' | ');
    expect(said, contains("I can't read the amounts on this page reliably"));
    expect(
      said,
      contains(
        "This reading is incomplete. I'll read only the parts I could check.",
      ),
    );
    expect(
      said.indexOf("I can't read the amounts"),
      lessThan(said.indexOf('Opening balance')),
    );
    expect(find.textContaining("I can't read the amounts"), findsOneWidget);
  });
}
