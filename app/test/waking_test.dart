// The free test-phase server sleeps (docs/INFRA.md): while it wakes, the Worker on api.magana.ng
// answers 503 "server_waking". The app says "Magana is waking up, one moment…" once and waits
// (up to 60 s) instead of failing; a page photo is read on the phone meanwhile.
import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/offline/offline_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response waking() => http.Response(
  jsonEncode({
    'detail': {'code': 'server_waking', 'retry_after': 1},
  }),
  503,
  headers: {'content-type': 'application/json'},
);

void main() {
  final realWait = serverWakeWait;
  tearDown(() {
    onServerWaking = null;
    serverWakeWait = realWait;
  });

  test('waits while the server wakes, says so once, then answers', () async {
    var calls = 0, told = 0;
    onServerWaking = () => told++;
    final api = MaganaApi(
      client: MockClient((req) async {
        calls++;
        return calls < 3
            ? waking()
            : http.Response(jsonEncode({'quizzes': []}), 200);
      }),
    );
    expect(await api.sessionQuizzes('123456'), isEmpty);
    expect(calls, 3);
    expect(told, 1);
  });

  test('gives up after the wait as "server sleeping"', () async {
    serverWakeWait = const Duration(seconds: 2);
    final api = MaganaApi(client: MockClient((req) async => waking()));
    await expectLater(
      api.sessionQuizzes('123456'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'server_sleeping'),
      ),
    );
  });

  test('Magana\'s own errors are never waited on', () async {
    var calls = 0;
    final api = MaganaApi(
      client: MockClient((req) async {
        calls++;
        return http.Response(
          jsonEncode({
            'detail': {'code': 'bad_api_key'},
          }),
          401,
        );
      }),
    );
    await expectLater(
      api.sessionQuizzes('123456'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test(
    'a page photo is read on the phone meanwhile, and the Reader says why',
    () {
      expect(
        OfflineReason.forCode('server_waking', web: false),
        OfflineReason.waking,
      );
    },
  );
}
