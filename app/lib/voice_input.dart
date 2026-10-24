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
import 'platform.dart';
import 'platform/speech_support.dart';
import 'policy.dart';

/// Short spoken answers and commands (docs/PRIVACY.md, "Spoken answers"). Tried in order:
/// 1. the phone's **on-device** recogniser, where Android has one: audio stays on the phone;
/// 2. Magana's own server ASR (NCAIR1's Hausa, Yorùbá, Igbo and Nigerian-English models);
/// 3. for adults (18+) only, the phone's or browser's usual (online) recogniser, which may
///    send audio to Google, Apple or the phone maker. Guided and Classroom (under-18)
///    accounts never use it;
/// then nothing: the screen offers tapping the answer instead. Development builds log
/// every step and its outcome to the console ([devLog]).
abstract class VoiceInput {
  /// For logs: "on-device recogniser", "Magana server ASR", "online recogniser".
  String get name;

  /// Why [init] said no, for logs.
  String? get unavailableReason => null;

  /// False when this recogniser can't be used here (see [unavailableReason]).
  /// Doesn't listen.
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

/// The steps a tier may not use, and why, for logs.
Map<String, String> voiceStepsSkipped(Tier tier) => switch (tier) {
  Tier.standard => const {},
  Tier.guided => const {'online recogniser': 'Guided account (13 to 17)'},
  Tier.classroom => const {'online recogniser': 'Classroom account (under 13)'},
};

/// Replaceable in tests.
VoiceInput Function(Tier tier) voiceInput = (tier) =>
    ChainVoiceInput(voiceSteps(tier), skipped: voiceStepsSkipped(tier));

/// The voice input for whoever is using the app now (most restrictive until a
/// tier is chosen).
VoiceInput voiceInputFor(BuildContext context) =>
    voiceInput(AppScope.of(context).profile.tier ?? Tier.classroom);

class ChainVoiceInput extends VoiceInput {
  ChainVoiceInput(this.steps, {this.skipped = const {}});
  final List<VoiceInput> steps;

  /// Steps left out for this account, and why (logged, never tried).
  final Map<String, String> skipped;
  final _usable = <VoiceInput, bool>{};
  final _why = <VoiceInput, String>{};
  VoiceInput? _current;

  @override
  String get name => 'voice';

  @override
  String? get unavailableReason => steps.isEmpty
      ? 'no recogniser for this account'
      : [for (final s in steps) '${s.name}: ${_why[s] ?? 'not checked'}']
            .join('; ');

  Future<bool> _ready(VoiceInput step) async {
    if (_usable[step] case final known?) return known;
    bool ok;
    try {
      ok = await step.init();
    } catch (e) {
      ok = false;
      _why[step] = 'error: $e';
    }
    if (!ok) _why[step] ??= step.unavailableReason ?? 'not available';
    devLog(
      ok
          ? 'voice: ${step.name} available'
          : 'voice: ${step.name} skipped: ${_why[step]}',
    );
    return _usable[step] = ok;
  }

  void _logSkipped() {
    for (final MapEntry(:key, :value) in skipped.entries) {
      devLog('voice: $key skipped: $value');
    }
  }

  @override
  Future<bool> init() async {
    _logSkipped();
    for (final step in steps) {
      if (await _ready(step)) return true;
    }
    devLog('voice: no recogniser available; tap answers instead');
    return false;
  }

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    _logSkipped();
    for (final step in steps) {
      if (_usable[step] == false) {
        devLog('voice: ${step.name} skipped: ${_why[step]}');
        continue;
      }
      if (!await _ready(step)) continue;
      try {
        _current = step;
        final heard = await step.listen(language: language);
        devLog(
          'voice: ${step.name} listened ($language): '
          '${heard.isEmpty ? 'heard nothing' : 'heard $heard'}',
        );
        return heard;
      } catch (e) {
        final why = e is VoiceStepFailed ? e.reason : '$e';
        devLog('voice: ${step.name} failed: $why; trying the next step');
        _usable[step] = false; // not again this session
        _why[step] = 'failed earlier: $why';
      } finally {
        _current = null;
      }
    }
    devLog('voice: no recogniser left; tap answers instead');
    throw VoiceStepFailed('no recogniser');
  }

  @override
  Future<void> stop() async => _current?.stop();
}

class SpeechVoiceInput extends VoiceInput {
  SpeechVoiceInput({required this.onDevice});

  /// Only the phone's on-device recogniser, checked first: speech_to_text quietly
  /// uses the network recogniser when the phone has no on-device one.
  final bool onDevice;
  final _stt = SpeechToText();
  Completer<List<String>>? _pending;
  List<String> _heard = const []; // the latest result, final or not
  List<LocaleName> _locales = const [];
  String? _why;

  @override
  String get name => onDevice ? 'on-device recogniser' : 'online recogniser';

  @override
  String? get unavailableReason => _why;

  /// Errors that mean "heard nothing", not a broken recogniser: Android's, and
  /// the browser's ("no-speech"; "aborted" when Magana stopped listening).
  static const _heardNothing = {
    'error_no_match',
    'error_speech_timeout',
    'no-speech',
    'aborted',
  };

  @override
  Future<bool> init() async {
    try {
      if (onDevice && !await onDeviceSpeechAvailable()) {
        _why = kIsWeb
            ? 'browsers have no on-device recogniser'
            : 'this phone has no on-device recogniser';
        return false;
      }
      String? error;
      final ok = await _stt.initialize(
        onStatus: (status) {
          devLog('voice: $name status "$status"');
          if (status != SpeechToText.doneStatus) return;
          // "done" can arrive just before the final result; give it a moment.
          final waiting = _pending;
          Timer(const Duration(milliseconds: 500), () {
            if (identical(_pending, waiting)) _finish(_heard);
          });
        },
        onError: (e) {
          devLog('voice: $name error "${e.errorMsg}"');
          error = e.errorMsg;
          _heardNothing.contains(e.errorMsg)
              ? _finish(_heard) // heard nothing: not a failure
              : _fail(_explain(e.errorMsg));
        },
      );
      if (!ok) {
        _why = kIsWeb
            ? 'this browser has no speech recognition${error == null ? '' : ' ($error)'}'
            : 'no speech recogniser on this phone${error == null ? '' : ' ($error)'}';
        return false;
      }
      _locales = await _stt.locales();
      return true;
    } catch (e) {
      _why = 'error: $e';
      return false;
    }
  }

  static String _explain(String error) => switch (error) {
    'not-allowed' => 'microphone not allowed in this browser (not-allowed)',
    'service-not-allowed' =>
      'the browser refused speech recognition (service-not-allowed)',
    'network' =>
      "the browser's online recogniser could not be reached (network)",
    'audio-capture' => 'no microphone found (audio-capture)',
    'language-not-supported' =>
      'language not supported (language-not-supported)',
    _ => error,
  };

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
    _heard = const [];
    final done = _pending = Completer<List<String>>();
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: locale,
        onDevice: onDevice,
        // speech_to_text's web plugin marks every browser result as partial, and
        // drops partial results unless asked for them: Chrome heard "B" and Magana
        // got nothing. On the web, take them and use the latest when it stops.
        partialResults: kIsWeb,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    return done.future;
  }

  void _onResult(SpeechRecognitionResult r) {
    _heard = [
      for (final a in r.alternates)
        if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords,
    ];
    if (r.finalResult) _finish(_heard);
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
class ServerVoiceInput extends VoiceInput {
  ServerVoiceInput({AudioRecorder? recorder, http.Client? client})
    : _given = recorder,
      _client = client ?? http.Client();

  final AudioRecorder? _given;
  AudioRecorder? _made;
  // Created on first use: the recorder starts the native plugin.
  AudioRecorder get _recorder => _given ?? (_made ??= AudioRecorder());
  final http.Client _client;
  Completer<void>? _stopped;

  String? _why;

  @override
  String get name => 'Magana server ASR';

  @override
  String? get unavailableReason => _why;

  /// The server must have speech recognition (ASR_ENGINE=local), and the
  /// microphone must be allowed. Asking the server first means nothing is
  /// recorded for a server that can't recognise it.
  @override
  Future<bool> init() async {
    try {
      final res = await _client
          .get(Uri.parse('$apiBase/asr/available'), headers: serverHeaders)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        _why = 'the server answered ${res.statusCode}';
        return false;
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      if (body['available'] != true) {
        _why =
            'the server has no speech recognition (ASR_ENGINE=${body['engine']})';
        return false;
      }
    } catch (e) {
      _why = 'the server could not be reached ($e)';
      return false;
    }
    if (!await _recorder.hasPermission()) {
      _why = 'microphone not allowed';
      return false;
    }
    return true;
  }

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
        throw VoiceStepFailed('server answered ${res.statusCode} ${res.body}');
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
