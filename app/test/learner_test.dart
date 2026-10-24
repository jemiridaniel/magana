import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/commands.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/about.dart';
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

/// A label whose "500" the backend flagged, plus a table.
final pageJson = <String, Object?>{
  ...tableJson,
  'lines': [
    {
      'text': 'Amoxicillin 500 mg capsules',
      'confidence': 0.95,
      'top': 40,
      'label': 'line 1',
    },
  ],
  'warnings': [
    {'block_index': 0, 'code': 'low_confidence_number', 'word_index': 1},
  ],
};

class Backend {
  final explains = <Map>[];
  Map<String, Object?> explainReply(Map body) => {
    'code': 'explain_preview',
    'explanation': body['source_text'],
    'read_instead': null,
    'preview': true,
  };

  MockClient get client => MockClient((req) async {
    if (req.url.path == '/explain') {
      final body = jsonDecode(req.body) as Map;
      explains.add(body);
      return http.Response(jsonEncode(explainReply(body)), 200);
    }
    return http.Response(jsonEncode(pageJson), 200);
  });
}

class GuardFails extends Backend {
  @override
  Map<String, Object?> explainReply(Map body) => {
    'code': 'numbers_unconfirmed',
    'explanation': null,
    'read_instead': body['source_text'],
    'preview': false,
  };
}

/// A tester or production server whose Explain host isn't approved (docs/MODELS.md).
class NotApproved extends Backend {
  @override
  Map<String, Object?> explainReply(Map body) => {
    'code': 'explain_not_available',
    'explanation': null,
    'read_instead': body['source_text'],
    'preview': false,
  };
}

Future<(FakeSpeaker, Backend, FakeVoice, LanguageController)> start(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  Backend? backend,
  bool voiceWorks = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final voice = FakeVoice(works: voiceWorks);
  voiceInput = (tier) => voice..tiers.add(tier);
  appVersion = () async => (version: '0.1.0', build: '3');
  final b = backend ?? Backend();
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
    teacherSession: true,
  );
  final speaker = FakeSpeaker();
  final language = LanguageController();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: b.client, headers: () => profile.headers),
      speaker: speaker,
      language: language,
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  return (speaker, b, voice, language);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

Future<void> say(WidgetTester tester, FakeVoice voice, String words) async {
  voice.replies.add([words]);
  await tap(tester, en.speakCommand);
}

void main() {
  group('voice command rules', () {
    bool all(Feature _) => true;
    bool teen(Feature f) => allows(Tier.guided, f);

    test('one spoken command for each main action', () {
      for (final (said, want) in [
        ('read a page', VoiceCommand.readPage),
        ('open the camera', VoiceCommand.readPage),
        ('read my test results', VoiceCommand.everyday),
        ('bank statement', VoiceCommand.everyday),
        ('practice quiz', VoiceCommand.quiz),
        ('my library', VoiceCommand.library),
        ('skills', VoiceCommand.skills),
        ('my score', VoiceCommand.score),
        ('ask a question', VoiceCommand.ask),
        ('medicine reminders', VoiceCommand.reminders),
        ('talk to a nurse', VoiceCommand.nurse),
        ('change language to Igbo', VoiceCommand.language),
        ('settings', VoiceCommand.settings),
        ('help', VoiceCommand.help),
      ]) {
        expect(matchCommand(said, all), want, reason: said);
      }
      expect(matchCommand('the latest news', all), isNull);
      expect(matchCommand('', all), isNull);
    });

    test('commands a tier cannot use are never matched', () {
      expect(matchCommand('bank statement', teen), isNull);
      expect(matchCommand('talk to a nurse', teen), isNull);
      expect(matchCommand('practice quiz', teen), VoiceCommand.quiz);
    });

    test('a named language', () {
      expect(namedLanguage('change language to Igbo')?.code, 'ig');
      expect(namedLanguage('switch to yoruba')?.code, 'yo');
      expect(namedLanguage('change language'), isNull);
    });
  });

  testWidgets('3b language sheet: hear each, then Use; closing keeps it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, _, _, language) = await start(tester);
    await tap(tester, 'App language: English. Change language');
    expect(find.text(en.languageSheetBody), findsOneWidget);
    final ig = lookupAppLocalizations(const Locale('ig'));
    expect(find.bySemanticsLabel('Igbo. ${ig.welcome}'), findsOneWidget);
    expectAccessible(tester, 'Language sheet');
    await tap(tester, RegExp('^Igbo'));
    expect(speaker.language, 'ig');
    expect(speaker.said.last, 'Igbo. ${ig.welcome}');
    // Closed without "Use Igbo": nothing changes, the voice goes back.
    Navigator.of(tester.element(find.text(en.languageSheetBody))).pop();
    await tester.pumpAndSettle();
    expect(language.value, const Locale('en'));
    expect(speaker.language, 'en');
    handle.dispose();
  });

  testWidgets('settings: version for testers, how to report a problem', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await start(tester);
    await tap(tester, en.settings);
    await tester.pumpAndSettle();
    expect(find.text(en.settingsVersion('0.1.0', '3')), findsOneWidget);
    expect(find.text(en.reportHow), findsOneWidget);
    expectAccessible(tester, 'Settings');
    await tap(tester, RegExp('^${en.aboutTitle}'));
    // The terms' credit lines, verbatim, as each model card words them.
    expect(
      find.text(en.aboutContact('maganasupport@gmail.com')),
      findsOneWidget,
    );
    expect(find.text(natlasAttribution), findsOneWidget);
    for (final line in asrAttributions) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text(termsCondition), findsOneWidget);
    expectAccessible(tester, 'About');
    handle.dispose();
  });

  testWidgets('speak a command: opens the screen, or says what it heard', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, _, voice, language) = await start(tester);
    expectAccessible(tester, 'Home');
    await say(tester, voice, 'open my library');
    expect(find.text(en.librarySubtitle), findsOneWidget);
    await tap(tester, en.back);

    await say(tester, voice, 'what is the weather');
    expect(speaker.said.last, en.commandNotUnderstood('what is the weather'));

    await say(tester, voice, 'change language to Hausa');
    expect(language.value, const Locale('ha'));
    // Commands are English keywords, whatever the app language.
    expect(voice.languages.toSet(), {'en'});
    handle.dispose();
  });

  testWidgets('help lists only what this tier can do', (tester) async {
    final (speaker, _, voice, _) = await start(tester, tier: Tier.guided);
    await say(tester, voice, 'help');
    expect(speaker.said.last, contains(en.practiceQuiz));
    expect(speaker.said.last, isNot(contains(en.everydayPapers)));
    expect(speaker.said.last, isNot(contains(en.talkToNurse)));
  });

  testWidgets('no recogniser: says so', (tester) async {
    final (speaker, _, voice, _) = await start(tester, voiceWorks: false);
    await tap(tester, en.speakCommand);
    expect(speaker.said.last, en.voiceCommandsUnavailable);
    expect(voice.listens, 0);
  });

  testWidgets('reader: jump within page to the table', (tester) async {
    final handle = tester.ensureSemantics();
    final (speaker, _, _, _) = await start(tester);
    await captureToReader(tester);
    await tap(tester, en.jumpWithinPage);
    expect(find.text(en.jumpNotYet), findsOneWidget);
    expectAccessible(tester, 'Jump sheet');
    await tap(tester, en.jumpTable(1));
    expect(speaker.said.last, startsWith('Row 1 of 1. Test: Haemoglobin.'));
    handle.dispose();
  });

  testWidgets(
    '6 explain (preview): page text through the guard, unclear stays unclear',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (speaker, backend, voice, _) = await start(tester);
      await captureToReader(tester);
      await tap(tester, en.explainThis);
      expect(find.text(en.explainPreviewBanner), findsOneWidget);
      final sent = backend.explains.single;
      // The unreliable "500" is never handed to an explainer.
      expect(sent['source_text'], contains('Amoxicillin unclear number mg'));
      expect(sent['source_text'], isNot(contains('500')));
      expect(sent['lang'], 'en');
      expect(find.text(en.msg_explain_preview), findsOneWidget);
      expect(speaker.said.last, startsWith(en.msg_explain_preview));
      expect(find.text(en.basedOnPage(2)), findsOneWidget);
      expectAccessible(tester, 'Explain');

      await tap(tester, en.answerLanguage('English'));
      await tap(tester, en.saySimpler);
      expect(backend.explains.last['lang'], 'ha');
      expect(backend.explains.last['style'], 'simpler');

      voice.replies.add(['what does this table mean']);
      await tap(tester, en.askAQuestion);
      expect(voice.languages.last, 'en'); // the app language
      expect(
        find.bySemanticsLabel('${en.youSaid}: what does this table mean'),
        findsOneWidget,
      );
      expect(backend.explains.last['question'], 'what does this table mean');
      expect(speaker.said.last, startsWith(en.explainQuestionPreview));

      await tap(tester, en.reportProblem);
      expect(find.text(en.reportHow), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('explain: when the guard fails, the page is read instead', (
    tester,
  ) async {
    final (speaker, _, _, _) = await start(tester, backend: GuardFails());
    await captureToReader(tester);
    await tap(tester, en.explainThis);
    expect(find.text(en.msg_numbers_unconfirmed), findsOneWidget);
    expect(speaker.said.last, startsWith(en.msg_numbers_unconfirmed));
    expect(speaker.said.last, contains('Amoxicillin unclear number mg'));
  });

  testWidgets('ask a question from Home: explains a page, so read one first', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, backend, _, _) = await start(tester);
    await tap(tester, en.askQuestion);
    expect(find.text(en.explainNoPage), findsOneWidget);
    expect(speaker.said.last, '${en.explainTitle}. ${en.explainNoPage}');
    expect(backend.explains, isEmpty);
    expectAccessible(tester, 'Explain without a page');
    handle.dispose();
  });

  testWidgets('under 13: no Explain this in the Reader', (tester) async {
    await start(tester, tier: Tier.classroom);
    await captureToReader(tester);
    expect(find.bySemanticsLabel(en.explainThis), findsNothing);
  });

  for (final tier in [Tier.guided, Tier.classroom]) {
    testWidgets('${tier.name}: Ask a question is hidden, by tile and by voice', (
      tester,
    ) async {
      final (speaker, backend, voice, _) = await start(tester, tier: tier);
      expect(find.bySemanticsLabel(RegExp('^${en.askQuestion}')), findsNothing);
      if (tier == Tier.guided) {
        // Classroom sessions have no voice commands for open questions either;
        // Guided learners can speak commands, but this one isn't offered.
        await say(tester, voice, 'ask a question');
        expect(speaker.said.last, en.commandNotUnderstood('ask a question'));
        await say(tester, voice, 'help');
        expect(speaker.said.last, isNot(contains(en.askQuestion)));
      }
      expect(backend.explains, isEmpty);
    });
  }

  testWidgets(
    'tester build without an approved host: not available, page read',
    (tester) async {
      final (speaker, _, _, _) = await start(tester, backend: NotApproved());
      await captureToReader(tester);
      await tap(tester, en.explainThis);
      expect(find.text(en.msg_explain_not_available), findsOneWidget);
      expect(speaker.said.last, startsWith(en.msg_explain_not_available));
      expect(speaker.said.last, contains('Amoxicillin unclear number mg'));
    },
  );
}
