// Money amounts on receipts, screenshots and bank papers are said only when the server's and the
// phone's readings agree exactly (27 Oct 2026: Tesseract read the "₦" of a dark-mode transfer
// receipt as "4", "#" or "N"); otherwise "I can't read the amount clearly". The currency sign
// is never guessed.
import 'dart:convert';
import 'dart:io';

import 'package:app/amount_check.dart';
import 'package:app/api.dart';
import 'package:app/offline/offline_reader.dart';
import 'package:app/offline/photo_queue.dart';
import 'package:app/papers.dart';
import 'package:app/screens/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'app_test.dart' show FakeSpeaker;
import 'white_paper_test.dart'
    show FakePhoto, FakeRecognizer, FakeVault, cropReads, en, pumpOffline, seen;

Map<String, dynamic> reading(List<String> lines) => {
  'tips': <String>[],
  'lines': [
    for (final (i, t) in lines.indexed)
      {
        'text': t,
        'confidence': 0.97,
        'top': 100 + i * 100,
        'words': [
          for (final w in t.split(' ')) {'text': w, 'confidence': 0.97},
        ],
      },
  ],
  'warnings': <Object>[],
};

List<String> said(Map<String, dynamic> json) => [
  for (final i in ReadResult.fromJson(json).items)
    [
      for (final (n, w) in i.words.indexed)
        if (!i.heldSign(n))
          i.unclearAmounts.contains(n)
              ? '[amount]'
              : i.unclearWords.contains(n)
              ? '[number]'
              : i.currencyUnclear.contains(n)
              ? '${digitsOf(w, sign: i.signBefore(n))} [sign?]'
              : w,
    ].join(' '),
];

void main() {
  group('amountIn', () {
    test('amounts as printed, sign included', () {
      expect(amountIn('₦8,000.00'), '₦8,000.00');
      expect(amountIn('#8,000.00'), '#8,000.00');
      expect(amountIn('N1,250'), 'N1,250');
      expect(amountIn('8,000.00,'), '8,000.00');
      expect(amountIn('45.50'), '45.50');
      expect(amountIn('8,000.00', sign: 'NGN'), 'NGN8,000.00');
      expect(amountIn('₦500'), '₦500');
    });
    test('any currency symbol is a sign', () {
      expect(amountIn('₩8,000.00'), '₩8,000.00');
      expect(isSignWord('₩'), isTrue);
    });
    test('plain numbers, dates and codes are not amounts', () {
      for (final w in [
        '2',
        '2026',
        '0123456789',
        'N5',
        '11:47',
        '27/10/2026',
      ]) {
        expect(amountIn(w), isNull, reason: w);
      }
    });
  });

  test(
    'checked: screenshots (found by the phone or the server) and money papers',
    () {
      final page = ReadResult.fromJson(reading(['Amount: ₦8,000.00']));
      final shot = ReadResult.fromJson({...reading([]), 'screenshot': true});
      expect(checksAmounts(page, mode: 'money'), isTrue);
      expect(checksAmounts(page, mode: 'school', screenshot: true), isTrue);
      expect(checksAmounts(shot, mode: 'school'), isTrue);
      expect(checksAmounts(page, mode: 'school'), isFalse);
      expect(checksAmounts(page, mode: 'health'), isFalse);
    },
  );

  group('confirmAmounts', () {
    final server = reading([
      'Transfer successful',
      'Amount: #8,000.00',
      'Fee: ₦10.75',
      'Account number: 0123456789',
    ]);

    test('agreed exactly: said; same digits, another sign: digits only', () {
      final phone = reading([
        'Transfer successful',
        'Amount: ₦8,000.00', // the phone read the sign the server read as "#"
        'Fee: ₦10.75',
        'Account number: 0123456789',
      ]);
      final out = confirmAmounts(server, phone);
      expect(out['amounts_checked'], 2);
      expect(out['amounts_held'], 0);
      expect(out['amounts_sign_unclear'], 1);
      expect(said(out), [
        'Transfer successful',
        'Amount: 8,000.00 [sign?]',
        'Fee: ₦10.75',
        'Account number: 0123456789', // not an amount: the number rules cover it
      ]);
    });

    test('"₦" read as "4" is a different amount, never said', () {
      final s = reading(['Amount: 48,000.00']);
      final p = reading(['Amount: ₦8,000.00']);
      expect(said(confirmAmounts(s, p)), ['Amount: [amount]']);
    });

    test('both read "₩" (Apple Vision\'s "₦"): the digits, not the sign', () {
      final s = reading(['Amount: ₩8,000.00', 'Fee: \$5.00']);
      expect(said(confirmAmounts(s, s)), [
        'Amount: 8,000.00 [sign?]',
        'Fee: \$5.00',
      ]);
    });

    test('a sign on one reading only: the digits, not the sign', () {
      final s = reading(['Amount: 8,000.00']);
      expect(said(confirmAmounts(s, reading(['Amount: N8,000.00']))), [
        'Amount: 8,000.00 [sign?]',
      ]);
    });

    test('digits must agree exactly, commas and decimal point included', () {
      final s = reading(['Amount: #8,000.00']);
      for (final p in ['₦8000.00', '₦8,000', '₦8,000.50', '₦80,000.00']) {
        expect(said(confirmAmounts(s, reading(['Amount: $p']))), [
          'Amount: [amount]',
        ], reason: p);
      }
    });

    test('an exact match is used before a digits-only one', () {
      final s = reading(['#500.00 ₦500.00']);
      expect(said(confirmAmounts(s, reading(['₦500.00 ₦500.00']))), [
        '500.00 [sign?] ₦500.00',
      ]);
    });

    test('no second reading: every amount is held back', () {
      expect(said(confirmAmounts(server, null)), [
        'Transfer successful',
        'Amount: [amount]',
        'Fee: [amount]',
        'Account number: 0123456789',
      ]);
    });

    test('a separate sign word goes with its amount', () {
      final s = reading(['Total NGN 1,250,000.00']);
      expect(said(confirmAmounts(s, reading(['Total NGN1,250,000.00']))), [
        'Total NGN 1,250,000.00',
      ]);
      // Held back: the bare sign is not said on its own either.
      expect(said(confirmAmounts(s, reading(['Total NGN 1,250,000.50']))), [
        'Total [amount]',
      ]);
      expect(said(confirmAmounts(s, reading(['Total N1,250,000.00']))), [
        'Total 1,250,000.00 [sign?]',
      ]);
    });

    test('each of the phone\'s amounts confirms one of the server\'s', () {
      final s = reading(['₦500.00 ₦500.00']);
      expect(said(confirmAmounts(s, reading(['₦500.00'])))..first, [
        '₦500.00 [amount]',
      ]);
    });

    test('a table cell: digits agreed, sign unclear', () {
      final s = {
        ...reading([]),
        'tables': [
          {
            'header': true,
            'rows': [
              [
                {'text': 'Date', 'row': 0, 'col': 0},
                {'text': 'Amount', 'row': 0, 'col': 1},
              ],
              [
                {'text': '27 Oct', 'row': 1, 'col': 0},
                {'text': '#8,000.00', 'row': 1, 'col': 1},
              ],
            ],
          },
        ],
      };
      final row = ReadResult.fromJson(
        confirmAmounts(s, reading(['27 Oct ₦8,000.00'])),
      ).items.single;
      expect(
        row.cells.map((c) => (c.value, c.unclear, c.amount, c.currencyUnclear)),
        [('27 Oct', false, false, false), ('#8,000.00', false, false, true)],
      );
      final held = ReadResult.fromJson(
        confirmAmounts(s, reading(['27 Oct ₦6,000.00'])),
      ).items.single;
      expect(held.cells.last.amount, isTrue);
    });

    test('a page with no amounts is left exactly as it is', () {
      final s = reading(['Take 2 tablets every 6 hours']);
      expect(identical(confirmAmounts(s, null), s), isTrue);
    });
  });

  group('Capture → Reader', () {
    setUp(
      () => photoQueue = PhotoQueue(
        vault: FakeVault(),
        store: MemoryQueueStore(),
      ),
    );
    tearDown(() => pageRecognizer = MlKitRecognizer());

    Future<FakeSpeaker> readReceipt(
      WidgetTester tester, {
      required List<String> server,
      required List<String> phone,
    }) async {
      final speaker = FakeSpeaker();
      final lines = [
        for (final (i, t) in phone.indexed) seen(t, 1.0, top: 100 + i * 100),
      ];
      pageRecognizer = FakeRecognizer(
        FakePhoto(
          lines,
          crop: (l, t, w, h) => cropReads(
            lines[((t + 40) ~/ 100 - 1).clamp(0, lines.length - 1)],
          )(l, t, w, h),
        ),
      );
      await pumpOffline(
        tester,
        speaker,
        client: MockClient(
          (req) async => http.Response(
            jsonEncode(reading(server)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute(
              builder: (_) => CaptureScreen(
                paper: Paper.statement,
                findCameras: () async => [],
                picker: (_) async =>
                    XFile.fromData(utf8.encode('png'), name: 'r.png'),
              ),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pumpAndSettle();
      return speaker;
    }

    testWidgets('the server read "#", the phone "₦": the digits, no naira', (
      tester,
    ) async {
      final speaker = await readReceipt(
        tester,
        server: ['Amount: #8,000.00', 'Recipient: Ada Okonkwo'],
        phone: ['Amount: ₦8,000.00', 'Recipient: Ada Okonkwo'],
      );
      expect(speaker.said, contains('Amount: 8,000.00, ${en.currencyUnclear}'));
      expect(speaker.said.where((s) => s.contains('naira')), isEmpty);
      expect(speaker.said.where((s) => s.contains('#')), isEmpty);
      expect(speaker.said, contains('Recipient: Ada Okonkwo'));
    });

    testWidgets('the digits differ: the amount is not said', (tester) async {
      final speaker = await readReceipt(
        tester,
        server: ['Amount: 48,000.00'],
        phone: ['Amount: ₦8,000.00'],
      );
      expect(speaker.said, contains('Amount: ${en.amountUnclear}'));
      expect(speaker.said.where((s) => s.contains('8,000')), isEmpty);
    });

    testWidgets('both read "₦8,000.00": said "8,000 naira"', (tester) async {
      final speaker = await readReceipt(
        tester,
        server: ['Amount: ₦8,000.00'],
        phone: ['Amount: ₦8,000.00'],
      );
      expect(speaker.said, contains('Amount: 8,000 naira'));
      expect(speaker.said.where((s) => s.contains(en.amountUnclear)), isEmpty);
    });

    testWidgets('both read "#8,000.00": said as printed, never as naira', (
      tester,
    ) async {
      final speaker = await readReceipt(
        tester,
        server: ['Amount: #8,000.00'],
        phone: ['Amount: #8,000.00'],
      );
      expect(speaker.said, contains('Amount: #8,000.00'));
      expect(speaker.said.where((s) => s.contains('naira')), isEmpty);
    });

    testWidgets('server unreachable: read on the phone, no amount said', (
      tester,
    ) async {
      final speaker = FakeSpeaker();
      final line = seen('Amount: ₦8,000.00', 1.0);
      pageRecognizer = FakeRecognizer(FakePhoto([line], crop: cropReads(line)));
      await pumpOffline(
        tester,
        speaker,
        client: MockClient((_) async => throw const SocketException('off')),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute(
              builder: (_) => CaptureScreen(
                paper: Paper.statement,
                findCameras: () async => [],
                picker: (_) async =>
                    XFile.fromData(utf8.encode('png'), name: 'r.png'),
              ),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pumpAndSettle();
      expect(speaker.said.where((s) => s.contains('8,000')), isEmpty);
    });
  });
}
