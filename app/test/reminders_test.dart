import 'package:app/api.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/main.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/reminders.dart';
import 'package:app/screens/reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker;

final en = lookupAppLocalizations(const Locale('en'));

class FakeAlerts implements ReminderAlerts {
  FakeAlerts({this.allowed = true, this.exact = true});
  final bool allowed;
  @override
  bool exact;
  bool grantExact = true;
  final calls = <String>[];

  @override
  Future<bool> requestExact() async {
    calls.add('requestExact');
    return exact = grantExact;
  }

  @override
  Future<bool> init() async => allowed;
  @override
  Future<void> daily(Reminder r, ReminderNotice n) async => calls.add(
    'daily ${r.minute} ${n.title} | ${n.body}${n.speak == null ? '' : ' | says: ${n.speak}'}',
  );
  @override
  Future<void> snooze(Reminder r, Duration after, ReminderNotice n) async =>
      calls.add(
        'snooze ${r.id} ${after.inMinutes}${n.speak == null ? '' : ' | says'}',
      );
  @override
  Future<void> cancelSnooze(Reminder r) async =>
      calls.add('cancelSnooze ${r.id}');
  @override
  Future<void> cancel(Reminder r) async => calls.add('cancel ${r.id}');
}

String saved(int id, String medicine, String amount, int minute) =>
    '{"id":$id,"medicine":"$medicine","amount":"$amount","minute":$minute}';

Future<(FakeSpeaker, FakeAlerts)> open(
  WidgetTester tester, {
  Tier tier = Tier.standard,
  Map<String, Object> prefs = const {},
  bool allowed = true,
  bool exact = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  clock = () => DateTime(2026, 10, 24, 14, 5);
  addTearDown(() => clock = DateTime.now);
  final alerts = FakeAlerts(allowed: allowed, exact: exact);
  reminderAlerts = () => alerts;
  final profile = ProfileController(
    tier: tier,
    consentAt: tier == Tier.guided ? DateTime(2026) : null,
  );
  final speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(headers: () => profile.headers),
      speaker: speaker,
      language: LanguageController(),
      profile: profile,
    ),
  );
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).last)
      .push(MaterialPageRoute(builder: (_) => const RemindersScreen()));
  await settle(tester);
  return (speaker, alerts);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> tap(WidgetTester tester, Pattern label) async {
  await tester.ensureVisible(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(label).first);
  await settle(tester);
}

void main() {
  group('store', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      clock = () => DateTime(2026, 10, 24, 14, 5);
    });
    tearDown(() => clock = DateTime.now);

    test('due once its time has come, taken for today only', () async {
      final store = await ReminderStore.load();
      final morning = await store.add('Amlodipine 5 mg', '1 tablet', 8 * 60);
      final night = await store.add('Paracetamol 500 mg', '2 tablets', 20 * 60);
      expect(store.all.map((r) => r.minute), [480, 1200]);
      expect(store.state(morning), DoseState.due);
      expect(store.state(night), DoseState.later);
      await store.markTaken(morning);
      expect(store.state(morning), DoseState.taken);
      clock = () => DateTime(2026, 10, 25, 9);
      expect(store.state(morning), DoseState.due); // a new day
    });
  });

  testWidgets('add a reminder: kept exactly as typed, scheduled daily', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, alerts) = await open(tester);
    expect(find.text(en.remindersEmpty), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^${en.emergencyBold}')),
      findsOneWidget,
    );
    expectAccessible(tester, 'Reminders (empty)');

    await tap(tester, en.addReminder);
    await tap(tester, en.saveReminder);
    expect(speaker.said.last, en.medicineNameNeeded);

    await tester.enterText(
      find.widgetWithText(TextField, en.medicineName),
      'Paracetamol 500 mg',
    );
    await tester.enterText(
      find.widgetWithText(TextField, en.medicineAmount),
      '2 tablets',
    );
    expect(find.bySemanticsLabel('${en.reminderTime}: 3:00 PM'), findsOne);
    await tap(tester, en.earlierHour);
    expect(speaker.said.last, '2:00 PM');
    expectAccessible(tester, 'Add reminder');
    await tap(tester, en.saveReminder);

    expect(alerts.calls, [
      // Off by default: the lock screen says only "Magana reminder".
      'daily 840 ${en.reminderGenericTitle} | ${en.reminderGenericBody}',
    ]);
    expect(speaker.said.last, en.reminderSaved('2:00 PM'));
    // 2:00 PM has passed (it is 2:05 PM): due now.
    final due = en.doseLabel(
      '2:00 PM',
      en.doseDue,
      'Paracetamol 500 mg',
      '2 tablets',
    );
    expect(find.bySemanticsLabel(due), findsOneWidget);
    expectAccessible(tester, 'Reminders (due)');

    await tap(tester, en.remindLater);
    expect(alerts.calls.last, 'snooze 1 15');
    expect(speaker.said.last, en.remindLaterSet);

    await tap(tester, en.iTookIt);
    expect(speaker.said.last, en.markedTaken);
    expect(alerts.calls.last, 'cancelSnooze 1');
    expect(
      find.bySemanticsLabel(RegExp('^2:00 PM · ${en.doseTaken}')),
      findsOne,
    );
    handle.dispose();
  });

  testWidgets('due doses are read out on opening; delete asks first', (
    tester,
  ) async {
    final (speaker, alerts) = await open(
      tester,
      prefs: {
        'reminders': [
          saved(1, 'Amlodipine 5 mg', '1 tablet', 8 * 60),
          saved(2, 'Paracetamol 500 mg', '2 tablets', 20 * 60),
        ],
      },
    );
    expect(
      speaker.said.last,
      '${en.remindersTitle}. '
      '${en.doseLabel('8:00 AM', en.doseDue, 'Amlodipine 5 mg', '1 tablet')}.',
    );
    await tap(tester, RegExp('^8:00 PM · ${en.doseLater}'));
    await tap(tester, en.deleteReminder);
    expect(
      find.text(en.deleteReminderConfirm('8:00 PM', 'Paracetamol 500 mg')),
      findsOne,
    );
    await tap(tester, en.deleteYes);
    expect(alerts.calls, ['cancel 2']);
    expect(find.bySemanticsLabel(RegExp('^8:00 PM')), findsNothing);
  });

  testWidgets('notifications refused: says reminders only show in Magana', (
    tester,
  ) async {
    await open(
      tester,
      allowed: false,
      prefs: {
        'reminders': [saved(1, 'Amlodipine 5 mg', '1 tablet', 8 * 60)],
      },
    );
    expect(find.text(en.notificationsOff), findsOneWidget);
  });

  testWidgets('missed a dose goes to a pharmacist', (tester) async {
    await open(tester);
    await tap(tester, en.missedDose);
    expect(find.text(en.healthWorkerTitle), findsOneWidget);
  });

  testWidgets('not on time yet: explained once, then the phone setting', (
    tester,
  ) async {
    final (speaker, alerts) = await open(tester, exact: false);
    await tap(tester, en.addReminder);
    await tester.enterText(
      find.widgetWithText(TextField, en.medicineName),
      'Amlodipine 5 mg',
    );
    await tap(tester, en.saveReminder);
    expect(find.text(en.exactBody), findsOneWidget);
    expect(speaker.said.last, '${en.exactTitle} ${en.exactBody}');
    alerts.grantExact = false;
    await tap(tester, en.exactOpen);
    expect(alerts.calls.first, 'requestExact');
    // Refused: saved anyway, and the list says it may ring late.
    expect(alerts.calls.last, startsWith('daily 900 '));
    expect(find.text(en.remindersMayBeLate), findsOneWidget);
    // Not asked again on the next save.
    await tap(tester, en.addReminder);
    await tester.enterText(
      find.widgetWithText(TextField, en.medicineName),
      'Paracetamol',
    );
    await tap(tester, en.saveReminder);
    expect(find.text(en.exactBody), findsNothing);
    // Granted later from the list: every reminder is rescheduled.
    alerts.grantExact = true;
    alerts.calls.clear();
    await tap(tester, en.allowOnTime);
    await tap(tester, en.exactOpen);
    expect(alerts.calls, [
      'requestExact',
      'daily 900 ${en.reminderGenericTitle} | ${en.reminderGenericBody}',
      'daily 900 ${en.reminderGenericTitle} | ${en.reminderGenericBody}',
    ]);
    expect(find.text(en.remindersMayBeLate), findsNothing);
  });

  testWidgets('under 18: refused', (tester) async {
    await open(tester, tier: Tier.guided);
    expect(find.text(en.adultsOnly), findsOneWidget);
    expect(find.bySemanticsLabel(en.addReminder), findsNothing);
  });

  testWidgets('say the medicine name when locked: off by default, DRAFT', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (speaker, alerts) = await open(
      tester,
      prefs: {
        'reminders': [saved(1, 'Amlodipine 5 mg', '1 tablet', 8 * 60)],
      },
    );
    final row = tester.getSemantics(
      find.bySemanticsLabel(en.sayNameWhenLocked),
    );
    // ignore: deprecated_member_use
    expect(row.hasFlag(SemanticsFlag.isToggled), isFalse);
    expect(find.text(en.sayNameNote), findsOneWidget);
    expectAccessible(tester, 'Reminders with lock-screen setting');

    await tap(tester, en.sayNameWhenLocked);
    expect(
      alerts.calls.last,
      'daily 480 ${en.reminderNotifyTitle} | Amlodipine 5 mg · 1 tablet'
      ' | says: ${en.reminderNotifyTitle}. Amlodipine 5 mg · 1 tablet',
    );
    await tap(tester, en.remindLater);
    expect(alerts.calls.last, 'snooze 1 15 | says');

    // Off again: back to "Magana reminder", nothing spoken.
    await tap(tester, en.sayNameWhenLocked);
    expect(
      alerts.calls.last,
      'daily 480 ${en.reminderGenericTitle} | ${en.reminderGenericBody}',
    );
    expect(
      (await SharedPreferences.getInstance()).getBool('remind_say_name'),
      isFalse,
    );
    handle.dispose();
  });
}
