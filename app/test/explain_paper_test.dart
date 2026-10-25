import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/explain.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;
import 'quiz_test.dart' show FakeVoice;

final ha = lookupAppLocalizations(const Locale('ha'));

/// Health papers are never explained by a model: each line is read from an
/// approved template, or in English as printed with "please ask a pharmacist".
void main() {
  testWidgets(
    'a medicine label: approved lines translated, the rest in English with the warning',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final sent = <http.Request>[];
      final api = MaganaApi(
        client: MockClient((req) async {
          sent.add(req);
          return http.Response(
            jsonEncode({
              'code': 'paper_lines',
              'explanation': null,
              'read_instead': null,
              'preview': false,
              'fallback': 'cant_translate_line_health',
              'lines': [
                {
                  'source': 'Do not take more than 8 tablets in 24 hours.',
                  'text': 'Kada ka sha fiye da ƙwaya 8 cikin sa\'o\'i 24.',
                  'template': 'not_more_than_in_hours',
                },
                {
                  'source': 'take 1 to 2 tablets every 4 to 6 hours as needed.',
                  'text': null,
                  'template': null,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final speaker = FakeSpeaker();
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaganaApp(
          api: api,
          speaker: speaker,
          language: LanguageController(const Locale('ha')),
          profile: ProfileController(tier: Tier.standard),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Navigator).first)).push(
        MaterialPageRoute(
          builder: (_) => const ExplainScreen(
            lines: ['Do not take more than 8 tablets in 24 hours.'],
            source: 'Medicine label',
            mode: 'health',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final body = jsonDecode(sent.single.body) as Map;
      expect((body['mode'], body['lang']), ('health', 'ha'));
      final said = speaker.said.last;
      expect(said, startsWith(ha.msg_paper_lines));
      expect(said, contains("Kada ka sha fiye da ƙwaya 8 cikin sa'o'i 24."));
      expect(
        said,
        contains(
          'take 1 to 2 tablets every 4 to 6 hours as needed. ${ha.msg_cant_translate_line_health}',
        ),
      );
      expect(
        find.textContaining(ha.msg_cant_translate_line_health),
        findsOneWidget,
      );
      expectAccessible(tester, 'Explain, health paper');
      handle.dispose();
    },
  );

  testWidgets(
    'numbers left out: the explanation, then "the exact numbers are on the page"; read again reads them',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final voice = FakeVoice();
      voiceInput = (_) => voice;
      final api = MaganaApi(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'code': 'explained',
              'explanation': 'A leaf kept in the dark makes no starch.',
              'read_instead': null,
              'preview': false,
              'followup': 'numbers_left_out',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final speaker = FakeSpeaker();
      await tester.pumpWidget(
        MaganaApp(
          api: api,
          speaker: speaker,
          language: LanguageController(),
          profile: ProfileController(tier: Tier.standard),
        ),
      );
      await tester.pumpAndSettle();
      const page =
          'A leaf kept in the dark for 48 hours gave a negative starch test.';
      Navigator.of(tester.element(find.byType(Navigator).first)).push(
        MaterialPageRoute(
          builder: (_) =>
              const ExplainScreen(lines: [page], source: 'Your page'),
        ),
      );
      await tester.pumpAndSettle();
      final en = lookupAppLocalizations(const Locale('en'));
      expect(speaker.said.last, endsWith(en.msg_numbers_left_out));
      expect(find.text(en.msg_numbers_left_out), findsOneWidget);

      await tester.ensureVisible(find.bySemanticsLabel(en.explainReadAgain));
      await tester.tap(find.bySemanticsLabel(en.explainReadAgain));
      await tester.pumpAndSettle();
      expect(speaker.said.last, page);

      speaker.said.clear();
      voice.replies.add(['read again']);
      await tester.tap(find.bySemanticsLabel(en.askAQuestion));
      await tester.pumpAndSettle();
      expect(speaker.said.last, page);
    },
  );
}
