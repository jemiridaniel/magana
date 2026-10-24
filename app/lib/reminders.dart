import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The current time; replaceable in tests.
DateTime Function() clock = DateTime.now;

/// One daily medicine time. The medicine and amount are exactly what the
/// learner typed from their label or pharmacist; Magana never changes them.
class Reminder {
  const Reminder({
    required this.id,
    required this.medicine,
    required this.amount,
    required this.minute,
  });

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'] as int,
    medicine: j['medicine'] as String,
    amount: j['amount'] as String,
    minute: j['minute'] as int,
  );

  final int id;
  final String medicine;
  final String amount;
  final int minute; // minutes after midnight

  /// "Paracetamol 500 mg · 2 tablets", or just the name if no amount was typed.
  String get text => amount.isEmpty ? medicine : '$medicine · $amount';

  Map<String, dynamic> toJson() => {
    'id': id,
    'medicine': medicine,
    'amount': amount,
    'minute': minute,
  };
}

enum DoseState { taken, due, later }

/// Reminders and which of today's doses were marked taken, on this phone.
class ReminderStore {
  ReminderStore._(this._prefs);
  final SharedPreferences _prefs;

  static Future<ReminderStore> load() async =>
      ReminderStore._(await SharedPreferences.getInstance());

  List<Reminder> get all => [
    for (final s in _prefs.getStringList('reminders') ?? const <String>[])
      Reminder.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ]..sort((a, b) => a.minute.compareTo(b.minute));

  Future<Reminder> add(String medicine, String amount, int minute) async {
    final ids = all.map((r) => r.id);
    final r = Reminder(
      id: ids.isEmpty ? 1 : ids.reduce((a, b) => a > b ? a : b) + 1,
      medicine: medicine,
      amount: amount,
      minute: minute,
    );
    await _store([...all, r]);
    return r;
  }

  Future<void> remove(Reminder r) => _store([
    for (final x in all)
      if (x.id != r.id) x,
  ]);

  Future<void> _store(List<Reminder> list) => _prefs.setStringList(
    'reminders',
    [for (final r in list) jsonEncode(r.toJson())],
  );

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<String> get _taken => _prefs.getStringList('reminders_taken') ?? [];

  bool takenToday(Reminder r) => _taken.contains('${r.id}|${_day(clock())}');

  Future<void> markTaken(Reminder r) async {
    final today = _day(clock());
    // Only today's marks matter; older ones are dropped.
    await _prefs.setStringList('reminders_taken', [
      for (final t in _taken)
        if (t.endsWith('|$today')) t,
      '${r.id}|$today',
    ]);
  }

  bool get askedExact => _prefs.getBool('asked_exact_alarms') ?? false;
  Future<void> markAskedExact() => _prefs.setBool('asked_exact_alarms', true);

  DoseState state(Reminder r) {
    if (takenToday(r)) return DoseState.taken;
    final now = clock();
    return now.hour * 60 + now.minute >= r.minute
        ? DoseState.due
        : DoseState.later;
  }
}

/// Phone notifications for reminders; replaceable in tests.
abstract class ReminderAlerts {
  /// False when the learner turned notifications off for Magana.
  Future<bool> init();

  /// Whether the phone lets reminders ring on the minute. Without it Android
  /// may ring them up to an hour late.
  bool get exact;

  /// Opens the phone's "Alarms and reminders" switch for Magana.
  Future<bool> requestExact();
  Future<void> daily(Reminder r, String title, String body);
  Future<void> snooze(Reminder r, Duration after, String title, String body);

  /// After "I've taken it": a pending "remind in 15 min" must not ring.
  Future<void> cancelSnooze(Reminder r);
  Future<void> cancel(Reminder r);
}

ReminderAlerts Function() reminderAlerts = LocalReminderAlerts.new;

class LocalReminderAlerts implements ReminderAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _exact = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine reminders',
      channelDescription: 'Times you set for your medicines',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<bool> init() async {
    try {
      if (!_ready) {
        tzdata.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        _ready = true;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      final allowed = await android.requestNotificationsPermission() ?? true;
      // Exact timing when the phone allows it; otherwise Android may ring a
      // reminder up to an hour late (see requestExact).
      _exact = await android.canScheduleExactNotifications() ?? false;
      return allowed;
    } catch (e) {
      debugPrint('reminders: notifications unavailable: $e');
      return false;
    }
  }

  @override
  bool get exact => _exact;

  @override
  Future<bool> requestExact() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return _exact = true;
    await android.requestExactAlarmsPermission();
    return _exact = await android.canScheduleExactNotifications() ?? false;
  }

  AndroidScheduleMode get _mode => _exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  @override
  Future<void> daily(Reminder r, String title, String body) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      r.minute ~/ 60,
      r.minute % 60,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return _plugin.zonedSchedule(
      id: r.id,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: _mode,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> snooze(Reminder r, Duration after, String title, String body) =>
      _plugin.zonedSchedule(
        id: 100000 + r.id,
        scheduledDate: tz.TZDateTime.now(tz.local).add(after),
        notificationDetails: _details,
        androidScheduleMode: _mode,
        title: title,
        body: body,
      );

  @override
  Future<void> cancelSnooze(Reminder r) => _plugin.cancel(id: 100000 + r.id);

  @override
  Future<void> cancel(Reminder r) async {
    await _plugin.cancel(id: r.id);
    await cancelSnooze(r);
  }
}
