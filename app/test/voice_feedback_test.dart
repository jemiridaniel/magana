// Nurse Balogun's voice-note feedback (Android, build 7, eyes closed): voices per language
// (never Hausa, Yorùbá or Igbo read with an English voice), the best voice and Settings → Voice,
// recorded prompts, the guided tour, "What can I say?" on every screen, Bluetooth headsets.
import 'dart:convert';
import 'dart:io';

import 'package:app/clips.dart';
import 'package:app/guidance.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/speech.dart';
import 'package:app/voice_input.dart';
import 'package:app/voices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart';
import 'onboarding_test.dart' as onboarding;
import 'quiz_test.dart' show FakeVoice;

final en = lookupAppLocalizations(const Locale('en'));

class FakeClipPlayer implements ClipPlayer {
  final played = <String>[];
  @override
  Future<bool> play(String file) async {
    played.add(file);
    return true;
  }

  @override
  Future<void> stop() async {}
}

Future<void> tapLabel(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

void main() {
  group('choosing the best voice', () {
    const ngStd = Voice(name: 'en-ng-x-tfn-local', locale: 'en-NG');
    const usPremium = Voice(name: 'Ava', locale: 'en-US', quality: 'premium');
    const gbCompact = Voice(
      name: 'Daniel',
      locale: 'en-GB',
      identifier: 'com.apple.voice.compact.en-GB.Daniel',
    );
    const gbEnhanced = Voice(
      name: 'Serena',
      locale: 'en-GB',
      quality: 'enhanced',
    );
    const bells = Voice(
      name: 'Bells',
      locale: 'en-US',
      identifier: 'com.apple.speech.synthesis.voice.Bells',
    );

    test('Nigerian English first, then quality; never another language', () {
      expect(bestVoice([usPremium, ngStd, gbEnhanced], 'en'), ngStd);
      expect(bestVoice([gbCompact, gbEnhanced], 'en'), gbEnhanced);
      expect(bestVoice([bells, gbCompact], 'en'), gbCompact);
      expect(bestVoice([usPremium, ngStd], 'ha'), isNull);
      expect(voicesFor([gbCompact, usPremium, ngStd], 'en').first, ngStd);
    });

    test('a Hausa voice is used for Hausa only', () {
      const ha = Voice(name: 'ha-ng', locale: 'ha_NG');
      expect(bestVoice([ngStd, ha], 'ha'), ha);
      expect(bestVoice([ha], 'en'), isNull);
    });

    test('a clearer English voice to download', () {
      // Android: no Nigerian English installed → say how to get it.
      expect(betterEnglishVoiceAvailable([usPremium]), isTrue);
      expect(betterEnglishVoiceAvailable([ngStd]), isFalse);
    });
  });

  group('never another language\'s voice', () {
    test('Hausa without a Hausa voice: not said, told once', () async {
      final s = FakeSpeaker()..noVoiceFor.add('ha');
      final told = <String>[];
      s.onNoVoice = told.add;
      expect(await s.say('Ruwa yana da muhimmanci', language: 'ha'), isTrue); // nothing to hear
      expect(await s.say('Kasar tana da dalibai', language: 'ha'), isTrue);
      expect(s.said, isEmpty);
      expect(told, ['ha']);
    });

    test('a line in two languages: each in its own voice, or not at all', () async {
      final s = FakeSpeaker()..noVoiceFor.add('yo');
      await s.sayParts([
        const SpeechPart('Line 2', 'en'),
        const SpeechPart('Ẹ káàárọ̀', 'yo'),
        const SpeechPart('Unclear', 'en'),
      ]);
      expect(s.said, ['Line 2', 'Unclear']);
    });

    test('parts in one language are one sentence, as before', () async {
      final s = FakeSpeaker();
      await s.sayParts([
        const SpeechPart('Row 1 of 2', 'en'),
        const SpeechPart('Test: Haemoglobin.', 'en'),
      ]);
      expect(s.said, ['Row 1 of 2. Test: Haemoglobin.']);
    });

    testWidgets(
      'a Hausa page and no Hausa voice: the text is shown, not read in English',
      (tester) async {
        final speaker = FakeSpeaker()..noVoiceFor.add('ha');
        await pumpApp(
          tester,
          speaker,
          body: {
            'tips': <String>[],
            'lines': [
              {'text': 'Ruwa yana da muhimmanci', 'confidence': 0.96, 'top': 40},
            ],
            'warnings': <Object>[],
            'page_language': 'ha',
          },
        );
        await captureToReader(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Ruwa yana da muhimmanci'), findsWidgets);
        expect(
          speaker.said.where((t) => t.contains('Ruwa yana da')),
          isEmpty,
        );
        expect(speaker.said, contains(en.noVoiceYet('Hausa')));
        expect(find.text(en.noVoiceYet('Hausa')), findsOneWidget);
      },
    );
  });

  group('recorded prompts', () {
    test('a phrase with a clip is played; the rest by the phone', () async {
      final player = FakeClipPlayer();
      final s = FakeSpeaker()
        ..clips = ClipLibrary.of(
          {
            'en': {'Page read.': 'pageRead'},
          },
          {
            'en': {'pageRead': 'en-pageRead.m4a'},
          },
        )
        ..clipPlayer = player;
      await s.say('Page read. Seven lines.');
      expect(player.played, ['en-pageRead.m4a']);
      expect(s.said, ['Seven lines.']);
    });

    test('a health template: its words from clips, its numbers by the phone', () async {
      final player = FakeClipPlayer();
      final s = FakeSpeaker()
        ..clips = ClipLibrary.of(
          {'ha': {}},
          {
            'ha': {
              'tpl-x-1': 'ha-tpl-x-1.m4a',
              'tpl-x-3': 'ha-tpl-x-3.m4a',
            },
          },
          {
            'ha': [
              ClipPattern('tpl-x', const [
                (text: 'Sha ƙwaya ', id: 'tpl-x-1', slot: false),
                (text: '', id: null, slot: true),
                (text: ' sau ', id: 'tpl-x-2', slot: false),
                (text: '', id: null, slot: true),
                (text: ' a rana.', id: 'tpl-x-3', slot: false),
              ]),
            ],
          },
        )
        ..clipPlayer = player;
      await s.say('Sha ƙwaya 2 sau 3 a rana.', language: 'ha');
      expect(player.played, ['ha-tpl-x-1.m4a', 'ha-tpl-x-3.m4a']);
      expect(s.said, ['2', 'sau', '3']); // numbers exactly as printed, never a clip
    });

    test('no clips recorded yet: everything as before', () async {
      final s = FakeSpeaker()..clips = ClipLibrary.of({'en': {}}, {});
      await s.say('Page read.');
      expect(s.said, ['Page read.']);
    });

    test('every fixed phrase of the app is in the phrase list to record', () {
      // scripts/export_phrases.py must be run again when the app's texts change.
      final phrases =
          jsonDecode(File('assets/voice/phrases.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final lang in ['en', 'ha', 'yo', 'ig']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
                as Map<String, dynamic>;
        final known = (phrases[lang] as Map).keys.toSet();
        final missing = [
          for (final MapEntry(:key, :value) in arb.entries)
            if (!key.startsWith('@') &&
                value is String &&
                value.trim().isNotEmpty &&
                !value.contains('{') &&
                !known.contains(value))
              key,
        ];
        expect(missing, isEmpty, reason: '$lang: run scripts/export_phrases.py');
      }
    });
  });

  group('Settings → Voice', () {
    testWidgets('choose an installed voice, hear a sample, set the speed', (
      tester,
    ) async {
      final speaker = FakeSpeaker()
        ..voices = const [
          Voice(name: 'en-us-x-iol-local', locale: 'en-US', quality: 'high'),
          Voice(name: 'en-ng-x-tfn-local', locale: 'en-NG', quality: 'high'),
        ];
      await pumpApp(tester, speaker);
      await tapLabel(tester, RegExp('^${en.settings}'));
      await tapLabel(tester, RegExp('^${en.voiceTitle}'));
      // Best first: Nigerian English.
      final ng = find.textContaining('English (Nigeria)');
      final us = find.textContaining('English (United States)');
      expect(ng, findsOneWidget);
      expect(
        tester.getTopLeft(ng).dy,
        lessThan(tester.getTopLeft(us).dy),
      );
      await tapLabel(tester, RegExp('^English \\(United States\\)'));
      expect(await VoiceSettings.chosen('en'), 'en-us-x-iol-local');
      expect(speaker.previews.last.$2, en.voiceSample);
      await tapLabel(tester, RegExp('^${en.speed('1.25×')}'));
      expect(await VoiceSettings.rate(), 1.25);
      expect(speaker.rates.last, 1.25);
    });

    testWidgets('Hausa app, no Hausa voice: says so, offers none', (
      tester,
    ) async {
      final speaker = FakeSpeaker()
        ..voices = const [Voice(name: 'en-ng-x-tfn-local', locale: 'en-NG')];
      await pumpApp(tester, speaker, language: 'ha');
      final ha = lookupAppLocalizations(const Locale('ha'));
      await tapLabel(tester, RegExp('^${ha.settings}'));
      await tapLabel(tester, RegExp('^${ha.voiceTitle}'));
      expect(find.text(ha.voiceNone('Hausa')), findsOneWidget);
      // Spoken guidance in English: on by default, turned off here.
      expect(await VoiceSettings.englishGuidance(), isTrue);
      await tapLabel(tester, RegExp('^${RegExp.escape(ha.voiceEnglishGuidance)}'));
      expect(await VoiceSettings.englishGuidance(), isFalse);
      expect(speaker.englishGuidance, isFalse);
    });
  });

  group('help and the tour', () {
    testWidgets('"What can I say?" on any screen lists its choices', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final voice = FakeVoice()
        ..replies.add(['what can I say']);
      voiceInput = (_) => voice;
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker);
      await tapLabel(tester, RegExp('^${en.settings}'));
      speaker.said.clear();
      await tapLabel(tester, en.sayName);
      final said = speaker.said.where(
        (s) => s.startsWith('On this screen you can say:'),
      );
      expect(said, hasLength(1));
      expect(said.first, contains(en.voiceTitle));
      expect(said.first, contains(en.tourOpen));
    });

    testWidgets('after language and age: the tour, spoken; Skip goes on', (
      tester,
    ) async {
      final (_, speaker, _) = await onboarding.start(tester);
      await onboarding.tap(tester, 'Continue');
      await tester.tap(find.bySemanticsLabel(RegExp('^I am 18 or older')));
      await tester.pumpAndSettle();
      expect(find.text(en.tourTitle), findsOneWidget);
      expect(speaker.said, contains('${en.tourTitle}. ${en.tourScript}'));
      await onboarding.tap(tester, en.tourSkip);
      expect(find.text('Who is using Magana?'), findsOneWidget);
      // Back from the next step returns to age, not to the tour.
      await tester.binding.handlePopRoute(); // Android Back
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsOneWidget);
    });

    testWidgets('the tour again from Settings', (tester) async {
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker);
      await tapLabel(tester, RegExp('^${en.settings}'));
      await tapLabel(tester, RegExp('^${en.tourOpen}'));
      expect(speaker.said.last, '${en.tourTitle}. ${en.tourScript}');
      await tapLabel(tester, en.tourContinue);
      expect(find.text(en.settings), findsWidgets);
    });

    test('the tour is about a minute at normal speed', () {
      for (final lang in ['en', 'ha', 'yo', 'ig']) {
        final words = lookupAppLocalizations(
          Locale(lang),
        ).tourScript.split(RegExp(r'\s+')).length;
        // 150–200 words a minute is normal speech.
        expect(words, inInclusiveRange(120, 240), reason: lang);
      }
    });
  });

  group('English guidance when the app language has no voice', () {
    final ha = lookupAppLocalizations(const Locale('ha'));

    test("Magana's own phrases, in English; page text never", () async {
      final g = EnglishGuidance();
      expect(await g.toEnglish('ha', ha.readPage), en.readPage);
      // A phrase with a blank.
      expect(
        await g.toEnglish('ha', ha.languageButtonLabel('Hausa')),
        en.languageButtonLabel('Hausa'),
      );
      // Two phrases joined; a sentence from a page in between is dropped.
      final mixed = await g.toEnglish(
        'ha',
        '${ha.ageTitle} Ruwa yana da muhimmanci. ${ha.tourTitle}',
      );
      expect(mixed, contains(en.ageTitle));
      expect(mixed, contains(en.tourTitle));
      expect(mixed, isNot(contains('Ruwa')));
      expect(await g.toEnglish('ha', 'Ruwa yana da muhimmanci.'), isNull);
    });

    test('told once, then English; off means nothing said', () async {
      final s = FakeSpeaker()
        ..noVoiceFor.add('ha')
        ..englishGuidanceNotice = (lang) => 'Spoken guidance is in English for now.';
      final told = <String>[];
      s.onEnglishGuidance = told.add;
      await s.say(ha.readPage, language: 'ha');
      await s.say(ha.settings, language: 'ha');
      expect(s.said, [
        'Spoken guidance is in English for now. ${en.readPage}',
        en.settings,
      ]);
      expect(told, ['ha']);
      // A Hausa page line is never said in English.
      await s.sayParts([
        const SpeechPart('Ruwa yana da muhimmanci', 'ha', guidance: false),
      ]);
      expect(s.said, hasLength(2));
      // Turned off in Settings → Voice: nothing said.
      s.englishGuidance = false;
      await s.say(ha.readPage, language: 'ha');
      expect(s.said, hasLength(2));
    });

    testWidgets(
      'Hausa app, no Hausa voice, a Hausa page: guidance in English, the page shown',
      (tester) async {
        final speaker = FakeSpeaker()..noVoiceFor.add('ha');
        await tester.runAsync(() => speaker.guidance.load()); // real file reading
        await speaker.setLanguage('ha'); // as main() does at start
        await pumpApp(
          tester,
          speaker,
          language: 'ha',
          body: {
            'tips': <String>[],
            'lines': [
              {'text': 'Ruwa yana da muhimmanci', 'confidence': 0.96, 'top': 40},
            ],
            'warnings': <Object>[],
            'page_language': 'ha',
          },
        );
        await captureToReader(tester, takePhoto: ha.takePhoto);
        await tester.pump(const Duration(seconds: 1));
        expect(
          speaker.said.where((t) => t.contains('Spoken guidance is in English for now')),
          hasLength(1),
          reason: '${speaker.said}',
        );
        expect(speaker.said.where((t) => t.contains('Ruwa yana da')), isEmpty);
        expect(speaker.said, contains(en.noVoiceYet('Hausa')));
        expect(find.text('Ruwa yana da muhimmanci'), findsWidgets);
      },
    );
  });

  test('Bluetooth headsets: the Android permissions the recogniser needs', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.BLUETOOTH_CONNECT'));
    expect(manifest, contains('android.permission.MODIFY_AUDIO_SETTINGS'));
  });
}
