// A digit inside a word on a Hausa, Yorùbá or Igbo page is an unclear letter, never a number
// (backend letters.digit_in_word; offline: lib/offline/page_letters.dart). The cases are the
// backend's: where Tesseract `eng` read Igbo ọ as "9" (backend/tests/fixtures/letters).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/l10n/app_localizations.dart';
import 'package:app/offline/offline_reader.dart';
import 'package:app/offline/page_letters.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, captureToReader, pumpApp;
import 'white_paper_test.dart' show FakePhoto, FakeRecognizer, cropReads, seen;

final cases = (jsonDecode(
  File('../backend/tests/fixtures/letters/ig_digit_cases.json')
      .readAsStringSync(),
) as List).cast<Map<String, dynamic>>();

bool isNumber(String w) =>
    RegExp(r'^\d+$').hasMatch(w.replaceAll(RegExp(r'[,.;:]'), ''));

/// An Igbo page as the backend returns it: "uz9" (ụzọ) is an unclear letter; "9" (ọ)
/// stands alone, so it is a number and keeps the number checks.
const igboJson = {
  'tips': ['letters_ig'],
  'page_language': 'ig',
  'lines': [
    {
      'text': '9 buruhaala na uz9 osuso',
      'confidence': 0.95,
      'top': 10,
      'words': [
        {'text': '9'},
        {'text': 'buruhaala'},
        {'text': 'na'},
        {'text': 'uz9'},
        {'text': 'osuso'},
      ],
    },
  ],
  'warnings': <Object>[],
  'letter_marks': [
    {'block_index': 0, 'word_index': 3, 'kind': 'unclear_letter'},
  ],
};

void main() {
  tearDown(() => pageRecognizer = MlKitRecognizer());

  test('the 37 phone-like Igbo cases, as the server decides them', () {
    expect(cases.where((c) => c['kind'] == 'photo'), hasLength(37));
    for (final c in cases) {
      final read = c['read'] as String;
      expect(digitInWord(read), !isNumber(read), reason: read);
    }
    for (final w in ['n9', 'ak9', "n'9", '9kwa', 'Uz9', 'ndi-9z9']) {
      expect(digitInWord(w), isTrue, reason: w);
    }
    for (final w in [
      '9',
      '929.',
      '₦500',
      'N500',
      '500mg',
      '5ml',
      '2nd',
      '10am',
      'SS2',
      'JSS3',
      'B12',
      'COVID-19',
      '12/10/2026',
      '(9)',
      '38.5',
    ]) {
      expect(digitInWord(w), isFalse, reason: w);
    }
  });

  test('the phone finds the page language as the server does', () {
    for (final lang in ['ha', 'yo', 'ig']) {
      final pages = (jsonDecode(
        File('../benchmark/letters/$lang.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>();
      for (final p in pages) {
        // As `eng` reads it: no special letters (the first reading decides).
        expect(pageLanguageOf(plainWord(p['text'] as String)), lang);
      }
    }
    expect(
      pageLanguageOf(
        'Plants make food in their leaves. They need sunlight and water.',
      ),
      isNull,
    );
    expect(plainWord('Ọ̀ZỌ́'), 'ozo');
    expect(plainWord('ƙasar ɗalibai'), 'kasar dalibai');
  });

  test(
    'offline: an Igbo page warns once; a digit in a word is never a number',
    () async {
      for (final conf in [0.97, 0.5]) {
        final line = seen('9 buruhaala na uz9 osuso', conf);
        final more = seen('ihe ndi ozo nke anyi nwere maka ha', 0.97, top: 200);
        pageRecognizer = FakeRecognizer(
          FakePhoto(
            [line, more],
            crop: (l, t, w, h) => cropReads(t > 150 ? more : line)(l, t, w, h),
          ),
        );
        final r = (await readOnPhone(Uint8List(1), mode: 'school'))!;
        expect(r.pageLanguage, 'ig');
        expect(r.tips, contains('letters_ig'));
        final item = r.items.first;
        expect(item.unclearLetters, {3});
        expect(item.letterMarks, {3});
        // The lone "9" keeps the number rule: unclear when unsure, read as printed when sure.
        expect(item.unclearWords, conf < 0.9 ? {0} : <int>{});
        expect(item.unclearWords.contains(3), isFalse);
      }
    },
  );

  test('offline: an English page is never touched', () async {
    final line = seen('Vitamin B12 and D3 take x3 daily', 0.97);
    pageRecognizer = FakeRecognizer(FakePhoto([line], crop: cropReads(line)));
    final r = (await readOnPhone(Uint8List(1), mode: 'school'))!;
    expect(r.pageLanguage, isNull);
    expect(r.items.first.unclearLetters, isEmpty);
  });

  testWidgets(
    'Reader: says "unclear letter", never the digit; Spell word spells it',
    (tester) async {
      final handle = tester.ensureSemantics();
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker, body: igboJson);
      await captureToReader(tester);
      // Magana's word inside an Igbo line is in Igbo, read by the same voice as the line.
      final ig = lookupAppLocalizations(const Locale('ig'));
      expect(
        speaker.said,
        contains('9 buruhaala na ${ig.unclearLetter} osuso'),
      );
      expect(speaker.said.join(' '), isNot(contains('uz9')));
      expect(
        find.textContaining('uz9'),
        findsWidgets,
      ); // shown as read, never changed
      expectAccessible(tester, 'Reader (unclear letter)');
      await tester.ensureVisible(find.bySemanticsLabel('Spell word'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Spell word'));
      await tester.pumpAndSettle();
      expect(speaker.said.last, 'unclear letter: u, z, unclear letter');
      handle.dispose();
    },
  );
}
