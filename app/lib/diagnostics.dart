import 'api.dart';
import 'capture/frame_analysis.dart';

/// The last reading attempt, as numbers and words, for the hidden diagnostics screen
/// (Settings → tap the version 7 times). Kept in memory only, never saved or sent, and never
/// an image: how the photo was taken, what the framing saw, which way it was read, what the
/// server answered, the words and their confidence, and whether speech started and finished.
class Attempt {
  Attempt(this.capture, this.frame) : at = DateTime.now();

  final DateTime at;

  /// How the photo was taken: auto (page ready), steady_text (4 s of text in view),
  /// small_item, button, gallery.
  final String capture;
  final FrameReport? frame;
  int? photoBytes;

  /// server, or phone (no internet / server slow).
  String? path;
  int? status; // the server's HTTP status; null if it never answered
  String? code; // its message code, when it refused
  int? serverMs;
  List<String> tips = const [];
  List<({String text, double? confidence})> words = const [];

  /// For each line or row Magana is unsure of: why (the backend's codes, and the word each
  /// number warning sits on, with its confidence).
  List<String> reasons = const [];

  /// The phone showed its own reading, and the server answered later (kept for My library).
  bool serverLate = false;

  void read(ReadResult r) {
    tips = r.tips;
    final lines = (r.json?['lines'] as List?) ?? const [];
    final byLine = <int, List<String>>{};
    for (final w in (r.json?['warnings'] as List?) ?? const []) {
      final m = w as Map;
      final i = m['block_index'] as int? ?? -1;
      final j = m['word_index'] as int?;
      var why = m['code'] as String? ?? '?';
      if (j != null && i >= 0 && i < lines.length) {
        final ws = ((lines[i] as Map)['words'] as List?) ?? const [];
        if (j < ws.length) {
          final word = ws[j] as Map;
          final c = (word['confidence'] as num?)?.toDouble();
          why +=
              ' on "${word['text']}" (${c == null ? 'no confidence' : (c * 100).round()})';
        }
      }
      byLine.putIfAbsent(i, () => []).add(why);
    }
    for (final c in (r.json?['cell_warnings'] as List?) ?? const []) {
      final m = c as Map;
      byLine
          .putIfAbsent(-1, () => [])
          .add(
            'table ${m['table_index']} row ${m['row']} column ${m['col']}: ${m['code']}',
          );
    }
    reasons = [
      for (final MapEntry(key: i, value: why)
          in (byLine.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        '${i < 0 ? 'Table' : 'Line ${i + 1}'}: ${why.join('; ')}',
    ];
    words = [
      for (final line in (r.json?['lines'] as List?) ?? const [])
        if (((line as Map)['words'] as List?)?.isNotEmpty ?? false)
          for (final w in line['words'] as List)
            (
              text: (w as Map)['text'] as String? ?? '',
              confidence: (w['confidence'] as num?)?.toDouble(),
            )
        else
          // No word boxes for this line: its words, with the line's confidence.
          for (final t in (line['text'] as String? ?? '').split(' '))
            if (t.isNotEmpty)
              (text: t, confidence: (line['confidence'] as num?)?.toDouble()),
    ];
  }
}

/// One thing sent to the voice: the exact text, and when it started and ended, and how.
class Utterance {
  Utterance(this.text) : asked = DateTime.now();
  final String text;
  final DateTime asked;
  DateTime? started;
  DateTime? finished;
  String? outcome; // finished, cutOff, stoppedByMagana, failed, blocked
}

class Diagnostics {
  Attempt? last;
  DateTime? speechStarted;
  DateTime? speechFinished;
  String? speechOutcome;

  /// The last utterances, newest last (at most [keep]).
  final utterances = <Utterance>[];
  static const keep = 40;

  Attempt begin(String capture, FrameReport? frame) =>
      last = Attempt(capture, frame);

  void asked(String text) {
    utterances.add(Utterance(text));
    if (utterances.length > keep) utterances.removeAt(0);
  }

  void spoke({required bool started, String? outcome}) {
    final u = utterances.isEmpty ? null : utterances.last;
    if (started) {
      speechStarted = DateTime.now();
      speechFinished = null;
      speechOutcome = null;
      u?.started ??= speechStarted;
    } else {
      speechFinished = DateTime.now();
      speechOutcome = outcome;
      if (u != null && u.finished == null) {
        u
          ..finished = speechFinished
          ..outcome = outcome;
      }
    }
  }
}

final diagnostics = Diagnostics();
