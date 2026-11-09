// Hausa, Yorùbá and Igbo pages (Hausa review pack, 2 Nov 2026; docs/FINDINGS.md, 9 Nov 2026):
// English guidance keeps the counts and never says "Page read" when the page wasn't read; a page
// read on the phone warns first that it may have many mistakes; a slow (reachable) server's
// reading is waited for instead of the phone's.
@Tags(['safety'])
library;

import 'dart:convert';

import 'package:app/guidance.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/offline/offline_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show FakeSpeaker;
import 'white_paper_test.dart'
    show FakePhoto, FakeRecognizer, openCaptureAndTakePhoto, pumpOffline, seen;

final en = lookupAppLocalizations(const Locale('en'));
final ha = lookupAppLocalizations(const Locale('ha'));

/// A Hausa line the phone's word lists recognise as Hausa.
const hausaLines = [
  'Kungiya ce ta kasa da kasa ba ta riba ba',
  'kuma tana da mambobi da yawa a duniya baki daya',
  'An kafa ta a shekara ta dubu daya da dari tara',
];

void main() {
  tearDown(() => pageRecognizer = MlKitRecognizer());

  group('English guidance keeps the counts', () {
    test('plural texts: the count picks the English form', () async {
      final g = EnglishGuidance();
      expect(await g.toEnglish('ha', ha.letterCount(6)), en.letterCount(6));
      expect(await g.toEnglish('ha', ha.letterCount(1)), en.letterCount(1));
      expect(await g.toEnglish('ha', ha.linesFound(6)), '6 lines found.');
      expect(
        await g.toEnglish(
          'ha',
          '${ha.pageNoVoice('Hausa')} ${ha.linesFound(6)} ${ha.letterCount(4)}',
        ),
        "This page is in Hausa. I can't read it aloud yet. 6 lines found. "
        '4 words may be wrong.',
      );
    });
  });

  testWidgets(
    'read on the phone: "This reading may have many mistakes." first',
    (tester) async {
      final speaker = FakeSpeaker();
      pageRecognizer = FakeRecognizer(
        FakePhoto([
          for (final (i, t) in hausaLines.indexed)
            seen(t, 0.97, top: 40 + i * 80),
        ]),
      );
      await pumpOffline(
        tester,
        speaker,
        client: MockClient(
          (req) async => throw http.ClientException('offline'),
        ),
      );
      await openCaptureAndTakePhoto(tester);
      await tester.pumpAndSettle();
      final intro = speaker.said.firstWhere(
        (t) => t.contains(en.msg_letters_ha),
      );
      expect(intro, contains(en.msg_offline_letters_unreliable));
      // Before the page itself and before the Hausa note.
      expect(
        intro.indexOf(en.msg_offline_letters_unreliable),
        lessThan(intro.indexOf(en.msg_letters_ha)),
      );
    },
  );

  testWidgets(
    'a slow server on a Hausa page: its reading is waited for, not the phone\'s',
    (tester) async {
      final speaker = FakeSpeaker();
      pageRecognizer = FakeRecognizer(
        FakePhoto([
          for (final (i, t) in hausaLines.indexed)
            seen(t, 0.97, top: 40 + i * 80),
        ]),
      );
      await pumpOffline(
        tester,
        speaker,
        client: MockClient((req) async {
          await Future<void>.delayed(
            const Duration(seconds: 35),
          ); // past the 25 s wait
          return http.Response(
            jsonEncode({
              'tips': ['letters_ha'],
              'lines': [
                {
                  'text': 'Ƙungiya ce ta ƙasa da ƙasa',
                  'confidence': 0.96,
                  'top': 40,
                },
              ],
              'warnings': <Object>[],
              'page_language': 'ha',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await openCaptureAndTakePhoto(tester);
      await tester.pump(const Duration(seconds: 26));
      expect(
      speaker.said,
      contains('${en.waitingFullReading('Hausa')} ${en.stopWaitingHint}'),
    );
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(speaker.said, contains('Ƙungiya ce ta ƙasa da ƙasa'));
      expect(
        speaker.said.where(
          (t) => t.contains(en.msg_offline_letters_unreliable),
        ),
        isEmpty,
      );
    },
  );

  group('a long wait is never silent, and can be stopped', () {
    Future<FakeSpeaker> slowHausaServer(WidgetTester tester) async {
      final speaker = FakeSpeaker();
      pageRecognizer = FakeRecognizer(
        FakePhoto([
          for (final (i, t) in hausaLines.indexed)
            seen(t, 0.97, top: 40 + i * 80),
        ]),
      );
      await pumpOffline(
        tester,
        speaker,
        client: MockClient((req) async {
          await Future<void>.delayed(
            const Duration(seconds: 60),
          ); // past both waits
          return http.Response(
            jsonEncode({
              'tips': ['letters_ha'],
              'lines': [
                {
                  'text': 'Ƙungiya ce ta ƙasa da ƙasa',
                  'confidence': 0.96,
                  'top': 40,
                },
              ],
              'warnings': <Object>[],
              'page_language': 'ha',
            }),
            200,
          );
        }),
      );
      return speaker;
    }

    testWidgets('no wait goes longer than 8 s without speech', (tester) async {
      final speaker = await slowHausaServer(tester);
      await openCaptureAndTakePhoto(tester);
      // From the photo to the page itself: the 25 s server wait, then the 40 s one.
      // Counted on everything heard (the phone's voice or a recorded clip).
      final started = speaker.heard.length;
      var lastSpoken = 0, longestSilence = 0, heard = started;
      final reminders = <int>[];
      for (var s = 1; s <= 70; s++) {
        await tester.pump(const Duration(seconds: 1));
        if (speaker.heard.length != heard) {
          if (speaker.spoken.last == en.stillReadingPleaseWait) {
            reminders.add(s);
          }
          heard = speaker.heard.length;
          longestSilence = s - lastSpoken > longestSilence
              ? s - lastSpoken
              : longestSilence;
          lastSpoken = s;
        }
      }
      await tester.pumpAndSettle();
      expect(longestSilence, lessThanOrEqualTo(8));
      // "Please wait, I'm still reading." at 5 s, then every 8 s; no "Still reading…" before it.
      expect(reminders.take(3), [5, 13, 21]);
      expect(speaker.spoken, isNot(contains(startsWith('Still reading'))));
      expect(
        speaker.said,
        contains('${en.waitingFullReading('Hausa')} ${en.stopWaitingHint}'),
      );
    });

    for (final how in ['button', 'double tap']) {
      testWidgets(
        '"stop" by $how: the phone\'s reading now, with its warning',
        (tester) async {
          final speaker = await slowHausaServer(tester);
          await openCaptureAndTakePhoto(tester);
          await tester.pump(const Duration(seconds: 27)); // in the 40 s wait
          expect(find.bySemanticsLabel(en.stopWaitingLabel), findsOneWidget);
          if (how == 'button') {
            await tester.tap(find.bySemanticsLabel(en.stopWaitingLabel));
          } else {
            final at = tester.getCenter(find.byType(Scaffold).first);
            await tester.tapAt(at);
            await tester.pump(const Duration(milliseconds: 50));
            await tester.tapAt(at);
          }
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          final intro = speaker.said.lastWhere(
            (t) => t.contains(en.msg_letters_ha),
            orElse: () => '',
          );
          expect(intro, contains(en.msg_offline_letters_unreliable));
          expect(speaker.said.join(' '), isNot(contains('Ƙungiya')));
          await tester.pump(const Duration(seconds: 60));
          await tester.pumpAndSettle();
        },
      );
    }
  });
}
