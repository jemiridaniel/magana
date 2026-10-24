import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'api.dart';

/// Short spoken answers and commands. The phone's own recogniser by default; with
/// --dart-define=MAGANA_ASR=server, NCAIR1's Hausa, Yorùbá, Igbo and Nigerian-English
/// models on the Magana server first, falling back to the phone (docs/MODELS.md).
abstract class VoiceInput {
  /// False when the phone has no recogniser or the microphone was refused.
  Future<bool> init();

  /// Listens until the person pauses. Returns what was heard, best guess
  /// first, or nothing. [language] is the speech to expect (en, ha, yo, ig).
  /// Audio is never saved by Magana.
  Future<List<String>> listen({String language = 'en'});

  Future<void> stop();
}

const _asr = String.fromEnvironment('MAGANA_ASR', defaultValue: 'device');

/// Replaceable in tests.
VoiceInput Function() voiceInput = () => _asr == 'server' && !kIsWeb
    ? HybridVoiceInput(ServerVoiceInput(), SpeechVoiceInput())
    : SpeechVoiceInput();

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
  Future<List<String>> listen({String language = 'en'}) async {
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

/// Records a short answer (16 kHz mono WAV, until about 1.5 s of silence after
/// speech, at most 8 s), sends it to the server's /asr and deletes it at once.
class ServerVoiceInput implements VoiceInput {
  ServerVoiceInput({AudioRecorder? recorder, http.Client? client})
    : _recorder = recorder ?? AudioRecorder(),
      _client = client ?? http.Client();

  final AudioRecorder _recorder;
  final http.Client _client;
  Completer<void>? _stopped;

  @override
  Future<bool> init() => _recorder.hasPermission();

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/answer-${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    final stopped = _stopped = Completer<void>();
    var heardSpeech = false;
    var quietSince = DateTime.now();
    final started = DateTime.now();
    final levels = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((a) {
          final now = DateTime.now();
          if (a.current > -35) {
            heardSpeech = true;
            quietSince = now;
          }
          final silent = now.difference(quietSince).inMilliseconds > 1500;
          final tooLong = now.difference(started).inSeconds >= 8;
          if ((heardSpeech && silent) ||
              tooLong ||
              (!heardSpeech && now.difference(started).inSeconds >= 5)) {
            if (!stopped.isCompleted) stopped.complete();
          }
        });
    await stopped.future;
    await levels.cancel();
    await _recorder.stop();
    final file = File(path);
    try {
      if (!heardSpeech) return const [];
      final req = http.MultipartRequest('POST', Uri.parse('$apiBase/asr'))
        ..fields['lang'] = language
        ..files.add(await http.MultipartFile.fromPath('file', path));
      if (apiKey.isNotEmpty) req.headers['X-Magana-Key'] = apiKey;
      final res = await http.Response.fromStream(await _client.send(req))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw AsrUnavailable(res.statusCode.toString());
      }
      final text =
          (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['text'] as String? ??
          '';
      return text.trim().isEmpty ? const [] : [text.trim()];
    } finally {
      if (await file.exists()) await file.delete(); // the audio is never kept
    }
  }

  @override
  Future<void> stop() async {
    final s = _stopped;
    if (s != null && !s.isCompleted) s.complete();
  }
}

class AsrUnavailable implements Exception {
  AsrUnavailable(this.reason);
  final String reason;
}

/// Server ASR first; if the server has none, is unreachable or fails, the phone's
/// own recogniser answers instead (and is used from then on this session).
class HybridVoiceInput implements VoiceInput {
  HybridVoiceInput(this.server, this.device);
  final VoiceInput server;
  final VoiceInput device;
  bool _serverWorks = true;
  bool? _deviceReady;

  @override
  Future<bool> init() async => await server.init() || await _initDevice();

  Future<bool> _initDevice() async => _deviceReady ??= await device.init();

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    if (_serverWorks) {
      try {
        return await server.listen(language: language);
      } catch (e) {
        debugPrint('server ASR unavailable, using the phone: $e');
        _serverWorks = false;
      }
    }
    if (!await _initDevice()) return const [];
    return device.listen(language: language);
  }

  @override
  Future<void> stop() async {
    await server.stop();
    await device.stop();
  }
}
