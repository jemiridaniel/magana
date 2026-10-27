// Hidden diagnostics (iPhone retest, 27 Oct 2026): why each line was marked unclear, and the
// exact text sent to the voice with how long it played.
import 'package:app/api.dart';
import 'package:app/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each unclear line says why, with the word and its confidence', () {
    final a = Attempt('auto', null)
      ..read(
        ReadResult(
          tips: const [],
          items: const [],
          json: {
            'lines': [
              {
                'text': 'Give God',
                'words': [
                  {'text': 'Give', 'confidence': 0.96},
                  {'text': 'God', 'confidence': 0.95},
                ],
              },
              {
                'text': 'Psalm 37:4',
                'words': [
                  {'text': 'Psalm', 'confidence': 0.96},
                  {'text': '37:4', 'confidence': 0.83},
                ],
              },
            ],
            'warnings': [
              {'block_index': 1, 'word_index': 1, 'code': 'number_low_confidence'},
              {'block_index': 0, 'code': 'unclear_line_end'},
            ],
          },
        ),
      );
    expect(a.reasons, [
      'Line 1: unclear_line_end',
      'Line 2: number_low_confidence on "37:4" (83)',
    ]);
  });

  test('every utterance is kept with its text, timing and outcome', () {
    final d = Diagnostics()
      ..asked('Give God')
      ..spoke(started: true)
      ..spoke(started: false, outcome: 'finished')
      ..asked('the utmost delight');
    expect(d.utterances.map((u) => u.text), ['Give God', 'the utmost delight']);
    expect(d.utterances.first.outcome, 'finished');
    expect(d.utterances.first.finished, isNotNull);
    expect(d.utterances.last.started, isNull);
    for (var i = 0; i < 50; i++) {
      d.asked('$i');
    }
    expect(d.utterances.length, Diagnostics.keep);
  });
}
