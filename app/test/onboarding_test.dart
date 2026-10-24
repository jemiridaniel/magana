import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

Future<(ProfileController, FakeSpeaker, List<http.BaseRequest>)> start(
  WidgetTester tester, {
  ProfileController? profile,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final p = profile ?? ProfileController();
  final speaker = FakeSpeaker();
  final sent = <http.BaseRequest>[];
  final api = MaganaApi(
    headers: () => p.headers,
    client: MockClient((req) async {
      sent.add(req);
      return http.Response(
        jsonEncode({'tips': [], 'lines': [], 'warnings': []}),
        200,
      );
    }),
  );
  await tester.pumpWidget(
    MaganaApp(
      api: api,
      speaker: speaker,
      language: LanguageController(),
      profile: p,
    ),
  );
  await tester.pumpAndSettle();
  return (p, speaker, sent);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

Set<String> homeTiles(WidgetTester tester) => {
  for (final label in [
    'Ask a question',
    'Practice quiz',
    'My library',
    'Everyday papers',
    'Skills',
    'My score',
  ])
    if (find.bySemanticsLabel(RegExp('^$label')).evaluate().isNotEmpty) label,
};

void main() {
  testWidgets('language step speaks each option in its own language', (
    tester,
  ) async {
    final (_, speaker, _) = await start(tester);
    expect(find.text('Choose your language'), findsOneWidget);
    await tap(tester, 'Hausa');
    expect(speaker.said.last, 'Hausa. Barka da zuwa');
    expect(speaker.language, 'ha');
    expect(
      find.text('Zaɓi harshenka'),
      findsOneWidget,
    ); // the screen switched to Hausa
    await tap(tester, 'Yorùbá');
    expect(speaker.said.last, 'Yorùbá. Ẹ káàbọ̀');
    await tap(tester, 'English');
  });

  testWidgets('18+: language, age, ready, then everything on Home', (
    tester,
  ) async {
    final (profile, _, _) = await start(tester);
    await tap(tester, 'Continue');
    expect(find.text('How old are you?'), findsOneWidget);
    await tap(tester, RegExp('^I am 18 or older'));
    await tap(tester, 'Start');
    expect(profile.tier, Tier.standard);
    expect(
      (await SharedPreferences.getInstance()).getString('age_tier'),
      'standard',
    );
    expect(homeTiles(tester), {
      'Ask a question',
      'Practice quiz',
      'My library',
      'Everyday papers',
      'Skills',
      'My score',
    });
  });

  testWidgets('13–17: guardian consent first, then school features only', (
    tester,
  ) async {
    final (profile, _, _) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am 13 to 17'));
    expect(find.text('Ask a parent, guardian or teacher'), findsOneWidget);
    expect(profile.tier, isNull); // nothing until the guardian agrees
    await tap(tester, 'I am the parent, guardian or teacher, and I agree');
    expect((profile.tier, profile.guardianConsent), (Tier.guided, true));
    expect(homeTiles(tester), {
      'Practice quiz',
      'My library',
      'Skills',
      'My score',
    });
    expect(profile.headers, {
      'X-Magana-Tier': 'guided',
      'X-Magana-Guardian-Consent': 'yes',
    });
  });

  testWidgets('under 13: only a teacher-started session, never saved', (
    tester,
  ) async {
    final (profile, _, _) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am under 13'));
    await tap(tester, 'Teacher: start the class session');
    expect(find.text('Are you the teacher?'), findsOneWidget);
    await tap(tester, 'Yes, start the session');
    expect((profile.tier, profile.teacherSession), (Tier.classroom, true));
    expect(homeTiles(tester), {'Practice quiz'});
    expect(profile.headers, {
      'X-Magana-Tier': 'classroom',
      'X-Magana-Teacher-Session': 'yes',
    });

    // Next launch: the tier is remembered, the session is not.
    final relaunch = ProfileController();
    await relaunch.load();
    expect(
      (relaunch.tier, relaunch.teacherSession, relaunch.active),
      (Tier.classroom, false, false),
    );
  });

  testWidgets('a returning Classroom user sees only the class screen', (
    tester,
  ) async {
    await start(tester, profile: ProfileController(tier: Tier.classroom));
    expect(find.text('Magana in class'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsNothing);
    expect(homeTiles(tester), isEmpty);
  });

  testWidgets(
    'a Guided profile without consent goes back to the consent step',
    (tester) async {
      await start(tester, profile: ProfileController(tier: Tier.guided));
      expect(find.text('Ask a parent, guardian or teacher'), findsOneWidget);
    },
  );

  test('the app tiers mirror the backend policy', () {
    expect(allows(Tier.guided, Feature.everydayHealth), isFalse);
    expect(allows(Tier.guided, Feature.healthCallback), isFalse);
    expect(allows(Tier.guided, Feature.openChat), isFalse);
    expect(allows(Tier.classroom, Feature.skills), isFalse);
    expect(allows(Tier.standard, Feature.everydayMoney), isTrue);
    for (final f in [Feature.readSchoolwork, Feature.quiz]) {
      expect(Tier.values.every((t) => allows(t, f)), isTrue);
    }
  });

  testWidgets('every request carries the tier headers', (tester) async {
    final (_, _, sent) = await start(
      tester,
      profile: ProfileController(tier: Tier.guided, consentAt: DateTime(2026)),
    );
    final api = MaganaApi(
      headers: () => ProfileController(
        tier: Tier.guided,
        consentAt: DateTime(2026),
      ).headers,
      client: MockClient((req) async {
        sent.add(req);
        return http.Response(
          jsonEncode({'tips': [], 'lines': [], 'warnings': []}),
          200,
        );
      }),
    );
    await api.read(utf8.encode('png'));
    expect(sent.last.headers['X-Magana-Tier'], 'guided');
    expect(sent.last.headers['X-Magana-Guardian-Consent'], 'yes');
  });

  testWidgets('every onboarding screen is accessible', (tester) async {
    final handle = tester.ensureSemantics();
    await start(tester);
    expectAccessible(tester, 'Language');
    await tap(tester, 'Continue');
    expectAccessible(tester, 'Age');
    await tap(tester, RegExp('^I am 13 to 17'));
    expectAccessible(tester, 'Consent');
    await tap(tester, 'Back');
    await tap(tester, RegExp('^I am under 13'));
    expectAccessible(tester, 'Classroom');
    await tap(tester, 'Back');
    await tap(tester, RegExp('^I am 18 or older'));
    expectAccessible(tester, 'Ready');
    handle.dispose();
  });
}
