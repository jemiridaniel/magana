import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/platform.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/everyday.dart';
import 'package:app/screens/health_worker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

final en = lookupAppLocalizations(const Locale('en'));

// Ibà-style questions, as relayed by Magana's /triage/questions.
const questions = [
  {
    'id': 'fever',
    'type': 'yes_no',
    'text': 'Do you have a fever, or does your body feel very hot?',
    'message': 'q_fever',
  },
  {
    'id': 'fever_days',
    'type': 'number',
    'ask_if': 'fever',
    'text': 'For how many days have you had the fever?',
    'message': 'q_fever_days',
  },
  {
    'id': 'fits',
    'type': 'yes_no',
    'text': 'Have you had fits, or shaking of the body you could not stop?',
    'message': 'q_fits',
  },
];

class Backend {
  final requests = <http.Request>[];
  int callbackStatus = 503;
  String source = 'iba';
  List<Map<String, Object>> qs = questions;

  bool unreachable = false;

  MockClient get client => MockClient((req) async {
    requests.add(req);
    if (unreachable) throw http.ClientException('no network');
    switch (req.url.path) {
      case '/triage/questions':
        return http.Response(
          jsonEncode({'source': source, 'questions': qs}),
          200,
        );
      case '/triage/assess':
        final a = jsonDecode(req.body) as Map;
        if (a.values.contains('cant_tell')) {
          // What Magana's backend answers when a danger sign is unknown.
          return http.Response(
            jsonEncode({
              'priority': 'urgent',
              'message': 'ask_someone_to_check',
            }),
            200,
          );
        }
        final emergency = a['fits'] == true;
        final urgent =
            a['fever'] == true && (a['fever_days'] as int? ?? 0) >= 2;
        return http.Response(
          jsonEncode({
            'priority': emergency
                ? 'emergency'
                : (urgent ? 'urgent' : 'routine'),
            'message': emergency
                ? 'go_to_clinic_now'
                : (urgent
                      ? 'nurse_call_within_2_hours'
                      : 'nurse_call_working_hours'),
          }),
          200,
        );
      case '/callback':
        return callbackStatus == 200
            ? http.Response(jsonEncode({'code': 'callback_booked'}), 200)
            : http.Response(
                jsonEncode({
                  'detail': {'code': 'callback_unavailable'},
                }),
                503,
              );
    }
    return http.Response('', 404);
  });

  Map body(String path) =>
      jsonDecode(requests.lastWhere((r) => r.url.path == path).body) as Map;
}

Future<(FakeSpeaker, Backend, List<String>)> open(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  Widget? screen,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final dialled = <String>[];
  dial = (n) async => dialled.add(n);
  final backend = Backend();
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
  );
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: backend.client, headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).last)
      .push(
        MaterialPageRoute(builder: (_) => screen ?? const HealthWorkerScreen()),
      );
  await tester.pumpAndSettle();
  return (speaker, backend, dialled);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

const sight = ['bleeding', 'yellow_eyes', 'very_pale', 'dark_urine'];

void main() {
  testWidgets('no nurse desk yet: says so, never promises a call', (
    tester,
  ) async {
    final (speaker, backend, _) = await open(tester);
    await tap(tester, RegExp('^Understanding my results'));
    await tap(tester, 'Hausa');
    await tap(tester, en.requestCallback);
    expect(backend.body('/callback'), {'reason': 'results', 'language': 'ha'});
    expect(find.text(en.msg_callback_unavailable), findsOneWidget);
    expect(speaker.said.last, en.msg_callback_unavailable);
  });

  testWidgets('with a nurse desk the call is booked', (tester) async {
    final (_, backend, _) = await open(tester);
    backend.callbackStatus = 200;
    await tap(tester, en.requestCallback);
    expect(find.text(en.msg_callback_booked), findsOneWidget);
  });

  testWidgets(
    'quick check: fever 3 days, urgent, priority goes with the call back',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (speaker, backend, _) = await open(tester);
      expectAccessible(tester, 'Talk to a health worker');
      await tap(tester, en.answerIbaFirst);
      expect(
        find.text(en.quickCheckProgress(1, 2)),
        findsOneWidget,
      ); // fever_days not asked yet
      expect(speaker.said.last, questions[0]['text']);
      expectAccessible(tester, 'Quick check');
      await tap(tester, en.yes);
      expect(
        find.text(en.quickCheckProgress(2, 3)),
        findsOneWidget,
      ); // follow-up appears
      await tap(tester, en.moreDays);
      await tap(tester, en.moreDays);
      expect(find.text(en.daysCount(3)), findsOneWidget);
      await tap(tester, en.nextLabel);
      await tap(tester, en.no);
      expect(backend.body('/triage/assess'), {
        'fever': true,
        'fever_days': 3,
        'fits': false,
      });
      expect(find.text(en.resultUrgent), findsOneWidget);
      expect(
        find.text(en.msg_nurse_call_within_2_hours),
        findsNothing,
      ); // nothing booked yet
      expectAccessible(tester, 'Result');
      await tap(tester, en.requestCallback);
      expect(find.text(en.healthWorkerTitle), findsOneWidget);
      expect(find.bySemanticsLabel(en.answerIbaFirst), findsNothing);
      await tap(tester, en.requestCallback);
      expect(backend.body('/callback')['priority'], 'urgent');
      handle.dispose();
    },
  );

  testWidgets('no fever: the days question is skipped', (tester) async {
    final (_, backend, _) = await open(
      tester,
      screen: const QuickCheckScreen(),
    );
    await tap(tester, en.no);
    expect(find.text(en.quickCheckProgress(2, 2)), findsOneWidget);
    await tap(tester, en.no);
    expect(backend.body('/triage/assess'), {'fever': false, 'fits': false});
  });

  testWidgets('danger sign: go to a clinic now, and Call 112 dials 112', (
    tester,
  ) async {
    final (speaker, _, dialled) = await open(
      tester,
      screen: const QuickCheckScreen(),
    );
    await tap(tester, en.no);
    await tap(tester, en.yes);
    expect(find.text(en.msg_go_to_clinic_now), findsOneWidget);
    expect(speaker.said.last, en.msg_go_to_clinic_now);
    expect(find.bySemanticsLabel(en.requestCallback), findsNothing);
    await tap(tester, en.call112);
    expect(dialled, ['112']);
  });

  testWidgets('the 112 banner is on every health screen and dials 112', (
    tester,
  ) async {
    for (final screen in [
      const HealthWorkerScreen(),
      const QuickCheckScreen(),
      const EverydayScreen(),
    ]) {
      final (_, _, dialled) = await open(tester, screen: screen);
      final banner = find.bySemanticsLabel(
        '${en.emergencyBold} ${en.emergencyText}',
      );
      expect(banner, findsOneWidget, reason: '$screen');
      await tap(tester, '${en.emergencyBold} ${en.emergencyText}');
      expect(dialled, ['112'], reason: '$screen');
    }
  });

  testWidgets('under 18: refused', (tester) async {
    await open(tester, tier: Tier.guided);
    expect(find.text(en.adultsOnly), findsOneWidget);
    expect(find.bySemanticsLabel(en.requestCallback), findsNothing);
  });

  testWidgets(
    'Iba down: built-in questions, labelled honestly, buttons stay on screen',
    (tester) async {
      final (_, backend, _) = await open(tester, screen: const SizedBox());
      backend.source = 'fallback';
      backend.qs = [
        for (final id in [
          'fits',
          'cannot_drink',
          'vomits_everything',
          'very_sleepy',
          'bleeding',
          'yellow_eyes',
          'hard_breathing',
          'very_pale',
          'dark_urine',
          'too_weak',
        ])
          {
            'id': id,
            'type': 'yes_no',
            'message': sight.contains(id) ? 'q_${id}_no_sight' : 'q_$id',
            'cant_tell': true,
            'danger_sign': true,
          },
      ];
      tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .push(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
      await tester.pumpAndSettle();
      expect(find.text(en.quickCheckProgressFallback(1, 10)), findsOneWidget);
      expect(
        find.text(en.msg_q_fits),
        findsOneWidget,
      ); // worded by the app from the code
      void expectOnScreen(List<String> labels, int question) {
        // Answers are pinned below the scrolling question, above the banner.
        final screen = tester.getRect(find.byType(Scaffold).last);
        final scroll = tester.getRect(find.byType(Scrollable).last);
        for (final label in labels) {
          final r = tester.getRect(find.bySemanticsLabel(label));
          expect(
            r.left >= screen.left &&
                r.top >= screen.top &&
                r.right <= screen.right &&
                r.bottom <= screen.bottom &&
                r.top >= scroll.bottom,
            isTrue,
            reason: '$label is off screen at question $question',
          );
        }
      }

      for (var i = 1; i <= 10; i++) {
        expectOnScreen([en.yes, en.no, en.cantTell], i);
        if (i == 10) break;
        await tester.tap(find.bySemanticsLabel(en.no));
        await tester.pumpAndSettle();
      }
      expect(find.text(en.quickCheckProgressFallback(10, 10)), findsOneWidget);
    },
  );

  testWidgets(
    'a danger sign you cannot tell: never a no, ask someone to check',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (speaker, backend, _) = await open(
        tester,
        screen: const SizedBox(),
      );
      backend.qs = [
        {
          'id': 'very_pale',
          'type': 'yes_no',
          'message': 'q_very_pale_no_sight',
          'cant_tell': true,
          'danger_sign': true,
        },
      ];
      tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .push(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
      await tester.pumpAndSettle();
      expect(find.text(en.msg_q_very_pale_no_sight), findsOneWidget);
      expect(speaker.said.last, en.msg_q_very_pale_no_sight);
      expectAccessible(tester, 'Sight-based question');
      await tap(tester, en.cantTell);
      expect(backend.body('/triage/assess'), {'very_pale': 'cant_tell'});
      final result = '${en.msg_ask_someone_to_check} ${en.resultUrgent}';
      expect(find.text(result), findsOneWidget);
      expect(speaker.said.last, result);
      handle.dispose();
    },
  );

  testWidgets('"I can\'t tell" is offered for the number of fever days too', (
    tester,
  ) async {
    final (_, backend, _) = await open(tester, screen: const SizedBox());
    tester
        .state<NavigatorState>(find.byType(Navigator).last)
        .push(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
    await tester.pumpAndSettle();
    await tap(tester, en.yes); // fever
    expect(find.text(en.daysCount(1)), findsOneWidget);
    await tap(tester, en.cantTell);
    await tap(tester, en.no); // fits
    expect(backend.body('/triage/assess'), {
      'fever': true,
      'fever_days': 'cant_tell',
      'fits': false,
    });
  });

  testWidgets('server unreachable: the quick check says so out loud', (
    tester,
  ) async {
    final (speaker, backend, _) = await open(tester, screen: const SizedBox());
    backend.unreachable = true;
    tester
        .state<NavigatorState>(find.byType(Navigator).last)
        .push(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
    await tester.pumpAndSettle();
    expect(find.text(en.cannotReach), findsOneWidget);
    expect(speaker.said.last, en.cannotReach);
  });

  testWidgets(
    'web app, browser online, server down: "Magana\'s server is sleeping", shown and said',
    (tester) async {
      runningOnWeb = true;
      browserIsOnline = () => true;
      addTearDown(() {
        runningOnWeb = false;
        browserIsOnline = () => false;
      });
      final (speaker, backend, _) = await open(
        tester,
        screen: const SizedBox(),
      );
      backend.unreachable = true;
      tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .push(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
      await tester.pumpAndSettle();
      expect(find.text(en.serverSleeping), findsOneWidget);
      expect(speaker.said.last, en.serverSleeping);
      expectAccessible(tester, 'Quick check, server sleeping');
    },
  );

  test(
    '503 from the proxy means the server is asleep, on phones too',
    () async {
      final api = MaganaApi(
        client: MockClient(
          (_) async => http.Response('<html>Bad gateway</html>', 503),
        ),
      );
      await expectLater(
        api.triageQuestions('en'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'server_sleeping'),
        ),
      );
    },
  );
}
