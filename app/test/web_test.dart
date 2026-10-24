import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/messages.dart';
import 'package:app/platform.dart';
import 'package:app/policy.dart';
import 'package:app/screens/start.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, pumpApp;
import 'reminders_test.dart' as reminders;

final en = lookupAppLocalizations(const Locale('en'));

void main() {
  test('every server call carries the install ID for rate limiting', () async {
    deviceId = '9f2c41aa07d3e6b1';
    addTearDown(() => deviceId = '');
    final sent = <http.BaseRequest>[];
    final api = MaganaApi(
      client: MockClient((req) async {
        sent.add(req);
        return http.Response(
          jsonEncode({
            'code': 'explain_preview',
            'explanation': 'x',
            'read_instead': null,
            'preview': true,
          }),
          200,
        );
      }),
    );
    await api.explain(sourceText: 'x', language: 'en');
    expect(sent.single.headers['X-Magana-Device'], '9f2c41aa07d3e6b1');
  });

  test('too many requests: "Magana is busy", never a crash', () async {
    final api = MaganaApi(
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'detail': {'code': 'too_many_requests'},
          }),
          429,
          headers: {'retry-after': '20'},
        ),
      ),
    );
    try {
      await api.explain(sourceText: 'x', language: 'en');
      fail('expected an ApiException');
    } on ApiException catch (e) {
      expect(e.code, 'too_many_requests');
      expect(messageFor(en, e.code), en.msg_too_many_requests);
    }
  });

  testWidgets('web: reminders say they need the Android or iPhone app', (
    tester,
  ) async {
    runningOnWeb = true;
    addTearDown(() => runningOnWeb = false);
    final handle = tester.ensureSemantics();
    final (speaker, alerts) = await reminders.open(tester);
    expect(find.text(en.remindersNeedApp), findsOneWidget);
    expect(speaker.said.last, en.remindersNeedApp);
    expect(find.bySemanticsLabel(en.addReminder), findsNothing);
    expect(alerts.calls, isEmpty); // nothing scheduled in a browser
    expectAccessible(tester, 'Reminders on the web');
    handle.dispose();
  });

  testWidgets('phones: reminders work as before', (tester) async {
    final (_, _) = await reminders.open(tester, tier: Tier.standard);
    expect(find.text(en.remindersNeedApp), findsNothing);
    expect(find.bySemanticsLabel(en.addReminder), findsOneWidget);
  });

  group('Start Magana (the browser refuses to speak before a first press)', () {
    testWidgets('covers the screen, is read by screen readers, Enter starts', (
      tester,
    ) async {
      runningOnWeb = true;
      addTearDown(() => runningOnWeb = false);
      final handle = tester.ensureSemantics();
      final speaker = FakeSpeaker()..needsStart.value = true;
      await pumpApp(tester, speaker);
      // Speech waits for the press instead of failing.
      expect(await speaker.say('Welcome to Magana'), isFalse);
      expect(speaker.said, isEmpty);
      final start = find.bySemanticsLabel(en.startMagana);
      expect(start, findsOneWidget);
      final button = find.descendant(
        of: find.byType(StartMagana),
        matching: find.byType(FilledButton),
      );
      expect(tester.getSize(button).height, greaterThan(800));
      // Nothing underneath is reachable while covered.
      expect(find.bySemanticsLabel(RegExp('^${en.readPage}')), findsNothing);
      expectAccessible(tester, 'Start Magana');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(start, findsNothing);
      expect(speaker.said, ['Welcome to Magana']); // said after the press
      expect(find.bySemanticsLabel(RegExp('^${en.readPage}')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Space works too', (tester) async {
      runningOnWeb = true;
      addTearDown(() => runningOnWeb = false);
      final speaker = FakeSpeaker()..needsStart.value = true;
      await pumpApp(tester, speaker);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text(en.startMagana), findsNothing);
      expect(speaker.needsStart.value, isFalse);
    });

    testWidgets('never on Android or iOS', (tester) async {
      final speaker = FakeSpeaker()..needsStart.value = true;
      await pumpApp(tester, speaker);
      expect(find.text(en.startMagana), findsNothing);
    });
  });
}
