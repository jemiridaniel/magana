// Accounts on the phone (boards A1–A5): joining a class with its 6-digit code,
// the confirmation, waiting for consent, a teacher's code to change class
// (checked by the backend, 3 wrong tries then 5 minutes), removal, goals.
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

const _class = {
  'name': 'SS2 Science',
  'level': 'sss2',
  'teacher': 'Mrs Folake Adebayo',
  'school': 'Surulere Grammar School',
};

/// A stand-in for backend/app/learner_api.py.
class FakeLearnerApi {
  final sent = <http.Request>[];
  String status = 'waiting_consent';
  int wrongTeacher = 0;

  MockClient get client => MockClient((req) async {
    sent.add(req);
    final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body);
    http.Response fail(int code, String c) => http.Response(
      jsonEncode({
        'detail': {'code': c},
      }),
      code,
    );
    switch (req.url.path) {
      case '/learner/join':
        if (body['class_code'] != '481736') {
          return fail(400, 'class_code_wrong');
        }
        final under18 = req.headers['X-Magana-Tier'] == 'guided';
        status = under18 ? 'waiting_consent' : 'active';
        return http.Response(
          jsonEncode({
            'code': 'class_joined',
            'token': 'tok-1',
            'status': status,
            'class': _class,
          }),
          200,
        );
      case '/learner/me':
        return http.Response(
          jsonEncode({'status': status, 'class': _class}),
          200,
        );
      case '/learner/change-class':
        if (wrongTeacher >= 3) return fail(429, 'code_locked');
        if (body['teacher_code'] != '907152') {
          wrongTeacher++;
          return fail(403, 'teacher_code_wrong');
        }
        return http.Response(
          jsonEncode({
            'code': 'class_changed',
            'status': 'active',
            'class': {..._class, 'name': 'SS2 Arts'},
          }),
          200,
        );
    }
    return http.Response(
      jsonEncode({'tips': [], 'lines': [], 'warnings': []}),
      200,
    );
  });
}

Future<(ProfileController, FakeSpeaker, FakeLearnerApi)> start(
  WidgetTester tester, {
  ProfileController? profile,
  FakeLearnerApi? backend,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final p = profile ?? ProfileController();
  final speaker = FakeSpeaker();
  final b = backend ?? FakeLearnerApi();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(headers: () => p.headers, client: b.client),
      speaker: speaker,
      language: LanguageController(),
      profile: p,
    ),
  );
  await tester.pumpAndSettle();
  return (p, speaker, b);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  final f = find.bySemanticsLabel(label).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tap(tester, d);
  }
}

ClassLink link(String status) => ClassLink(
  token: 'tok-1',
  status: status,
  className: 'SS2 Science',
  level: 'sss2',
  teacher: 'Mrs Folake Adebayo',
  school: 'Surulere Grammar School',
);

void main() {
  testWidgets('13–17 in school: class code by keypad, A3, then waiting', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (profile, speaker, backend) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am 13 to 17'));
    await tap(tester, RegExp('^I’m in school'));
    expectAccessible(tester, 'Join your class');

    await tap(tester, 'Join class');
    expect(speaker.said.last, 'Type all 6 digits first.');
    await type(tester, '4817');
    expect(speaker.said.last, 'You typed 4, 8, 1, 7. 2 more.');
    expect(
      find.bySemanticsLabel(RegExp(r'^Class code: 4, 8, 1, 7, 4 of 6 digits')),
      findsOneWidget,
    );
    await tap(tester, 'Delete');
    await type(tester, '736');
    await tap(tester, 'Read back');
    expect(speaker.said.last, 'All 6 digits: 4, 8, 1, 7, 3, 6.');
    await tap(tester, 'Join class');
    expect(backend.sent.last.headers['X-Magana-Tier'], 'guided');

    // A3: the class, teacher and school, and that consent is still pending.
    expect(find.text('You’re in!'), findsOneWidget);
    expect(find.textContaining('SS2 Science'), findsWidgets);
    expect(find.textContaining('Mrs Folake Adebayo'), findsWidgets);
    expect(find.textContaining('Waiting for your parent'), findsWidgets);
    expectAccessible(tester, 'Joined');
    await tap(tester, 'Start reading');

    expect((profile.tier, profile.who), (Tier.guided, 'in_school'));
    expect(profile.waitingForConsent, isTrue);
    expect(profile.classLevel, 'sss2');
    expect(profile.headers['X-Magana-Learner'], 'tok-1');
    expect(profile.headers.containsKey('X-Magana-Guardian-Consent'), isFalse);
    expect(profile.can(Feature.quiz), isFalse);
    expect(profile.can(Feature.readSchoolwork), isTrue);
    expectAccessible(tester, 'Home, waiting');
    handle.dispose();
  });

  testWidgets('a wrong class code is said, and nothing is saved', (
    tester,
  ) async {
    final (profile, speaker, _) = await start(tester);
    await tap(tester, 'Continue');
    await tap(tester, RegExp('^I am 18 or older'));
    await tap(tester, RegExp('^I’m in school'));
    await type(tester, '111222');
    await tap(tester, 'Join class');
    expect(find.text('Join your class'), findsOneWidget);
    expect(speaker.said.last, isNot(contains('6 digits')));
    expect((profile.tier, profile.link), (null, null));
  });

  testWidgets('the teacher records consent: the app learns it on start', (
    tester,
  ) async {
    final backend = FakeLearnerApi()..status = 'active';
    final (profile, _, _) = await start(
      tester,
      profile: ProfileController(
        tier: Tier.guided,
        classLevel: 'sss2',
        link: link('waiting_consent'),
      ),
      backend: backend,
    );
    expect(profile.guardianConsent, isTrue);
    expect(profile.can(Feature.quiz), isTrue);
    expect(find.textContaining('Waiting for your parent'), findsNothing);
  });

  testWidgets('removed from the class: unlinked, a note on Home', (
    tester,
  ) async {
    final backend = FakeLearnerApi()..status = 'removed';
    final (profile, _, _) = await start(
      tester,
      profile: ProfileController(
        tier: Tier.standard,
        classLevel: 'sss2',
        link: link('active'),
      ),
      backend: backend,
    );
    expect(profile.link, isNull);
    expect(profile.headers.containsKey('X-Magana-Learner'), isFalse);
    expect(
      find.text(
        'Your teacher removed this phone from the class. You can still read pages.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an under-18 changes class only with the teacher’s code', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final backend = FakeLearnerApi()..status = 'active';
    final (profile, speaker, _) = await start(
      tester,
      profile: ProfileController(
        tier: Tier.guided,
        consentAt: DateTime(2026),
        classLevel: 'sss2',
        link: link('active'),
      ),
      backend: backend,
    );
    await tap(tester, RegExp('^Settings'));
    expect(find.bySemanticsLabel(RegExp("I'm a teacher")), findsNothing);
    await tap(tester, RegExp('^My class. SS2 Science'));
    expect(find.text('Your teacher needs to do this'), findsOneWidget);
    expectAccessible(tester, 'Teacher code');

    // Wrong teacher code: back to the teacher's part; the 3rd time locks.
    for (var i = 0; i < 3; i++) {
      await type(tester, '123456');
      await tap(tester, 'Confirm');
      await type(tester, '481736');
      await tap(tester, 'Confirm');
      expect(find.text('Your teacher needs to do this'), findsOneWidget);
    }
    await type(tester, '907152');
    await tap(tester, 'Confirm');
    await type(tester, '481736');
    await tap(tester, 'Confirm');
    expect(backend.wrongTeacher, 3);
    expect(profile.link!.className, 'SS2 Science'); // locked: unchanged

    backend.wrongTeacher = 0; // five minutes later
    await type(tester, '907152');
    await tap(tester, 'Confirm');
    expect(speaker.said.last, 'Now the new class’s code');
    await type(tester, '481736');
    await tap(tester, 'Confirm');
    expect(profile.link!.className, 'SS2 Arts');
    expect(profile.link!.token, 'tok-1');
    expect(jsonDecode(backend.sent.last.body), {
      'teacher_code': '907152',
      'class_code': '481736',
    });
    handle.dispose();
  });

  testWidgets('adults who finished school change their goals in Settings', (
    tester,
  ) async {
    final profile = ProfileController(
      tier: Tier.standard,
      classLevel: ProfileController.notInSchool,
    );
    await start(tester, profile: profile);
    await profile.setWho('finished');
    await profile.setGoals(['reading']);
    await tap(tester, RegExp('^Settings'));
    await tap(tester, RegExp('^My goals. Practise reading'));
    await tap(tester, RegExp('^Prepare for WAEC'));
    await tap(tester, 'Save');
    expect(profile.goals, ['reading', 'waec']);
    expect(profile.classLevel, 'sss3');
    expect(
      find.bySemanticsLabel(
        RegExp('^My goals. Practise reading, Prepare for WAEC'),
      ),
      findsOneWidget,
    );
  });
}
