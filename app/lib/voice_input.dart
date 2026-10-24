import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:flutter/widgets.dart' show BuildContext;

import 'api.dart';
import 'app_scope.dart';
import 'platform/speech_support.dart';
import 'policy.dart';

/// Short spoken answers and commands (docs/PRIVACY.md, "Spoken answers"). Tried in order:
/// 1. the phone's **on-device** recogniser, where Android has one: audio stays on the phone;
/// 2. Magana's own server ASR (NCAIR1's Hausa, Yorùbá, Igbo and Nigerian-English models);
/// 3. for adults (18+) only, the phone's usual recogniser, which may send audio to Google
///    or the phone maker. Guided and Classroom (under-18) accounts never use it;
/// then nothing: the screen offers tapping the answer instead.
abstract class VoiceInput {
  /// False when no recogniser can be used or the microphone was refused.
  Future<bool> init();

  /// Listens until the person pauses. Returns what was heard, best guess
  /// first, or nothing. [language] is the speech to expect (en, ha, yo, ig).
  /// Audio is never saved by Magana. Throws [VoiceStepFailed] if this
  /// recogniser failed (not merely heard nothing).
  Future<List<String>> listen({String language = 'en'});

  Future<void> stop();
}

class VoiceStepFailed implements Exception {
  VoiceStepFailed(this.reason);
  final String reason;
  @override
  String toString() => 'VoiceStepFailed($reason)';
}

/// The recognisers a tier may use, in order (see [VoiceInput]).
List<VoiceInput> voiceSteps(Tier tier) => [
  SpeechVoiceInput(onDevice: true),
  ServerVoiceInput(), // phones and the web
  if (tier == Tier.standard) SpeechVoiceInput(onDevice: false),
];

/// Replaceable in tests.
VoiceInput Function(Tier tier) voiceInput = (tier) =>
    ChainVoiceInput(voiceSteps(tier));

/// The voice input for whoever is using the app now (most restrictive until a
/// tier is chosen).
VoiceInput voiceInputFor(BuildContext context) =>
    voiceInput(AppScope.of(context).profile.tier ?? Tier.classroom);

class ChainVoiceInput implements VoiceInput {
  ChainVoiceInput(this.steps);
  final List<VoiceInput> steps;
  final _usable = <VoiceInput, bool>{};
  VoiceInput? _current;

  Future<bool> _ready(VoiceInput step) async =>
      _usable[step] ??= await step.init().catchError((_) => false);

  @override
  Future<bool> init() async {
    for (final step in steps) {
      if (await _ready(step)) return true;
    }
    return false;
  }

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    for (final step in steps) {
      if (!await _ready(step)) continue;
      try {
        _current = step;
        return await step.listen(language: language);
      } catch (e) {
        debugPrint('voice: ${step.runtimeType} failed ($e), trying the next');
        _usable[step] = false; // not again this session
      } finally {
        _current = null;
      }
    }
    throw VoiceStepFailed('no recogniser');
  }

  @override
  Future<void> stop() async => _current?.stop();
}

class SpeechVoiceInput implements VoiceInput {
  SpeechVoiceInput({required this.onDevice});

  /// Only the phone's on-device recogniser, checked first: speech_to_text quietly
  /// uses the network recogniser when the phone has no on-device one.
  final bool onDevice;
  final _stt = SpeechToText();
  Completer<List<String>>? _pending;
  List<LocaleName> _locales = const [];

  @override
  Future<bool> init() async {
    try {
      if (onDevice && !await onDeviceSpeechAvailable()) return false;
      final ok = await _stt.initialize(
        onStatus: (status) {
          if (status != SpeechToText.doneStatus) return;
          // "done" can arrive just before the final result; give it a moment.
          final waiting = _pending;
          Timer(const Duration(milliseconds: 500), () {
            if (identical(_pending, waiting)) _finish(const []);
          });
        },
        onError: (e) =>
            e.errorMsg == 'error_no_match' ||
                e.errorMsg == 'error_speech_timeout'
            ? _finish(const []) // heard nothing: not a failure
            : _fail(e.errorMsg),
      );
      if (!ok) return false;
      _locales = await _stt.locales();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Nigerian variant first, then any of the language; null means the default
  /// (English only: another language without a model is a failure).
  String? _localeFor(String language) {
    String norm(LocaleName l) => l.localeId.replaceAll('-', '_');
    final ng = _locales.where((l) => norm(l) == '${language}_NG').firstOrNull;
    final any = _locales
        .where((l) => norm(l).startsWith('${language}_'))
        .firstOrNull;
    final found = (ng ?? any)?.localeId;
    if (found == null && language != 'en') {
      throw VoiceStepFailed('no $language recogniser');
    }
    return found;
  }

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    _finish(const []);
    final locale = _localeFor(language);
    final done = _pending = Completer<List<String>>();
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: locale,
        onDevice: onDevice,
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

  void _fail(String reason) {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.completeError(VoiceStepFailed(reason));
  }

  @override
  Future<void> stop() => _stt.stop();
}

/// Records a short answer (16 kHz mono WAV, until about 1.5 s of silence after
/// speech, at most 8 s), sends it to the server's /asr and deletes it at once.
class ServerVoiceInput implements VoiceInput {
  ServerVoiceInput({AudioRecorder? recorder, http.Client? client})
    : _given = recorder,
      _client = client ?? http.Client();

  final AudioRecorder? _given;
  AudioRecorder? _made;
  // Created on first use: the recorder starts the native plugin.
  AudioRecorder get _recorder => _given ?? (_made ??= AudioRecorder());
  final http.Client _client;
  Completer<void>? _stopped;

  @override
  Future<bool> init() => _recorder.hasPermission();

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    // Phones record to a temporary file; browsers to an in-memory blob.
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}/answer-${DateTime.now().microsecondsSinceEpoch}.wav';
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
    final recorded = await _recorder.stop();
    try {
      if (!heardSpeech || recorded == null) return const [];
      final bytes = kIsWeb
          ? await _client.readBytes(Uri.parse(recorded))
          : await File(recorded).readAsBytes();
      final req = http.MultipartRequest('POST', Uri.parse('$apiBase/asr'))
        ..fields['lang'] = language
        ..headers.addAll(serverHeaders)
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: 'answer.wav'),
        );
      final res = await http.Response.fromStream(await _client.send(req))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw VoiceStepFailed('server ASR ${res.statusCode}');
      }
      final text =
          (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['text'] as String? ??
          '';
      return text.trim().isEmpty ? const [] : [text.trim()];
    } finally {
      // The audio is never kept.
      if (!kIsWeb && recorded != null && await File(recorded).exists()) {
        await File(recorded).delete();
      }
    }
  }

  @override
  Future<void> stop() async {
    final s = _stopped;
    if (s != null && !s.isCompleted) s.complete();
  }
}
