// One screen talks at a time (iPhone test, 27 Oct 2026: "Read a page" kept talking after going
// back to Home). Open a screen, let it start speaking, press Back: nothing more from it.
import 'dart:async';

import 'package:app/api.dart';
import 'package:app/quiz.dart';
import 'package:app/screens/capture.dart';
import 'package:app/screens/everyday.dart';
import 'package:app/screens/library.dart';
import 'package:app/screens/quiz.dart';
import 'package:app/screens/quiz_list.dart';
import 'package:app/screens/reader.dart';
import 'package:app/screens/settings.dart';
import 'package:app/speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show FakeSpeaker, pumpApp, readJson;

/// A voice that takes 400 ms per utterance, like a real one, and is cut short by stop().
class SlowSpeaker extends FakeSpeaker {
  int stops = 0;
  Completer<Spoken>? _now;

  @override
  Future<Spoken> utter(String text) {
    said.add(text);
    final done = _now = Completer<Spoken>();
    Timer(const Duration(milliseconds: 400), () {
      if (!done.isCompleted) done.complete(Spoken.finished);
    });
    return done.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final now = _now;
    if (now != null && !now.isCompleted) now.complete(Spoken.stoppedByMagana);
  }
}

void main() {
  final screens = <String, Widget Function()>{
    'Read a page': () => CaptureScreen(findCameras: () async => []),
    'Everyday papers': () => const EverydayScreen(),
    'My library': () => const LibraryScreen(),
    'Practice quiz': () => const QuizListScreen(),
    'Reader': () => ReaderScreen(
      result: ReadResult.fromJson({
        ...readJson,
        'lines': [
          for (var i = 1; i <= 12; i++)
            {
              'text': 'Line number $i of the page',
              'confidence': 0.97,
              'top': i * 40,
            },
        ],
        'warnings': <Map<String, dynamic>>[],
      }),
    ),
    'Quiz': () => QuizScreen(load: Quiz.load),
    'Settings': () => const SettingsScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name: Back stops its voice; nothing from it after 100 ms', (
      tester,
    ) async {
      final speaker = SlowSpeaker();
      await pumpApp(tester, speaker);
      await tester.pump(const Duration(seconds: 1)); // Home's own summary, done
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => screen()));
      // Let it start talking (its summary, guidance, the page or the question).
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final before = speaker.said.length;
      expect(before, greaterThan(0), reason: '$name said nothing');
      final stops = speaker.stops;
      nav.pop();
      await tester.pump(); // the change of screen
      expect(speaker.stops, greaterThan(stops), reason: 'not stopped on Back');
      final atBack = speaker.said.length;
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        speaker.said.sublist(atBack),
        isEmpty,
        reason: '$name kept talking after Back',
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'a screen covered by another stays quiet until it is in front again',
    (tester) async {
      final speaker = SlowSpeaker();
      await pumpApp(tester, speaker);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => screens['Reader']!()));
      await tester.pump(const Duration(milliseconds: 500)); // reading line 1
      nav.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      await tester.pump();
      final atCover = speaker.said.length;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Only Settings' own summary: no more lines of the page behind it.
      expect(
        speaker.said.sublist(atCover).where((t) => t.startsWith('Line number')),
        isEmpty,
      );
      nav.pop();
      nav.pop();
      await tester.pumpAndSettle();
    },
  );
}
