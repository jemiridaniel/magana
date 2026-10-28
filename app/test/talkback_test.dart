// Android TalkBack audit (docs/TALKBACK_AUDIT.md): what failed on the emulator, kept fixed.
import 'dart:async';
import 'dart:convert';

import 'package:app/platform/speech_support.dart';
import 'package:app/voice_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import 'onboarding_test.dart' show start, tap;

/// The phone's recogniser, scripted: each listen reports the next error, or nothing at all.
class FakeRecogniser extends SpeechToTextPlatform {
  FakeRecogniser(this.errors);
  final List<String?> errors;
  var listens = 0;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async => true;
  @override
  Future<List<dynamic>> locales() async => ['en_NG:English (Nigeria)'];
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    final error = errors[listens++];
    if (error != null) {
      scheduleMicrotask(() {
        onStatus?.call('listening');
        onError?.call(jsonEncode({'errorMsg': error, 'permanent': true}));
        onStatus?.call('done');
      });
    }
    return true;
  }
}

/// A step that notes when it started listening.
class Noting extends VoiceInput {
  DateTime? startedAt;
  @override
  String get name => 'noting';
  @override
  Future<bool> init() async => true;
  @override
  Future<List<String>> listen({
    String language = 'en',
    AnswerChoices? choices,
  }) async {
    startedAt = DateTime.now();
    return ['help'];
  }

  @override
  Future<void> stop() async {}
}

void main() {
  final realOnDevice = onDeviceSpeechAvailable;
  final realReaderRunning = screenReaderRunning;
  final realReaderSpeaking = screenReaderSpeaking;
  tearDown(() {
    onDeviceSpeechAvailable = realOnDevice;
    screenReaderRunning = realReaderRunning;
    screenReaderSpeaking = realReaderSpeaking;
    SpeechVoiceInput.watchdog = const Duration(seconds: 30);
  });

  test('no on-device English model: the online step still answers, never "Listening…" '
      'for ever', () async {
    // The emulator, 27 Oct 2026: the on-device step failed with error_language_unavailable,
    // and the online step's "heard nothing" went to the on-device step's handlers.
    SpeechToTextPlatform.instance = FakeRecogniser([
      'error_language_unavailable',
      'error_speech_timeout',
    ]);
    onDeviceSpeechAvailable = () async => true;
    screenReaderRunning = () => false;
    final chain = ChainVoiceInput([
      SpeechVoiceInput(onDevice: true),
      SpeechVoiceInput(onDevice: false),
    ]);
    expect(await chain.init(), isTrue);
    final heard = await chain.listen().timeout(const Duration(seconds: 5));
    expect(heard, isEmpty); // heard nothing: "Sorry, I didn't catch that…"
  });

  test('a recogniser that never answers is stopped by the watchdog', () async {
    SpeechToTextPlatform.instance = FakeRecogniser([null]);
    onDeviceSpeechAvailable = () async => false;
    screenReaderRunning = () => false;
    SpeechVoiceInput.watchdog = const Duration(milliseconds: 200);
    final step = SpeechVoiceInput(onDevice: false);
    expect(await step.init(), isTrue);
    expect(await step.listen().timeout(const Duration(seconds: 3)), isEmpty);
  });

  test(
    'with TalkBack on, the microphone opens only once TalkBack is quiet',
    () async {
      screenReaderRunning = () => true;
      var checks = 0;
      DateTime? quietAt;
      screenReaderSpeaking = () async {
        if (++checks < 4) return true; // still saying "Speak a command, button"
        quietAt ??= DateTime.now();
        return false;
      };
      final step = Noting();
      final heard = await ChainVoiceInput([step]).listen();
      expect(heard, ['help']);
      expect(checks, greaterThanOrEqualTo(4));
      expect(step.startedAt!.isBefore(quietAt!), isFalse);
    },
  );

  test('with TalkBack off, nothing waits', () async {
    screenReaderRunning = () => false;
    var asked = false;
    screenReaderSpeaking = () async => asked = true;
    expect(await ChainVoiceInput([Noting()]).listen(), ['help']);
    expect(asked, isFalse);
  });

  testWidgets(
    'each onboarding step is reached title first; Android Back goes one step '
    'back, not out of Magana',
    (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      String first() => tester.semantics
          .simulatedAccessibilityTraversal()
          .firstWhere((n) => n.label.isNotEmpty)
          .label;
      expect(first(), 'Choose your language');
      await tap(tester, 'Continue');
      expect(find.text('How old are you?'), findsOneWidget);
      // TalkBack lands on the first item: the title, not Back or "Step 2 of 4".
      expect(first(), 'How old are you?');

      // Android's Back button (and TalkBack's back gesture).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Choose your language'), findsOneWidget);
      handle.dispose();
    },
  );
}
