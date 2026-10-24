import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/library.dart';
import 'package:app/papers.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart';

final en = lookupAppLocalizations(const Locale('en'));

const labelJson = {
  'tips': <String>[],
  'lines': [
    {
      'text': 'Amoxicillin 500 mg capsules take one three times daily for seven days',
      'confidence': 0.95,
      'top': 10,
    },
  ],
  'warnings': [
    {'block_index': 0, 'code': 'low_confidence_number', 'word_index': 1},
  ],
};

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

/// Lets SharedPreferences-backed loads finish.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('library store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps readings 30 days, newest first, then deletes them', () async {
      final day1 = DateTime(2026, 10, 1);
      final result = ReadResult.fromJson(readJson);
      await Library.save(result, null, now: day1);
      await Library.save(
        result,
        Paper.medicine,
        now: day1.add(const Duration(days: 5)),
      );
      final soon = await Library.load(now: day1.add(const Duration(days: 29)));
      expect(soon.map((r) => r.paper), [Paper.medicine, null]);
      final later = await Library.load(now: day1.add(const Duration(days: 31)));
      expect(later.single.paper, Paper.medicine);
      // The expired one is gone for good, not just hidden.
      expect(
        await Library.load(now: day1.add(const Duration(days: 2))),
        hasLength(1),
      );
    });

    test('titles never show an unreliable number or cut one in half', () async {
      final saved = await Library.save(
        ReadResult.fromJson(labelJson),
        Paper.medicine,
      );
      final title = saved.title('unclear number');
      expect(title, startsWith('Amoxicillin [unclear number] mg capsules'));
      expect(title, isNot(contains('500')));
      expect(title, endsWith(' …'));
      // Every word shown is a whole word from the page (or the marker).
      final page =
          'Amoxicillin [unclear number] mg capsules take one three '
          'times daily for seven days …';
      expect(title.split(' ').every(page.split(' ').contains), isTrue);
    });

    test('a reopened reading is the same page', () async {
      final saved = await Library.save(ReadResult.fromJson(tableJson), null);
      final again = (await Library.load()).single.result;
      expect(
        again.items
            .map((i) => (i.kind, i.words, i.cells.map((c) => c.value)))
            .toString(),
        ReadResult.fromJson(tableJson).items
            .map((i) => (i.kind, i.words, i.cells.map((c) => c.value)))
            .toString(),
      );
      expect(saved.json, tableJson);
    });
  });

  testWidgets('save from the Reader, find it in My library, delete it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker);
    await captureToReader(tester);
    await tap(tester, en.saveToLibrary);
    await settle(tester);
    expect(find.text(en.savedToLibrary), findsOneWidget);
    expect(find.bySemanticsLabel(en.saveToLibrary), findsNothing);
    expect(speaker.said.last, en.savedToLibrary);

    await tap(tester, en.backToHome);
    expect(
      tester.getSemantics(find.bySemanticsLabel(en.myLibrary)).hint,
      isEmpty,
    );
    await tap(tester, en.myLibrary);
    await settle(tester);
    final entry = RegExp(
      '^Food tests\\. ${en.yourPage} · Saved .* · ${en.libraryDeletesIn(30)}\$',
    );
    expect(find.bySemanticsLabel(entry), findsOneWidget);
    expect(find.text(en.libraryPrivacy), findsOneWidget);
    expectAccessible(tester, 'Library');

    await tap(tester, entry);
    expect(speaker.said, contains('Food tests'));
    expect(find.bySemanticsLabel(en.saveToLibrary), findsNothing);
    await tap(tester, en.deleteFromLibrary);
    expect(find.text(en.deleteConfirm), findsOneWidget);
    await tap(tester, en.cancel);
    expect(find.bySemanticsLabel(en.deleteFromLibrary), findsOneWidget);
    await tap(tester, en.deleteFromLibrary);
    await tap(tester, en.deleteYes);
    await settle(tester);
    expect(speaker.said.last, en.deletedFromLibrary);
    expect(find.text(en.libraryEmpty), findsOneWidget);
    handle.dispose();
  });

  testWidgets('under 13: no library tile and no Save in the Reader', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeSpeaker(),
      profile: ProfileController(tier: Tier.classroom, teacherSession: true),
    );
    expect(find.bySemanticsLabel(en.myLibrary), findsNothing);
    await captureToReader(tester);
    expect(find.bySemanticsLabel(en.saveToLibrary), findsNothing);
  });
}
