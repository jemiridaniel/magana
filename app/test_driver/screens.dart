// Development only, never shipped: opens one screen with sample data, for screenshots on
// simulators and emulators against the design boards (10, 10b, T1, T2).
//
//   flutter run -t test_driver/screens.dart -d <device>
//
// It steps through [shots], printing "SHOT <name>" when each is on screen.
import 'dart:convert';

import 'package:app/api.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/everyday.dart';
import 'package:app/screens/reader.dart';
import 'package:app/screens/touch_intro.dart';
import 'package:app/speech.dart';
import 'package:app/touch.dart';
import 'package:app/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A sample page (the board's Social Studies page), read with one unclear number.
const sample = {
  'tips': <String>[],
  'lines': [
    {
      'text': 'The rainy season in Nigeria',
      'confidence': 0.97,
      'top': 40,
      'label': 'line 1',
    },
    {
      'text': 'usually starts in April in the',
      'confidence': 0.96,
      'top': 90,
      'label': 'line 2',
    },
    {
      'text': 'south and in June in the north.',
      'confidence': 0.95,
      'top': 140,
      'label': 'line 3',
    },
    {
      'text': 'Farmers plant maize, yam and',
      'confidence': 0.96,
      'top': 190,
      'label': 'line 4',
    },
    {
      'text': 'cassava at the start of the rains.',
      'confidence': 0.95,
      'top': 240,
      'label': 'line 5',
    },
    {
      'text': 'Rain falls on about 150 days a year.',
      'confidence': 0.6,
      'top': 290,
      'label': 'line 6',
    },
  ],
  'warnings': [
    {'block_index': 5, 'code': 'low_confidence'},
  ],
};

/// Each shot: its name, the orientation, and the screen to open over Home (null: Home).
final shots = <(String, String, Widget? Function())>[
  ('T1-home-portrait', 'portrait', () => null),
  ('10-touch-portrait', 'portrait', () => const EverydayScreen()),
  (
    '10b-intro-portrait',
    'portrait',
    () => TouchIntroScreen(onDone: (c) => Navigator.of(c).pop()),
  ),
  ('everyday-end-portrait', 'portrait', () => const EverydayScreen()),
  (
    'T2-reader-landscape',
    'landscape',
    () => ReaderScreen(result: ReadResult.fromJson(sample)),
  ),
  (
    'reader-portrait',
    'portrait',
    () => ReaderScreen(result: ReadResult.fromJson(sample)),
  ),
  ('home-landscape', 'landscape', () => null),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final touch = TouchToHear(on: true);
  final app = MaganaApp(
    api: MaganaApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(sample),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
    speaker: Speaker(),
    language: LanguageController(const Locale('en')),
    profile: ProfileController(tier: Tier.standard, who: 'finished'),
    touch: touch,
  );
  runApp(app);
  await Future<void>.delayed(const Duration(seconds: 3));
  final nav = navigatorOf(WidgetsBinding.instance.rootElement!)!;
  for (final (name, turn, open) in shots) {
    nav.popUntil((r) => r.isFirst);
    touch.focused.value = null;
    touch.caption.value = null;
    await SystemChrome.setPreferredOrientations(
      turn == 'landscape'
          ? [DeviceOrientation.landscapeLeft]
          : [DeviceOrientation.portraitUp],
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final screen = open();
    if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (name.startsWith('10-touch')) _touch(touch, nav, 'Medicine label');
    if (name.startsWith('everyday-end')) _touch(touch, nav, 'Talk to a nurse');
    await Future<void>.delayed(const Duration(seconds: 2));
    debugPrint('SHOT $name');
    await Future<void>.delayed(const Duration(seconds: 4));
  }
  debugPrint('SHOTS DONE');
}

/// Touch to hear on [label]: outlined, scrolled fully into view, said at the foot (board 10).
void _touch(TouchToHear touch, NavigatorState nav, String label) {
  Element? card;
  void visit(Element e) {
    if (card != null) return;
    if (e.widget is Labelled &&
        (e.widget as Labelled).label.startsWith(label)) {
      card = e;
      return;
    }
    e.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  final target = touch
      .choicesOf(ModalRoute.of(card!))
      .firstWhere((t) => t.label.startsWith(label));
  touch.focus(nav.context, target);
}

NavigatorState? navigatorOf(Element root) {
  NavigatorState? found;
  void visit(Element e) {
    if (found != null) return;
    if (e is StatefulElement && e.state is NavigatorState) {
      found = e.state as NavigatorState;
      return;
    }
    e.visitChildren(visit);
  }

  visit(root);
  return found;
}
