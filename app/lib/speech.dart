import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'diagnostics.dart';
import 'platform.dart';

/// How one utterance ended.
enum Spoken {
  finished,

  /// Magana stopped it (a new utterance, or the person pressed something).
  stoppedByMagana,

  /// Something else cut it off: TalkBack announcing a screen, or the browser
  /// reporting "interrupted" or "canceled" when Magana didn't stop it.
  cutOff,

  /// The browser refused to speak before the first press (Chrome's autoplay
  /// rule, "not-allowed"); it is said after "Start Magana".
  blocked,

  /// Any other engine error ("synthesis-failed", "audio-busy", ...).
  failed,
}

/// Text-to-speech wrapper. [say] completes when the utterance finishes or is
/// interrupted, so callers can read items one after another. It returns false
/// when it was cut off, so reading loops pause there instead of skipping ahead.
/// Something other than Magana cutting it off gets one more try (see [say]).
class Speaker {
  Speaker({FlutterTts? tts}) : _ttsInstance = tts {
    if (tts != null) _listen(tts);
  }

  FlutterTts? _ttsInstance;
  FlutterTts get _tts => _ttsInstance ??= _listen(FlutterTts());
  Completer<Spoken>? _pending;
  String _text = '';
  bool _started = false;
  bool _active =
      false; // the engine is speaking (or has not yet reported a stop)
  int _turn = 0; // goes up with every say() and stop()
  double _rate = 1.0;
  String _languageCode = 'en';

  /// Web only: true until the first press, while the browser won't speak. The
  /// app then covers the screen with "Start Magana" (see [start]).
  final needsStart = ValueNotifier<bool>(false);
  String? _waiting; // the latest text that couldn't be spoken yet

  double get rate => _rate;

  /// VoiceOver or TalkBack is on: when it cuts Magana off, the person is moving around the
  /// screen, so the words are not said again.
  bool screenReaderOn = false;

  /// True while an utterance is playing or about to.
  bool get speaking => _pending != null;

  FlutterTts _listen(FlutterTts tts) {
    tts.setStartHandler(() {
      _started = _active = true;
      diagnostics.spoke(started: true);
    });
    // A stop() can deliver the old utterance's cancel event late; only finish
    // the current utterance once it has actually started.
    tts.setCompletionHandler(() {
      _active = false;
      _finish(Spoken.finished, onlyIfStarted: true);
    });
    tts.setCancelHandler(() {
      _active = false;
      _finish(Spoken.cutOff, onlyIfStarted: true);
    });
    // On the web the plugin passes SpeechSynthesisErrorEvent.error.
    tts.setErrorHandler((error) {
      _active = false;
      _onError('$error');
    });
    unawaited(_pickVoice(tts));
    return tts;
  }

  void _onError(String error) {
    // Magana's own stop finished the utterance already: the engine's report is normal.
    final ours =
        _pending == null && (error == 'interrupted' || error == 'canceled');
    devLog(
      ours
          ? 'speech "$error" after Magana stopped "$_text" (normal)'
          : 'speech error "$error" while saying "$_text"',
    );
    switch (error) {
      case 'not-allowed' when runningOnWeb:
        _waiting = _text;
        needsStart.value = true;
        _finish(Spoken.blocked);
      // Magana's own stops finish the utterance before the engine reports them,
      // so an interruption that reaches a started utterance came from elsewhere.
      case 'interrupted' || 'canceled':
        _finish(Spoken.cutOff, onlyIfStarted: true);
      default:
        _finish(Spoken.failed);
    }
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

  /// Says [text]. If something other than Magana cuts it off (TalkBack
  /// announcing a new screen, say), waits [retryDelay] and says it once more,
  /// unless Magana has moved on or [wanted] turned false. True if it was heard
  /// to the end.
  Future<bool> say(String text, {bool Function()? wanted}) async {
    final turn = ++_turn;
    if (needsStart.value) {
      _waiting = text; // said after "Start Magana"
      devLog('speech waits for Start Magana: "$text"');
      return false;
    }
    final first = await utter(text);
    if (first != Spoken.cutOff || screenReaderOn) {
      return first == Spoken.finished;
    }
    devLog('speech cut off by something else; saying it once more: "$text"');
    await Future<void>.delayed(retryDelay);
    if (turn != _turn || !(wanted?.call() ?? true)) return false;
    return await utter(text) == Spoken.finished;
  }

  /// For reading loops: [say], stopping if [wanted] turns false (the learner
  /// pressed something) before the second try.
  Future<bool> sayThrough(String text, {required bool Function() wanted}) =>
      say(text, wanted: wanted);

  static const retryDelay = Duration(milliseconds: 1500);

  /// iPhone: speech plays with the silent switch on, and next to VoiceOver. The playback
  /// category ignores the switch; spokenAudio mode, ducking other sound, pauses other spoken
  /// audio (podcasts). Set before every utterance: recording a voice note or an answer
  /// switches the session to record mode, which would send speech to the quiet earpiece.
  static Future<void> iosAudio(FlutterTts tts) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions
            .interruptSpokenAudioAndMixWithOthers,
      ], IosTextToSpeechAudioMode.spokenAudio);
    } catch (e) {
      devLog('speech: iOS audio session not set ($e)');
    }
  }

  /// One utterance, no retry. Replaceable in tests.
  @protected
  Future<Spoken> utter(String text) async {
    await _halt();
    await iosAudio(_tts);
    diagnostics.asked(
      text,
    ); // the exact text sent to the voice (diagnostics screen)
    _text = text;
    final done = _pending = Completer<Spoken>();
    _started = false;
    await _tts.speak(text);
    // Never hang a reading loop on an utterance the engine silently dropped.
    Timer(const Duration(seconds: 3), () {
      if (identical(_pending, done) && !_started) _finish(Spoken.finished);
    });
    return done.future;
  }

  /// The first press on the web: speech is allowed from now on, and the text
  /// that was waiting is said.
  Future<void> start() async {
    needsStart.value = false;
    final text = _waiting;
    _waiting = null;
    if (text != null) await say(text);
  }

  Future<void> stop() async {
    _turn++;
    await _halt();
  }

  Future<void> _halt() async {
    _finish(Spoken.stoppedByMagana);
    await _tts.stop();
    // The web engine ignores speak() until the cancelled utterance reports
    // back, so wait briefly for that before the next say().
    for (var i = 0; i < 20 && _active; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    _active = false;
  }

  void _finish(Spoken how, {bool onlyIfStarted = false}) {
    if (onlyIfStarted && !_started) return;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) {
      diagnostics.spoke(started: false, outcome: how.name);
      c.complete(how);
    }
  }
}
