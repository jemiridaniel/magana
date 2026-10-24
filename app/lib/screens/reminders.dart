import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../policy.dart';
import '../reminders.dart';
import '../theme.dart';
import '../widgets.dart';
import 'everyday.dart';
import 'health_worker.dart';

String reminderTime(BuildContext context, int minute) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));

/// Explains, then opens the phone's "Alarms and reminders" switch, so
/// reminders ring on the minute; reschedules every reminder afterwards.
Future<void> askForOnTime(BuildContext context, ReminderAlerts alerts) async {
  final l = AppLocalizations.of(context);
  final speaker = AppScope.of(context).speaker;
  final store = await ReminderStore.load();
  await store.markAskedExact();
  if (!context.mounted) return;
  speaker.say('${l.exactTitle} ${l.exactBody}');
  final open = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(
        l.exactTitle,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      content: Text(l.exactBody, style: const TextStyle(fontSize: 19)),
      actions: [
        SecondaryButton(
          label: l.notNow,
          onTap: () => Navigator.of(dialog).pop(false),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: l.exactOpen,
          onTap: () => Navigator.of(dialog).pop(true),
        ),
      ],
    ),
  );
  if (open != true || !await alerts.requestExact()) return;
  if (context.mounted) await rescheduleAll(context, alerts);
}

/// What a reminder shows on the lock screen and says, by the learner's choice
/// (DRAFT, pending Dr. Amos): only "Magana reminder" unless they turned on
/// "Say the medicine name when locked".
ReminderNotice noticeFor(BuildContext context, Reminder r, bool sayName) {
  final l = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  return sayName
      ? ReminderNotice(
          title: l.reminderNotifyTitle,
          body: r.text,
          speak: '${l.reminderNotifyTitle}. ${r.text}',
          language: lang,
        )
      : ReminderNotice(
          title: l.reminderGenericTitle,
          body: l.reminderGenericBody,
          language: lang,
        );
}

/// Schedules every reminder again (after the timing permission or the
/// lock-screen setting changed).
Future<void> rescheduleAll(BuildContext context, ReminderAlerts alerts) async {
  final store = await ReminderStore.load();
  if (!context.mounted) return;
  for (final r in store.all) {
    await alerts.daily(r, noticeFor(context, r, store.sayNameWhenLocked));
  }
}

void openReminders(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RemindersScreen()));

/// Today's medicines (18+): the times the learner set, what is due now, and
/// what was taken. Medicine names and amounts are shown exactly as typed.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ReminderAlerts _alerts = reminderAlerts();
  ReminderStore? _store;
  bool? _alertsOn;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      if (!mounted) return;
      final store = _store!;
      final due = store.all.where((r) => store.state(r) == DoseState.due);
      AppScope.of(context).speaker.say(
        [
          '${_l.remindersTitle}.',
          if (store.all.isEmpty) _l.remindersEmpty,
          for (final r in due) '${_label(r, store)}.',
        ].join(' '),
      );
      if (store.all.isNotEmpty) {
        final on = await _alerts.init();
        if (mounted) setState(() => _alertsOn = on);
      }
    });
  }

  Future<void> _load() async {
    final store = await ReminderStore.load();
    if (mounted) setState(() => _store = store);
  }

  String _state(DoseState s) => switch (s) {
    DoseState.taken => _l.doseTaken,
    DoseState.due => _l.doseDue,
    DoseState.later => _l.doseLater,
  };

  String _label(Reminder r, ReminderStore store) => _l.doseLabel(
    reminderTime(context, r.minute),
    _state(store.state(r)),
    r.medicine,
    r.amount,
  );

  Future<void> _taken(Reminder r) async {
    await _store!.markTaken(r);
    await _alerts.cancelSnooze(r);
    if (!mounted) return;
    setState(() {});
    AppScope.of(context).speaker.say(_l.markedTaken);
  }

  Future<void> _later(Reminder r) async {
    await _alerts.snooze(
      r,
      const Duration(minutes: 15),
      noticeFor(context, r, _store!.sayNameWhenLocked),
    );
    if (mounted) AppScope.of(context).speaker.say(_l.remindLaterSet);
  }

  Future<void> _options(Reminder r) async {
    final l = _l;
    final store = _store!;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          _label(r, store),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (store.state(r) != DoseState.taken) ...[
            PrimaryButton(
              label: l.iTookIt,
              onTap: () => Navigator.of(dialog).pop('taken'),
            ),
            const SizedBox(height: 8),
          ],
          SecondaryButton(
            label: l.deleteReminder,
            onTap: () => Navigator.of(dialog).pop('delete'),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: l.cancel,
            onTap: () => Navigator.of(dialog).pop(),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'taken') await _taken(r);
    if (choice == 'delete') await _delete(r);
  }

  Future<void> _delete(Reminder r) async {
    final l = _l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l.deleteReminderConfirm(reminderTime(context, r.minute), r.medicine),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          SecondaryButton(
            label: l.cancel,
            onTap: () => Navigator.of(dialog).pop(false),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: l.deleteYes,
            onTap: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _alerts.cancel(r);
    await _store!.remove(r);
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddReminderScreen(alerts: _alerts)),
    );
    await _load();
    if (_store!.all.isNotEmpty && _alertsOn == null) {
      final on = await _alerts.init();
      if (mounted) setState(() => _alertsOn = on);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (!AppScope.of(context).profile.can(Feature.reminders)) {
      return const AdultsOnlyScreen();
    }
    final store = _store;
    return PageScaffold(
      body: [
        ScreenHeader(title: l.remindersTitle, subtitle: l.remindersSubtitle),
        if (store == null)
          const Center(child: CircularProgressIndicator())
        else if (store.all.isEmpty)
          NoteBox(text: l.remindersEmpty)
        else
          for (final r in store.all)
            if (store.state(r) == DoseState.due)
              _DueCard(
                label: _label(r, store),
                time: reminderTime(context, r.minute),
                reminder: r,
                onTaken: () => _taken(r),
                onLater: () => _later(r),
                onOptions: () => _options(r),
              )
            else
              ChoiceCard(
                title:
                    '${reminderTime(context, r.minute)} · ${_state(store.state(r))}',
                detail: r.text,
                selected: store.state(r) == DoseState.taken,
                leading: Icon(
                  store.state(r) == DoseState.taken
                      ? Icons.check
                      : Icons.schedule,
                  size: 30,
                ),
                onTap: () => _options(r),
              ),
        if (_alertsOn == false)
          NoteBox(text: l.notificationsOff, kind: NoteKind.warning),
        if (store != null && store.all.isNotEmpty) ...[
          _SayNameRow(
            on: store.sayNameWhenLocked,
            onChanged: (on) async {
              await store.setSayNameWhenLocked(on);
              if (!context.mounted) return;
              setState(() {});
              await rescheduleAll(context, _alerts);
            },
          ),
          NoteBox(text: l.sayNameNote, kind: NoteKind.privacy),
        ],
        if (_alertsOn == true && !_alerts.exact) ...[
          NoteBox(text: l.remindersMayBeLate, kind: NoteKind.warning),
          SecondaryButton(
            label: l.allowOnTime,
            onTap: () async {
              await askForOnTime(context, _alerts);
              if (mounted) setState(() {});
            },
          ),
        ],
        PrimaryButton(label: l.addReminder, onTap: _add),
        NoteBox(text: l.reminderNotice),
        SecondaryButton(
          label: l.missedDose,
          onTap: () => openHealthWorker(context),
        ),
        const EmergencyBanner(),
      ],
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({
    required this.label,
    required this.time,
    required this.reminder,
    required this.onTaken,
    required this.onLater,
    required this.onOptions,
  });

  final String label;
  final String time;
  final Reminder reminder;
  final VoidCallback onTaken;
  final VoidCallback onLater;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MaganaColors.ink, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Labelled(
            label: label,
            onTap: onOptions,
            child: InkWell(
              onTap: onOptions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.doseDue.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: MaganaColors.warnInk,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(reminder.text, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: l.iTookIt, onTap: onTaken),
          const SizedBox(height: 10),
          SecondaryButton(label: l.remindLater, onTap: onLater),
        ],
      ),
    );
  }
}

/// Adds one daily medicine time. The name and amount are typed by the learner
/// (TalkBack's keyboard or voice typing) and stored exactly as entered.
class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key, required this.alerts});
  final ReminderAlerts alerts;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _medicine = TextEditingController();
  final _amount = TextEditingController();
  late int _minute = (clock().hour + 1) % 24 * 60; // next full hour
  String? _error;

  @override
  void dispose() {
    _medicine.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _shift(int minutes) {
    setState(() => _minute = (_minute + minutes) % (24 * 60));
    AppScope.of(context).speaker.say(reminderTime(context, _minute));
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final speaker = AppScope.of(context).speaker;
    final medicine = _medicine.text.trim();
    if (medicine.isEmpty) {
      setState(() => _error = l.medicineNameNeeded);
      speaker.say(l.medicineNameNeeded);
      return;
    }
    final time = reminderTime(context, _minute);
    final store = await ReminderStore.load();
    final r = await store.add(medicine, _amount.text.trim(), _minute);
    if (await widget.alerts.init()) {
      // The first time, offer to let reminders ring on the minute.
      if (!widget.alerts.exact && !store.askedExact && mounted) {
        await askForOnTime(context, widget.alerts);
      }
      if (!mounted) return;
      await widget.alerts.daily(
        r,
        noticeFor(context, r, store.sayNameWhenLocked),
      );
    }
    speaker.say(l.reminderSaved(time));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget field(TextEditingController c, String label) => TextField(
      controller: c,
      style: const TextStyle(fontSize: 22),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 18, color: MaganaColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
    Widget stepper(String text, String semantic, int minutes) => Expanded(
      child: SecondaryButton(
        label: text,
        semanticLabel: semantic,
        onTap: () => _shift(minutes),
      ),
    );
    return PageScaffold(
      body: [
        ScreenHeader(title: l.addReminder),
        field(_medicine, l.medicineName),
        field(_amount, l.medicineAmount),
        if (_error != null) NoteBox(text: _error!, kind: NoteKind.warning),
        Semantics(
          liveRegion: true,
          label: '${l.reminderTime}: ${reminderTime(context, _minute)}',
          excludeSemantics: true,
          child: Text(
            reminderTime(context, _minute),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
        ),
        Row(
          children: [
            stepper('− 1 h', l.earlierHour, -60),
            const SizedBox(width: 10),
            stepper('+ 1 h', l.laterHour, 60),
          ],
        ),
        Row(
          children: [
            stepper('− 15 min', l.earlierMinutes, -15),
            const SizedBox(width: 10),
            stepper('+ 15 min', l.laterMinutes, 15),
          ],
        ),
      ],
      bottom: [PrimaryButton(label: l.saveReminder, onTap: _save)],
    );
  }
}

/// "Say the medicine name when locked" (off by default). The whole row toggles.
class _SayNameRow extends StatelessWidget {
  const _SayNameRow({required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      toggled: on,
      label: l.sayNameWhenLocked,
      excludeSemantics: true,
      onTap: () => onChanged(!on),
      child: InkWell(
        onTap: () => onChanged(!on),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MaganaColors.ink, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.sayNameWhenLocked,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: on,
                activeThumbColor: MaganaColors.green,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
