import 'api.dart';
import 'capture/frame_analysis.dart';

/// The last reading attempt, as numbers and words, for the hidden diagnostics screen
/// (Settings → tap the version 7 times). Kept in memory only, never saved or sent, and never
/// an image: how the photo was taken, what the framing saw, which way it was read, what the
/// server answered, the words and their confidence, and whether speech started and finished.
class Attempt {
  Attempt(this.capture, this.frame) : at = DateTime.now();

  final DateTime at;

  /// How the photo was taken: auto (page ready), steady_text (6 s of steady text),
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

  void read(ReadResult r) {
    tips = r.tips;
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

class Diagnostics {
  Attempt? last;
  DateTime? speechStarted;
  DateTime? speechFinished;
  String? speechOutcome;

  Attempt begin(String capture, FrameReport? frame) =>
      last = Attempt(capture, frame);

  void spoke({required bool started, String? outcome}) {
    if (started) {
      speechStarted = DateTime.now();
      speechFinished = null;
      speechOutcome = null;
    } else {
      speechFinished = DateTime.now();
      speechOutcome = outcome;
    }
  }
}

final diagnostics = Diagnostics();
