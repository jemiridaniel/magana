// Hausa pages read on the phone: ƙ and ɗ put back where it is safe, as the server does
// (page_letters.restoreHausa, backend letters.restore_hausa). The cases are shared with
// backend/tests/test_hausa_restore.py, so both readers agree (Brydl's review, 13 Nov 2026).
@Tags(['safety'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:app/offline/page_letters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_letter_marks_test.dart' show readLines;

final cases =
    ((jsonDecode(
                  File(
                    '../backend/tests/fixtures/letters/hausa_restore_cases.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['cases']
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  for (final c in cases) {
    test('shared case: ${c['why']}', () {
      final tokens = (c['line'] as String).split(' ');
      final r = restoreHausa(tokens);
      expect(r.words.join(' '), c['restored']);
      // Marked as the server marks: every changed word, and every word that may have lost a
      // special letter (letters.marks).
      final marked = [
        for (final (j, t) in tokens.indexed)
          if (r.changed.contains(j) || mayMissLetter(t, 'ha')) j,
      ];
      expect(marked, (c['marked'] as List).cast<int>());
    });
  }

  test('the offline reader shows the restored words, marked', () async {
    final r = await readLines([
      'Ita ce Kungiyar mafi girma a kasar.',
      'Yana da đalibai da yawa a makaranta.',
      '== Kuruciya ==',
    ], 'school');
    expect(r.language, 'ha');
    expect(r.texts, [
      'Ita ce ƙungiyar mafi girma a kasar.',
      'Yana da ɗalibai da yawa a makaranta.',
      '== Kuruciya ==',
    ]);
    final marked = {for (final m in r.marked) (m.$1, m.$2)};
    expect(marked, containsAll([(0, 2), (1, 2), (2, 1)]));
  });
}
