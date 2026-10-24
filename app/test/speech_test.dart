import 'package:app/platform.dart';
import 'package:app/speech.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The real [Speaker] on a fake text-to-speech engine: the test plays the
/// engine's events (start, done, errors) the way a browser or phone sends them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final spoken = <String>[];
  final logs = <String>[];
  late void Function(String) originalLog;
  late FlutterTts tts;
  late Speaker speaker;

  setUp(() {
    spoken.clear();
    logs.clear();
    originalLog = devLog;
    devLog = logs.add;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          if (call.method == 'speak') spoken.add('${call.arguments}');
          return 1;
        });
    tts = FlutterTts();
    speaker = Speaker(tts: tts);
  });
  // Each test ends past the 3 s "engine never started" safety timer.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 4));

  tearDown(() {
    devLog = originalLog;
    runningOnWeb = false;
  });

  testWidgets(
    'cut off by something else: said once more, then reading goes on',
    (tester) async {
      final said = speaker.say('Question 1 of 10');
      await tester.pump();
      tts.startHandler!();
      tts.errorHandler!('interrupted'); // not Magana: TalkBack, another tab...
      await tester.pump(Speaker.retryDelay);
      await tester.pump();
      expect(spoken, ['Question 1 of 10', 'Question 1 of 10']);
      tts.startHandler!();
      tts.completionHandler!();
      expect(await said, isTrue);
      expect(
        logs,
        contains('speech error "interrupted" while saying "Question 1 of 10"'),
      );
      await settle(tester);
    },
  );

  testWidgets('"canceled" twice: tried twice only, never a loop', (
    tester,
  ) async {
    final said = speaker.say('A, Iodine.');
    await tester.pump();
    tts.startHandler!();
    tts.errorHandler!('canceled');
    await tester.pump(Speaker.retryDelay);
    await tester.pump();
    tts.startHandler!();
    tts.errorHandler!('canceled');
    expect(await said, isFalse);
    expect(spoken, hasLength(2));
    await settle(tester);
  });

  testWidgets('Magana stopping itself is normal: no retry', (tester) async {
    final first = speaker.say('Question 1 of 10');
    await tester.pump();
    tts.startHandler!();
    final second = speaker.say('Correct!'); // the learner pressed an answer
    await tester.pump();
    tts.errorHandler!('interrupted'); // the first one's late report
    expect(await first, isFalse);
    await tester.pump(Speaker.retryDelay * 2);
    expect(spoken, ['Question 1 of 10', 'Correct!']);
    tts.startHandler!();
    tts.completionHandler!();
    expect(await second, isTrue);
    await settle(tester);
  });

  testWidgets(
    'not-allowed on the web: waits for "Start Magana", then says it',
    (tester) async {
      runningOnWeb = true;
      final said = speaker.say('Choose your language');
      await tester.pump();
      tts.errorHandler!('not-allowed');
      expect(await said, isFalse);
      expect(speaker.needsStart.value, isTrue);
      expect(
        logs,
        contains(
          'speech error "not-allowed" while saying "Choose your language"',
        ),
      );

      // Until the press, nothing is sent to the engine.
      await speaker.say('Hausa');
      expect(spoken, ['Choose your language']);

      final started = speaker.start();
      await tester.pump();
      expect(speaker.needsStart.value, isFalse);
      expect(spoken.last, 'Hausa'); // the latest, not a backlog
      tts.startHandler!();
      tts.completionHandler!();
      await started;
      await settle(tester);
    },
  );

  testWidgets('synthesis-failed is logged with the text, not retried', (
    tester,
  ) async {
    final said = speaker.say('N186,750.00');
    await tester.pump();
    tts.startHandler!();
    tts.errorHandler!('synthesis-failed');
    expect(await said, isFalse);
    await tester.pump(Speaker.retryDelay * 2);
    expect(spoken, hasLength(1));
    expect(
      logs.first,
      'speech error "synthesis-failed" while saying "N186,750.00"',
    );
    await settle(tester);
  });
}
