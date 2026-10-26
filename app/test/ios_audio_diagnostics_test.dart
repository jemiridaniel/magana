// iPhone speech with the silent switch on (AVAudioSession playback, spokenAudio) and the hidden
// diagnostics screen (Settings → tap the version 7 times).
import 'package:app/api.dart';
import 'package:app/diagnostics.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/speech.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'app_test.dart' show captureToReader;
import 'learner_test.dart' show start, tap;

final en = lookupAppLocalizations(const Locale('en'));

class RecordingTts extends FlutterTts {
  final calls = <String>[];

  @override
  Future<dynamic> setSharedInstance(bool sharedSession) async =>
      calls.add('shared $sharedSession');

  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async => calls.add(
    '${category.name} ${mode.name} ${options.map((o) => o.name).join('+')}',
  );

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak $text');
    startHandler?.call();
    completionHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async => false;
  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> stop() async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'iPhone: playback + spokenAudio before every utterance (works on silent)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final tts = RecordingTts();
      final speaker = Speaker(tts: tts);
      await speaker.say('Line 1.');
      await speaker.say('Line 2.');
      final set = tts.calls.where((c) => c.startsWith('playback')).toList();
      expect(
        set,
        hasLength(2),
      ); // again before each: recording changes the session
      expect(
        set.first,
        'playback spokenAudio duckOthers+interruptSpokenAudioAndMixWithOthers',
      );
      expect(
        tts.calls.indexOf(set.first),
        lessThan(tts.calls.indexOf('speak Line 1.')),
      );
      expect(diagnostics.speechOutcome, 'finished');
    },
  );

  test('Android: the audio session is left alone', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final tts = RecordingTts();
    await Speaker(tts: tts).say('Line 1.');
    expect(tts.calls.where((c) => c.startsWith('playback')), isEmpty);
  });

  testWidgets(
    '7 taps on the version open diagnostics: the last attempt, no image',
    (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await captureToReader(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await tap(tester, en.settings);
      final version = find.text(en.settingsVersion('0.1.0', '3'));
      for (var i = 0; i < 6; i++) {
        await tester.tap(version);
        await tester.pump();
      }
      expect(find.text('Diagnostics'), findsNothing);
      await tester.tap(version);
      await tester.pumpAndSettle();
      expect(find.text('Diagnostics'), findsOneWidget);
      String row(String name) =>
          tester.getSemantics(find.bySemanticsLabel(RegExp('^$name: '))).label;
      expect(row('Server'), 'Server: $apiBase');
      expect(row('App key'), startsWith('App key: '));
      expect(row('Capture fired'), 'Capture fired: system_camera');
      expect(row('Read by'), 'Read by: server');
      expect(row('Server status'), 'Server status: 200');
      expect(row('Words read'), contains('Amoxicillin'));
      expect(row('Photo size'), isNot('Photo size: —'));
      handle.dispose();
    },
  );
}
