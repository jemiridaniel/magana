import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'platform.dart';

/// Text-to-speech wrapper. [say] completes when the utterance finishes or is
/// interrupted, so callers can read items one after another.
class Speaker {
  FlutterTts? _ttsInstance;
  FlutterTts get _tts => _ttsInstance ??= _create();
  Completer<void>? _pending;
  bool _started = false;
  bool _active =
      false; // the engine is speaking (or has not yet reported a stop)
  double _rate = 1.0;
  String _languageCode = 'en';

  double get rate => _rate;

  /// True while an utterance is playing or about to.
  bool get speaking => _pending != null;

  FlutterTts _create() {
    final tts = FlutterTts();
    tts.setStartHandler(() => _started = _active = true);
    // A stop() can deliver the old utterance's cancel event late; only finish
    // the current utterance once it has actually started.
    tts.setCompletionHandler(() {
      _active = false;
      _finish(onlyIfStarted: true);
    });
    tts.setCancelHandler(() {
      _active = false;
      _finish(onlyIfStarted: true);
    });
    // On the web a cancelled utterance reports an "interrupted" error.
    tts.setErrorHandler((_) {
      _active = false;
      _finish();
    });
    unawaited(_pickVoice(tts));
    return tts;
  }

  /// Use a voice for the app language when the device has one (Nigerian
  /// variant first), otherwise English. Most phones have no Hausa, Yorùbá or
  /// Igbo voice yet; MMS-TTS on the backend will cover those.
  Future<void> setLanguage(String code) async {
    _languageCode = code;
    if (_ttsInstance != null) await _pickVoice(_tts);
  }

  Future<void> _pickVoice(FlutterTts tts) async {
    final candidates = [
      '$_languageCode-NG',
      _languageCode,
      'en-NG',
      'en-GB',
      'en-US',
    ];
    for (final lang in candidates) {
      try {
        if (await tts.isLanguageAvailable(lang) == true) {
          await tts.setLanguage(lang);
          break;
        }
      } catch (_) {}
    }
    await _applyRate(tts);
  }

  Future<void> _applyRate(FlutterTts tts) =>
      tts.setSpeechRate(normalSpeechRate * _rate);

  Future<void> setRate(double rate) async {
    _rate = rate;
    await _applyRate(_tts);
  }

  Future<void> say(String text) async {
    await stop();
    final done = _pending = Completer<void>();
    _started = false;
    await _tts.speak(text);
    // Never hang a reading loop on an utterance the engine silently dropped.
    Timer(const Duration(seconds: 3), () {
      if (identical(_pending, done) && !_started) _finish();
    });
    return done.future;
  }

  Future<void> stop() async {
    _finish();
    await _tts.stop();
    // The web engine ignores speak() until the cancelled utterance reports
    // back, so wait briefly for that before the next say().
    for (var i = 0; i < 20 && _active; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    _active = false;
  }

  void _finish({bool onlyIfStarted = false}) {
    if (onlyIfStarted && !_started) return;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}
