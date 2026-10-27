// Touch to hear (board 10) and its first-run practice (board 10b): with the phone's screen
// reader off, the first touch says a control, a second tap opens it, a sliding finger hears
// each control it crosses. With VoiceOver or TalkBack on, Magana stays out of the way.

import 'package:app/l10n/app_localizations.dart';
import 'package:app/screens/everyday.dart';
import 'package:app/screens/health_worker.dart';
import 'package:app/screens/library.dart';
import 'package:app/screens/touch_intro.dart';
import 'package:app/touch.dart';
import 'package:app/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show FakeSpeaker, pumpApp;

final en = lookupAppLocalizations(const Locale('en'));

Finder control(String label) =>
    find.byWidgetPredicate((w) => w is Labelled && w.label.startsWith(label));

void main() {
  testWidgets('first touch says it, with its place; a second tap opens it', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    final touch = TouchToHear(on: true);
    await pumpApp(tester, speaker, touch: touch);

    await tester.tap(control(en.everydayPapers));
    await tester.pumpAndSettle();
    expect(find.byType(EverydayScreen), findsNothing);
    expect(
      speaker.said.last,
      matches(RegExp(r'^Everyday papers\. \d of 9\. Tap again to open\.$')),
    );
    expect(touch.focused.value?.label, en.everydayPapers);
    // What was said is shown at the foot, for low vision.
    expect(find.text(speaker.said.last), findsOneWidget);

    await tester.tap(control(en.everydayPapers));
    await tester.pumpAndSettle();
    expect(find.byType(EverydayScreen), findsOneWidget);
    // The new screen says what it is: title, choices, how to explore.
    expect(
      speaker.said.last,
      endsWith('9 choices. Touch to explore, or say a name.'),
    );

    // On a list: name, hint (its detail), "3 of 8".
    await tester.tap(control(en.paperMedicine));
    await tester.pumpAndSettle();
    expect(
      speaker.said.last,
      startsWith('${en.paperMedicine}. ${en.paperMedicineDetail}'),
    );
    expect(speaker.said.last, endsWith(' 3 of 9. Tap again to open.'));
  });

  testWidgets(
    'a sliding finger hears each control it crosses; lifting opens nothing',
    (tester) async {
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker, touch: TouchToHear(on: true));
      final quiz = tester.getCenter(control(en.practiceQuiz));
      final library = tester.getCenter(control(en.myLibrary));

      final finger = await tester.startGesture(quiz);
      await tester.pump();
      expect(speaker.said.last, startsWith('${en.practiceQuiz}.'));
      await finger.moveTo(library);
      await tester.pump();
      expect(speaker.said.last, startsWith('${en.myLibrary}.'));
      await finger.up();
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsNothing);

      // A long press says it again.
      final count = speaker.said.length;
      final press = await tester.startGesture(library);
      await tester.pump(const Duration(milliseconds: 700));
      await press.up();
      await tester.pumpAndSettle();
      expect(speaker.said.length, count + 1);
      expect(speaker.said.last, startsWith('${en.myLibrary}.'));
      expect(find.byType(LibraryScreen), findsNothing);
    },
  );

  testWidgets('screen reader on: one tap opens, nothing is said twice', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final data = (message as Map)['data'] as Map;
        if (data['message'] case final String m) announced.add(m);
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker, touch: TouchToHear(on: true));
    expect(speaker.said, isEmpty); // the screen reader reads Home itself

    await tester.tap(control(en.everydayPapers));
    await tester.pumpAndSettle();
    expect(find.byType(EverydayScreen), findsOneWidget);
    // The summary is one short announcement, not the voice as well.
    expect(speaker.said, isEmpty);
    expect(announced, contains('Everyday papers. 9 choices.'));
    expect(find.text(en.touchTapAgain), findsNothing);
  });

  testWidgets('Touch to hear off: one tap opens, no "tap again"', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker, touch: TouchToHear(on: false));
    await tester.tap(control(en.everydayPapers));
    await tester.pumpAndSettle();
    expect(find.byType(EverydayScreen), findsOneWidget);
    expect(speaker.said.any((s) => s.contains(en.touchTapAgain)), isFalse);
  });

  testWidgets('saying a name opens it ("medicine label", "bank statement")', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    final touch = TouchToHear(on: false);
    await pumpApp(tester, speaker, touch: touch);
    await tester.tap(control(en.everydayPapers));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.byType(EverydayScreen)));
    final opened = <String>[];
    for (final t in touch.choicesOf(route)) {
      expect(t.label, isNotEmpty);
    }
    String? match(String heard) => bestMatch(heard, [
      for (final t in touch.choicesOf(route)) t.label,
    ], (s) => s);
    opened.add(match('medicine label')!);
    opened.add(match('read my bank statement please')!);
    expect(opened, [
      startsWith(en.paperMedicine),
      startsWith(en.paperStatement),
    ]);
    expect(match('weather today'), isNull);

    expect(touch.openByName(route, 'medicine label'), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(EverydayScreen), findsNothing); // Capture opened
  });

  testWidgets('the Everyday list scrolls until its last card is fully in view', (
    tester,
  ) async {
    Future<void> openEveryday() async {
      await tester.ensureVisible(control(en.everydayPapers));
      await tester.pumpAndSettle();
      await tester.tap(control(en.everydayPapers));
      await tester.pumpAndSettle();
      if (find.byType(EverydayScreen).evaluate().isEmpty) {
        await tester.tap(control(en.everydayPapers)); // Touch to hear: again
        await tester.pumpAndSettle();
      }
    }

    // By dragging: the last card and the banner under it come fully into view.
    await pumpApp(tester, FakeSpeaker(), size: const Size(390, 700));
    await openEveryday();
    final scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -3000));
    await tester.pumpAndSettle();
    var view = tester.getRect(scroll);
    expect(
      tester.getRect(find.byType(EmergencyBanner)).bottom,
      lessThanOrEqualTo(view.bottom),
    );
    final nurse = tester.getRect(control(en.talkToNurse));
    expect(nurse.top, greaterThanOrEqualTo(view.top));
    expect(nurse.bottom, lessThanOrEqualTo(view.bottom));

    // By touch (Touch to hear): a card cut off at the bottom scrolls fully into view.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(
      tester,
      FakeSpeaker(),
      size: const Size(390, 700),
      touch: TouchToHear(on: true),
    );
    await openEveryday();
    view = tester.getRect(find.byType(Scrollable).first);
    final cut = control('').evaluate().firstWhere((e) {
      final r = tester.getRect(find.byWidget(e.widget));
      return r.top < view.bottom - 20 && r.bottom > view.bottom;
    });
    await tester.tapAt(Offset(view.center.dx, view.bottom - 10));
    await tester.pumpAndSettle();
    final now = tester.getRect(find.byWidget(cut.widget));
    expect(now.bottom, lessThanOrEqualTo(view.bottom));
    expect(now.top, greaterThanOrEqualTo(view.top));
  });

  testWidgets(
    'first run with the screen reader off: practise, then "Got it" turns it on',
    (tester) async {
      final speaker = FakeSpeaker();
      final touch = TouchToHear(defaultOn: true);
      await pumpApp(tester, speaker, touch: touch);
      // Set up before Touch to hear existed: the practice is shown once.
      expect(find.byType(TouchIntroScreen), findsOneWidget);
      expect(speaker.said.last, startsWith(en.touchIntroTitle));

      await tester.tap(control(en.touchPractice));
      await tester.pumpAndSettle();
      expect(speaker.said.last, startsWith('${en.touchPractice}.'));
      await tester.tap(control(en.touchPractice));
      await tester.pumpAndSettle();
      expect(speaker.said.last, en.touchPracticeDone);

      await tester.tap(control(en.touchGotIt));
      await tester.pumpAndSettle();
      await tester.tap(control(en.touchGotIt));
      await tester.pumpAndSettle();
      expect(find.byType(TouchIntroScreen), findsNothing);
      expect((touch.on, touch.chosen), (true, true));
    },
  );

  testWidgets(
    '"I use VoiceOver / TalkBack" skips it and turns Touch to hear off',
    (tester) async {
      final touch = TouchToHear(defaultOn: true);
      await pumpApp(tester, FakeSpeaker(), touch: touch);
      for (var i = 0; i < 2; i++) {
        await tester.tap(control(en.touchUseScreenReader));
        await tester.pumpAndSettle();
      }
      expect(find.byType(TouchIntroScreen), findsNothing);
      expect((touch.on, touch.chosen), (false, true));
    },
  );

  testWidgets(
    'the outline never changes a control\'s size; the caption goes after 5 s',
    (tester) async {
      final touch = TouchToHear(on: false);
      await pumpApp(tester, FakeSpeaker(), touch: touch);
      final off = [
        en.askQuestion,
        en.practiceQuiz,
      ].map((t) => tester.getSize(control(t))).toList();
      await touch.set(true);
      await tester.pumpAndSettle();
      await tester.tap(control(en.practiceQuiz));
      await tester.pumpAndSettle();
      final on = [
        en.askQuestion,
        en.practiceQuiz,
      ].map((t) => tester.getSize(control(t))).toList();
      expect(
        on,
        off,
      ); // tiles in a row still fill their share (board T2's buttons shrank)
      final said = find.textContaining('Tap again to open.');
      expect(said, findsOneWidget);
      await tester.pump(TouchToHear.captionFor + const Duration(seconds: 1));
      expect(said, findsNothing);
    },
  );
}
