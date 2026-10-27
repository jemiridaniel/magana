// Tablets and iPad (boards T1, T2): one app, laid out by size. Phones (shorter side under
// 600 dp) are unchanged, sideways too.
import 'package:app/l10n/app_localizations.dart';
import 'package:app/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, pumpApp, captureToReader;

final en = lookupAppLocalizations(const Locale('en'));

Finder control(String label) =>
    find.byWidgetPredicate((w) => w is Labelled && w.label.startsWith(label));

const ipadPortrait = Size(834, 1194);
const ipadLandscape = Size(1194, 834);

void main() {
  testWidgets('tablet home (T1): the whole screen, 3 columns, larger targets', (
    tester,
  ) async {
    await pumpApp(tester, FakeSpeaker(), size: ipadPortrait);
    expect(tester.getRect(find.byType(Scaffold).first).width, 834);
    final row = [
      en.askQuestion,
      en.practiceQuiz,
      en.myLibrary,
    ].map((t) => tester.getRect(control(t))).toList();
    expect(row.map((r) => r.top).toSet(), hasLength(1)); // one row of three
    expect(row[0].left < row[1].left && row[1].left < row[2].left, isTrue);
    for (final r in row) {
      expect(r.height, greaterThanOrEqualTo(170));
    }
    expect(
      tester.getRect(control(en.readPage)).height,
      greaterThanOrEqualTo(200),
    );
    expect(
      tester.getRect(control(en.speakCommand)).height,
      greaterThanOrEqualTo(88),
    );
    // Board T1's subtitle: how to hold a tablet.
    expect(find.text(en.readPageTablet), findsOneWidget);
    expectAccessible(tester, 'tablet home');
  });

  testWidgets('a phone held sideways is still a phone', (tester) async {
    await pumpApp(tester, FakeSpeaker(), size: const Size(844, 390));
    expect(find.text(en.readPageTablet), findsNothing);
    final ask = tester.getRect(control(en.askQuestion));
    final quiz = tester.getRect(control(en.practiceQuiz));
    final library = tester.getRect(control(en.myLibrary));
    expect(ask.top, quiz.top); // the phone's 2 columns
    expect(library.top, greaterThan(quiz.top));
    expect(control(en.readPdf), findsNothing);
  });

  testWidgets('list screens on a tablet are a centred column', (tester) async {
    await pumpApp(tester, FakeSpeaker(), size: ipadLandscape);
    await tester.tap(control(en.everydayPapers));
    await tester.pumpAndSettle();
    final card = tester.getRect(control(en.paperMedicine));
    expect(card.width, lessThanOrEqualTo(720));
    expect(card.center.dx, closeTo(1194 / 2, 1));
  });

  testWidgets('tablet capture: lay the page flat, hold the tablet above it', (
    tester,
  ) async {
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker, size: ipadPortrait);
    await captureToReader(tester);
    expect(speaker.said, contains(en.framingGuidanceTablet));
    expect(speaker.said, isNot(contains(en.framingGuidance)));
  });

  testWidgets(
    'tablet reader, landscape (T2): the page on the left, controls on the right',
    (tester) async {
      await pumpApp(tester, FakeSpeaker(), size: ipadLandscape);
      await captureToReader(tester);
      final page = tester.getRect(find.bySemanticsLabel(en.pageViewLabel));
      final next = tester.getRect(control(en.nextLine));
      expect(page.right, lessThan(next.left));
      expect(page.height, greaterThan(400));
      // Every line of the page is shown; the one being read is highlighted.
      expect(find.text('Food tests'), findsWidgets);
      expect(next.height, greaterThanOrEqualTo(72));

      // Zoom and high contrast.
      final before = tester.getSize(find.text('Food tests').first).height;
      await tester.tap(control(en.zoomIn));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.text('Food tests').first).height,
        greaterThan(before),
      );
      await tester.tap(control(en.highContrast));
      await tester.pumpAndSettle();
      final contrast = tester.widget<Labelled>(control(en.highContrast));
      expect(contrast.toggled, isTrue);
      await tester.tap(control(en.highContrast)); // back, for the other tests
      await tester.tap(control(en.zoomOut));
      await tester.pumpAndSettle();
      expectAccessible(tester, 'tablet reader');
    },
  );

  testWidgets('tablet reader, portrait: the page above the reading panel', (
    tester,
  ) async {
    await pumpApp(tester, FakeSpeaker(), size: ipadPortrait);
    await captureToReader(tester);
    final page = tester.getRect(find.bySemanticsLabel(en.pageViewLabel));
    final next = tester.getRect(control(en.nextLine));
    expect(page.bottom, lessThan(next.top));
  });

  testWidgets('the screen reader meets the tablet reader in a sensible order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, FakeSpeaker(), size: ipadLandscape);
    await captureToReader(tester);
    final order = <String>[];
    void visit(SemanticsNode node) {
      final label = node.getSemanticsData().label;
      if (label.isNotEmpty) order.add(label);
      node.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    var root = tester.getSemantics(find.byType(Scaffold).last);
    while (root.parent != null) {
      root = root.parent!;
    }
    visit(root);
    int at(String label) => order.indexWhere((l) => l.startsWith(label));
    // Back, the page, its zoom, then the reading panel and its controls.
    expect(at(en.backToHome), lessThan(at(en.pageViewLabel)));
    expect(at(en.pageViewLabel), lessThan(at(en.zoomIn)));
    expect(at(en.zoomIn), lessThan(at(en.previousLine)));
    expect(at(en.previousLine), lessThan(at(en.nextLine)));
    expect(at(en.nextLine), lessThan(at(en.playLabel)));
    handle.dispose();
  });
}
