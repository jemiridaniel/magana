// Offline reading marks the same Hausa words the server marks (Brydl's review of the Hausa
// pack, 13 Nov 2026: on the 2 Nov build the phone marked almost nothing, and none of it a word
// that had lost a hook). The phone now uses the server's word lists (page_letters.mayMissLetter,
// lib/offline/word_lists.dart, made by scripts/gen_offline_language.py).
@Tags(['safety'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/offline/offline_reader.dart';
import 'package:app/offline/page_letters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'white_paper_test.dart' show FakePhoto, FakeRecognizer, seen;

final fixture =
    jsonDecode(
          File('test/fixtures/hausa_label_pages.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _list(String key) =>
    (fixture[key] as List).cast<Map<String, dynamic>>();

String _bare(String w) =>
    w.toLowerCase().replaceAll(RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true), '');

/// Reads [lines] with the offline reader, as the phone would, and returns the result.
Future<OfflineResultForTest> readLines(List<String> lines, String mode) async {
  final seenLines = [
    for (final (i, l) in lines.indexed) seen(l, 0.97, top: 100 + 60 * i),
  ];
  pageRecognizer = FakeRecognizer(
    FakePhoto(
      seenLines,
      // A crop read again: the words inside it, from every line.
      crop: (l, t, w, h) => [
        for (final line in seenLines)
          if (line.words.first.top >= t && line.words.first.top < t + h) line,
      ],
    ),
  );
  final r = (await readOnPhone(Uint8List(1), mode: mode))!;
  return OfflineResultForTest(
    r.pageLanguage,
    r.tips,
    [
      for (final (i, item) in r.items.indexed)
        for (final j in item.letterMarks) (i, j, item.text.split(' ')[j]),
    ],
    [
      for (final (i, item) in r.items.indexed)
        for (final j in item.unclearLetters) (i, j),
    ],
  );
}

class OfflineResultForTest {
  OfflineResultForTest(this.language, this.tips, this.marked, this.unclear);
  final String? language;
  final List<String> tips;
  final List<(int, int, String)> marked;
  final List<(int, int)> unclear;
}

void main() {
  test('the phone marks the words the server marks (word level)', () {
    expect(mayMissLetter('kwaya', 'ha'), isTrue); // ƙwaya
    expect(mayMissLetter('hadiye', 'ha'), isTrue); // haɗiye
    expect(mayMissLetter('nika', 'ha'), isTrue); // niƙa
    expect(mayMissLetter('Kungiyar,', 'ha'), isTrue); // ƙungiyar, punctuation ignored
    expect(mayMissLetter('ƙwaya', 'ha'), isFalse); // read with its letter
    expect(mayMissLetter('da', 'ha'), isFalse);
    expect(mayMissLetter('makaranta', 'ha'), isFalse);
    expect(mayMissLetter('2026', 'ha'), isFalse);
    expect(mayMissLetter('omo', 'yo'), isTrue);
    expect(mayMissLetter('umu', 'ig'), isTrue);
  });

  for (final page in _list('pages')) {
    test('review ${page['id']} (medicine label): offline marks what the server marks', () async {
      final r = await readLines(
        (page['offline_lines'] as List).cast<String>(),
        'health',
      );
      expect(r.language, 'ha');
      final offline = [for (final m in r.marked) _bare(m.$3)]..sort();
      final server = [
        for (final w in (page['server_marked'] as List).cast<String>()) _bare(w),
      ]..sort();
      expect(offline, server);
      // So the page note "Marked words may have one of these" is true.
      expect(r.tips, contains('letters_ha'));
    });
  }

  for (final page in _list('parity')) {
    test('review ${page['id']}: the same marks as the server on the same lines', () async {
      final r = await readLines(
        (page['offline_lines'] as List).cast<String>(),
        'school',
      );
      final server = [
        for (final m in (page['server_marks'] as List).cast<List>())
          if (m[2] == 'special_letter') (m[0] as int, m[1] as int),
      ];
      final unclear = [
        for (final m in (page['server_marks'] as List).cast<List>())
          if (m[2] == 'unclear_letter') (m[0] as int, m[1] as int),
      ];
      expect([for (final m in r.marked) (m.$1, m.$2)]..removeWhere(r.unclear.contains), unorderedEquals(server));
      expect(r.unclear, unorderedEquals(unclear));
    });
  }

  test('an English page gets no marks and no Hausa page note', () async {
    final r = await readLines([
      'Take two tablets after meals.',
      'Keep out of the reach of children.',
    ], 'health');
    expect(r.language, isNull);
    expect(r.marked, isEmpty);
    expect(r.tips.where((t) => t.startsWith('letters_')), isEmpty);
  });
}
