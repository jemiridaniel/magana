import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/capture.dart';
import 'package:app/screens/everyday.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, readJson;

final en = lookupAppLocalizations(const Locale('en'));

Future<(FakeSpeaker, List<String>)> start(
  WidgetTester tester,
  Tier tier,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
    teacherSession: true,
  );
  final speaker = FakeSpeaker();
  final bodies = <String>[];
  final api = MaganaApi(
    headers: () => profile.headers,
    client: MockClient((req) async {
      bodies.add(utf8.decode(req.bodyBytes, allowMalformed: true));
      return http.Response(jsonEncode(readJson), 200);
    }),
  );
  await tester.pumpWidget(
    MaganaApp(
      api: api,
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  return (speaker, bodies);
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

/// Captures through the fake picker from whatever Capture screen is open.
Future<void> takePhoto(WidgetTester tester) async {
  final capture = tester.widget<CaptureScreen>(find.byType(CaptureScreen));
  final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
  nav.pushReplacement(
    MaterialPageRoute(
      builder: (_) => CaptureScreen(
        paper: capture.paper,
        findCameras: () async => [],
        picker: (_) async => XFile.fromData(utf8.encode('png'), name: 'p.png'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tap(tester, 'Take photo');
}

String mode(String multipart) =>
    RegExp(r'name="mode"\r\n\r\n(\w+)').firstMatch(multipart)!.group(1)!;

void main() {
  testWidgets(
    'medicine label: health mode, read exactly as printed, ask a pharmacist',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (speaker, bodies) = await start(tester, Tier.standard);
      // Built now, so TalkBack must not call the tile "Coming soon".
      expect(
        tester.getSemantics(find.bySemanticsLabel('Everyday papers')).hint,
        isEmpty,
      );
      await tap(tester, RegExp('^Everyday papers'));
      expect(find.text(en.everydaySubtitle), findsOneWidget);
      expectAccessible(tester, 'Everyday hub');
      await tap(tester, RegExp('^Medicine label'));
      expect(find.text('Medicine label'), findsOneWidget); // capture title
      await takePhoto(tester);

      expect(mode(bodies.single), 'health');
      expect(find.text('Medicine label'), findsOneWidget);
      expect(find.textContaining(en.readExactly), findsOneWidget);
      expect(find.text(en.noteMedicine), findsOneWidget);
      expect(speaker.said.last, contains(en.noteMedicine));
      expectAccessible(tester, 'Medicine reader');
      await tap(tester, en.askPharmacistOrNurse);
      expect(find.text(en.healthWorkerTitle), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('medical report: health mode with the results note', (
    tester,
  ) async {
    final (_, bodies) = await start(tester, Tier.standard);
    await tap(tester, RegExp('^Everyday papers'));
    await tap(tester, RegExp('^Medical report'));
    await takePhoto(tester);
    expect(mode(bodies.single), 'health');
    expect(find.text(en.noteReport), findsOneWidget);
    expect(find.bySemanticsLabel(en.askPharmacistOrNurse), findsOneWidget);
  });

  testWidgets('bank statement: money mode, PIN note, no health button', (
    tester,
  ) async {
    final (_, bodies) = await start(tester, Tier.standard);
    await tap(tester, RegExp('^Everyday papers'));
    await tap(tester, RegExp('^Bank statement'));
    await takePhoto(tester);
    expect(mode(bodies.single), 'money');
    expect(find.text(en.noteStatement), findsOneWidget);
    expect(find.bySemanticsLabel(en.askPharmacistOrNurse), findsNothing);
  });

  testWidgets(
    'under 18: no Everyday papers, and the screen refuses if reached',
    (tester) async {
      await start(tester, Tier.guided);
      expect(find.bySemanticsLabel(RegExp('^Everyday papers')), findsNothing);
      tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .push(MaterialPageRoute(builder: (_) => const EverydayScreen()));
      await tester.pumpAndSettle();
      expect(find.text(en.adultsOnly), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Medicine label')), findsNothing);
    },
  );

  testWidgets('schoolwork reading is unchanged: school mode, no paper note', (
    tester,
  ) async {
    final (_, bodies) = await start(tester, Tier.standard);
    tester
        .state<NavigatorState>(find.byType(Navigator).last)
        .push(
          MaterialPageRoute(
            builder: (_) => CaptureScreen(
              findCameras: () async => [],
              picker: (_) async =>
                  XFile.fromData(utf8.encode('png'), name: 'p.png'),
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tap(tester, 'Take photo');
    expect(mode(bodies.single), 'school');
    expect(find.text(en.yourPage), findsOneWidget);
    expect(find.text(en.noteMedicine), findsNothing);
  });
}
