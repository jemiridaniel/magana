import '../platform.dart';

/// Time from sending a photo to the Reader's first spoken word (board 5e: offline vs
/// online, docs/FINDINGS.md). Development builds log it; nothing is kept or sent.
class ReadTiming {
  static final _clock = Stopwatch();
  static String _how = '';

  static void start() => _clock
    ..reset()
    ..start();

  /// Called when the Reader starts speaking; logs once per page.
  static void firstWord({required bool offline}) {
    if (!_clock.isRunning) return;
    _clock.stop();
    _how = offline ? 'on the phone' : 'by the server';
    devLog(
      'time to first spoken word ($_how): ${_clock.elapsedMilliseconds} ms',
    );
  }
}
