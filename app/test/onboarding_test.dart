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
  await tester.ensureVisible(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
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

  testWidgets('18+ university or other: no class, everything on Home', (
    tester,
  ) async {
    final (profile, _, _) = await start(tester);
    await tap(tester, 'Continue');
    expect(find.text('How old are you?'), findsOneWidget);
    await tap(tester, RegExp('^I am 18 or older'));
    expect(find.text('Who is using Magana?'), findsOneWidget);
    await tap(tester, RegExp('^University or other'));
    await tap(tester, 'Start');
    expect(profile.tier, Tier.standard);
    expect(profile.who, 'other');
    expect(profile.classLevel, ProfileController.notInSchool);
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

  testWidgets('18+ finished school: goals, JAMB practice at SS3 level', (
    tester,
  ) async {
    final (profile, _, _) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am 18 or older'));
    await tap(tester, RegExp('^I’ve finished school'));
    expect(find.text('What would you like to do?'), findsOneWidget);
    await tap(tester, RegExp('^Prepare for JAMB'));
    await tap(tester, RegExp('^Just read my papers'));
    await tap(tester, 'Save');
    await tap(tester, 'Start');
    expect((profile.tier, profile.who), (Tier.standard, 'finished'));
    expect(profile.goals, ['jamb', 'papers']);
    expect(profile.classLevel, 'sss3');
  });

  testWidgets('13–17 without a class code: waiting, schoolwork reading only', (
    tester,
  ) async {
    final (profile, _, _) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am 13 to 17'));
    await tap(tester, RegExp('^I’m in school'));
    expect(find.text('Join your class'), findsOneWidget);
    await tap(tester, 'I don’t have a code yet');
    expect(find.text('Which class are you in?'), findsOneWidget);
    // Learners aged 13 to 17 are in school: no "not in school" choice.
    expect(find.bySemanticsLabel("I'm not in school"), findsNothing);
    await tap(tester, 'SSS 2');
    expect((profile.tier, profile.guardianConsent), (Tier.guided, false));
    expect(profile.waitingForConsent, isTrue);
    expect(profile.level?.name, 'SSS 2');
    expect(
      find.text(
        'Waiting for your parent or guardian to agree. Until then you can read pages.',
      ),
      findsOneWidget,
    );
    expect(homeTiles(tester), isEmpty); // reading pages only
    expect(profile.headers, {'X-Magana-Tier': 'guided'});
  });

  testWidgets('under 13: only a teacher-started session, never saved', (
    tester,
  ) async {
    final (profile, speaker, _) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am under 13'));
    // The teacher chooses the class for the session first.
    await tap(tester, 'Teacher: start the class session');
    expect(find.text('Are you the teacher?'), findsNothing);
    expect(speaker.said.last, 'Choose the class first.');
    await tap(tester, 'Primary 5 (Basic 5)');
    await tap(tester, 'Teacher: start the class session');
    expect(find.text('Are you the teacher?'), findsOneWidget);
    await tap(tester, 'Yes, start the session');
    expect((profile.tier, profile.teacherSession), (Tier.classroom, true));
    expect(profile.classLevel, 'p5');
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
    expect(relaunch.classLevel, isNull); // the session's class isn't kept
  });

  testWidgets('a returning Classroom user sees only the class screen', (
    tester,
  ) async {
    await start(tester, profile: ProfileController(tier: Tier.classroom));
    expect(find.text('Magana in class'), findsOneWidget);
    expect(find.textContaining('Step 3 of'), findsNothing);
    expect(homeTiles(tester), isEmpty);
  });

  testWidgets('a Guided profile without consent waits on Home', (tester) async {
    await start(tester, profile: ProfileController(tier: Tier.guided));
    expect(find.textContaining('Waiting for your parent'), findsOneWidget);
    expect(homeTiles(tester), isEmpty);
  });

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
    expectAccessible(tester, 'Who is using Magana');
    await tap(tester, RegExp('^I’m in school'));
    expectAccessible(tester, 'Join your class');
    await tap(tester, 'I don’t have a code yet');
    expectAccessible(tester, 'Class');
    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, RegExp('^I’ve finished school'));
    expectAccessible(tester, 'Goals');
    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, RegExp('^I am under 13'));
    expectAccessible(tester, 'Classroom');
    await tap(tester, 'Back');
    await tap(tester, RegExp('^I am 18 or older'));
    await tap(tester, RegExp('^University or other'));
    expectAccessible(tester, 'Ready');
    handle.dispose();
  });
}
