// Board 9 "Report a problem": from Settings (Help), by voice on Home and in the Reader; a
// choice from the list; adults may add a voice note (60 s at most), under-18s get no recording
// option; page text off by default and never in a Classroom session; never a photo.
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/platform/device_model.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/about.dart';
import 'package:app/screens/report_problem.dart';
import 'package:app/screens/settings.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, captureToReader, tableJson;
import 'quiz_test.dart' show FakeVoice;

final en = lookupAppLocalizations(const Locale('en'));

class FakeRecorder implements NoteRecorder {
  bool allowed = true;
  int started = 0;
  @override
  Future<bool> start() async {
    started++;
    return allowed;
  }

  @override
  Future<VoiceNote?> stop() async =>
      VoiceNote(Uint8List.fromList([1, 2, 3, 4]), 'audio/mp4', 12);

  @override
  Future<void> cancel() async {}
}

Future<(FakeSpeaker, FakeVoice, List<Map>, FakeRecorder)> start(
  WidgetTester tester, {
  Tier tier = Tier.standard,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final voice = FakeVoice();
  voiceInput = (_) => voice;
  appVersion = () async => (version: '0.1.0', build: '6');
  phoneModel = () async => 'TECNO KI5q';
  final recorder = FakeRecorder();
  noteRecorder = () => recorder;
  final sent = <Map>[];
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
    teacherSession: true,
  );
  final client = MockClient((req) async {
    if (req.url.path == '/reports') {
      sent.add({'headers': req.headers, 'body': jsonDecode(req.body) as Map});
      return http.Response(jsonEncode({'code': 'report_sent'}), 201);
    }
    return http.Response(jsonEncode(tableJson), 200);
  });
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: client, headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  return (speaker, voice, sent, recorder);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

Future<void> openFromSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^${en.settings}')).first);
  await tester.pumpAndSettle();
  await tap(tester, RegExp('^${en.reportProblem}\\. '));
}

void main() {
  tearDown(() => noteRecorder = RecordNoteRecorder.new);

  testWidgets(
    'from Settings: a choice, then sent with version, phone, language and screen',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (speaker, _, sent, _) = await start(tester);
      await openFromSettings(tester);
      expect(speaker.said.last, '${en.reportProblem}. ${en.reportWhat}');
      expect(
        find.bySemanticsLabel(en.reportIncludeText),
        findsNothing,
      ); // no page here
      expectAccessible(tester, 'Report a problem');
      // Nothing chosen yet.
      await tap(tester, en.reportSend);
      expect(speaker.said.last, en.reportChooseFirst);
      expect(sent, isEmpty);
      await tap(tester, en.reportTooSlow);
      await tap(tester, en.reportSend);
      expect(sent.single['body'], {
        'kind': 'too_slow',
        'screen': 'settings',
        'app_version': '0.1.0+6',
        'phone_model': 'TECNO KI5q',
        'language': 'en',
      });
      expect(find.text(en.msg_report_sent, findRichText: true), findsOneWidget);
      expect(speaker.said.last, en.msg_report_sent);
      handle.dispose();
    },
  );

  testWidgets('an adult may add a voice note (sent with its length)', (
    tester,
  ) async {
    final (_, _, sent, recorder) = await start(tester);
    await openFromSettings(tester);
    await tap(tester, en.reportReadWrong);
    await tap(tester, en.reportRecord);
    expect(recorder.started, 1);
    await tap(tester, en.reportRecording(0));
    expect(find.text(en.reportVoiceNote(12)), findsOneWidget);
    await tap(tester, en.reportSend);
    final body = sent.single['body'] as Map;
    expect(body['voice_note'], base64Encode([1, 2, 3, 4]));
    expect((body['voice_type'], body['voice_seconds']), ('audio/mp4', 12));
  });

  testWidgets('a voice note stops itself at 60 seconds', (tester) async {
    final (_, _, _, _) = await start(tester);
    await openFromSettings(tester);
    await tap(tester, en.reportRecord);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(find.text(en.reportVoiceNote(12)), findsOneWidget);
  });

  for (final tier in [Tier.guided, Tier.classroom]) {
    testWidgets('${tier.name} (under 18): no recording option at all', (
      tester,
    ) async {
      final (_, _, sent, recorder) = await start(tester, tier: tier);
      await openFromSettings(tester);
      expect(find.bySemanticsLabel(en.reportRecord), findsNothing);
      await tap(tester, en.reportHardToUse);
      await tap(tester, en.reportSend);
      expect(recorder.started, 0);
      expect((sent.single['body'] as Map).containsKey('voice_note'), isFalse);
    });
  }

  testWidgets(
    'from the Reader by voice: page text off by default, sent only when switched on',
    (tester) async {
      final (_, voice, sent, _) = await start(tester);
      await captureToReader(tester);
      voice.replies.add(['report a problem']);
      await tap(tester, en.speakCommand);
      expect(find.text(en.reportWhat), findsOneWidget);
      final toggle = find.byType(Switch);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      await tap(tester, en.reportReadWrong);
      await tap(tester, en.reportSend);
      expect((sent.last['body'] as Map).containsKey('page_text'), isFalse);
      expect(sent.last['body']['screen'], 'reader');
    },
  );

  testWidgets('page text switched on goes with the report', (tester) async {
    final (_, voice, sent, _) = await start(tester);
    await captureToReader(tester);
    voice.replies.add(['report a problem']);
    await tap(tester, en.speakCommand);
    await tap(tester, en.reportIncludeText);
    await tap(tester, en.reportReadWrong);
    await tap(tester, en.reportSend);
    expect(sent.last['body']['page_text'], contains('Haemoglobin'));
  });

  testWidgets('a Classroom session never offers the page text', (tester) async {
    final (_, voice, _, _) = await start(tester, tier: Tier.classroom);
    await captureToReader(tester);
    voice.replies.add(['report a problem']);
    await tap(tester, en.speakCommand);
    expect(find.text(en.reportWhat), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('"report a problem" on Home opens it (not Everyday papers)', (
    tester,
  ) async {
    final (_, voice, _, _) = await start(tester);
    voice.replies.add(['report a problem with the reading']);
    await tap(tester, en.speakCommand);
    expect(find.text(en.reportWhat), findsOneWidget);
  });

  testWidgets('About: the support email is a button (mailto)', (tester) async {
    await start(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.emailSupport(supportEmail)), findsOneWidget);
  });
}
