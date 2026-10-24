import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Short spoken answers through the phone's own speech recogniser.
abstract class VoiceInput {
  /// False when the phone has no recogniser or the microphone was refused.
  Future<bool> init();

  /// Listens until the person pauses. Returns what was heard, best guess
  /// first, or nothing. Audio is never saved by Magana.
  Future<List<String>> listen();

  Future<void> stop();
}

/// Replaceable in tests.
VoiceInput Function() voiceInput = SpeechVoiceInput.new;

class SpeechVoiceInput implements VoiceInput {
  final _stt = SpeechToText();
  Completer<List<String>>? _pending;
  String? _locale;

  @override
  Future<bool> init() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (status) {
          if (status != SpeechToText.doneStatus) return;
          // "done" can arrive just before the final result; give it a moment.
          final waiting = _pending;
          Timer(const Duration(milliseconds: 500), () {
            if (identical(_pending, waiting)) _finish(const []);
          });
        },
        onError: (_) => _finish(const []),
      );
      if (!ok) return false;
      // Nigerian English when the phone has it; the quiz is in English.
      final locales = await _stt.locales();
      _locale = [
        for (final l in locales)
          if (l.localeId.replaceAll('-', '_') == 'en_NG') l.localeId,
      ].firstOrNull;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> listen() async {
    _finish(const []);
    final done = _pending = Completer<List<String>>();
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: _locale,
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    return done.future;
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!r.finalResult) return;
    _finish([
      for (final a in r.alternates)
        if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords,
    ]);
  }

  void _finish(List<String> heard) {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(heard);
  }

  @override
  Future<void> stop() => _stt.stop();
}
