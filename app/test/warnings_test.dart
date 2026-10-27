// Warning fatigue (docs/FINDINGS.md, 27 Oct 2026): one page summary, "unclear" at each spot, the
// full list on request. Number safety unchanged: an unclear number is never spoken as digits.
import 'dart:convert';
import 'dart:io';

import 'package:app/api.dart';
import 'package:app/commands.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/messages.dart';
import 'package:app/warnings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final en = lookupAppLocalizations(const Locale('en'));

Map<String, dynamic> line(String text) => {
  'text': text,
  'confidence': 0.9,
  'top': 0,
  'words': [
    for (final w in text.split(' ')) {'text': w},
  ],
};

final page = ReadResult.fromJson({
  'tips': ['edge_cut_left'],
  'lines': [
    line('BOARDING PASS'),
    line('FLIGHT P4 7123'),
    line('SEAT 14C GATE B2'),
    line('DEPARTS 06:45'),
  ],
  'warnings': [
    {'block_index': 0, 'code': 'low_confidence'},
    {'block_index': 1, 'code': 'number_mismatch', 'word_index': 2},
    {'block_index': 2, 'code': 'low_confidence'},
    {'block_index': 2, 'code': 'low_confidence_number', 'word_index': 1},
    {'block_index': 3, 'code': 'number_mismatch'}, // no word to mark
  ],
});

/// How many warning sentences a full read-through spoke before the grouping: every tip, the
/// "I'm not sure about N" summary, and one sentence for every unsure line or row.
int spokenBefore(ReadResult r) =>
    r.tips.length +
    (r.json?['script'] == 'mixed'
        ? 1
        : 0) + // the old "Some of this page looks handwritten"
    (r.unsureCount > 0 ? 1 : 0) +
    r.items.where((i) => i.unsure).length;

/// After: the tips, the summary (at most 3 sentences), and faint bands (their own items).
int spokenAfter(ReadResult r) =>
    r.tips.length +
    PageWarnings(r.items).summary(en).length +
    r.items.where((i) => i.isFaint).length;

/// The short "unclear" words said inline (not sentences).
int inlineMarks(ReadResult r) =>
    [for (final i in r.items) ...PageWarnings.marks(en, i)].length;

void main() {
  test(
    'the page summary counts numbers and lines, and says how to hear where',
    () {
      final w = PageWarnings(page.items);
      expect((w.unclearNumbers, w.unclearLines), (3, 2));
      expect(w.summary(en), [
        '3 numbers are unclear.',
        '2 lines are hard to read.',
        "Say “what's unclear” to hear where.",
      ]);
    },
  );

  test('at each spot: "unclear number" in place of digits, "Unclear." at a line end', () {
    final [_, flight, seat, departs] = page.items;
    expect(flight.unclearWords, {
      2,
    }); // "7123" is replaced by the Reader, never spoken
    expect(PageWarnings.marks(en, flight), isEmpty);
    expect(PageWarnings.marks(en, seat), ['Unclear.']);
    // A number warning with no word to mark: still said, at the end of the line.
    expect(PageWarnings.marks(en, departs), ['unclear number']);
  });

  test('"what\'s unclear?" lists every spot with its full warning', () {
    final details = PageWarnings(page.items)
        .details(en, (i) => en.whereLine(i.number));
    expect(details, hasLength(4));
    expect(details[1], en.msg_number_mismatch(en.whereLine(2)));
    expect(details[2], contains(en.msg_low_confidence(en.whereLine(3))));
    expect(details[2], contains(en.msg_low_confidence_number(en.whereLine(3))));
    expect(matchReaderCommand("what's unclear"), ReaderCommand.unclear);
    expect(
      matchReaderCommand('what is unclear on this page'),
      ReaderCommand.unclear,
    );
  });

  test('fewer spoken warnings on this page: 6 sentences before, 4 after', () {
    expect(spokenBefore(page), 1 + 1 + 4);
    expect(spokenAfter(page), 1 + 3);
    expect(inlineMarks(page), 3); // "Unclear." twice, "unclear number" once
  });

  test('measured on saved server readings (set MAGANA_WARNINGS_JSON to a folder)', () {
    final dir = Platform.environment['MAGANA_WARNINGS_JSON'];
    // Counts only; the readings stay outside the repository.
    if (dir == null) return;
    for (final f
        in Directory(dir).listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path))) {
      if (!f.path.endsWith('.json')) {
        continue;
      }
      final r = ReadResult.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
      // ignore: avoid_print
      print(
        'WARNINGS ${f.uri.pathSegments.last}: lines ${r.items.length}, '
        'sentences ${spokenBefore(r)} -> ${spokenAfter(r)}, inline marks ${inlineMarks(r)}, '
        'tips ${r.tips.map((t) => messageFor(en, t).isEmpty ? t : t).join(",")}',
      );
    }
  });

  test('a line the server may have missed: said at its place, counted in the summary', () {
    final r = ReadResult.fromJson({
      'tips': <String>[],
      'lines': [
        {...line('Give God'), 'top': 440},
        {...line('Psalm 34:4'), 'top': 866},
      ],
      'warnings': <Map<String, dynamic>>[],
      'faint_regions': [
        {'code': 'missed_line', 'top': 722, 'bottom': 799, 'where': 'middle'},
      ],
    });
    final w = PageWarnings(r.items);
    expect(r.items.map((i) => i.isFaint), [
      false,
      true,
      false,
    ]); // between the two lines
    expect(w.missedLines, 1);
    expect(w.summary(en), [en.summaryMissed(1), en.summaryAsk]);
    expect(
      messageFor(en, 'missed_line', where: en.whereMiddle),
      'I may have missed a line here, in the middle of the page. '
      'Please check it or retake the photo.',
    );
  });
}
