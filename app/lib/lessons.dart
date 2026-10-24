import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'policy.dart';
import 'tasks.dart';

/// Where "Practise now" takes the learner.
enum Practice { home, capture, statement }

/// A short spoken lesson: steps read one after another by the phone's voice.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.minutes,
    required this.feature,
    required this.steps,
    this.practice,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'] as String,
    title: j['title'] as String,
    minutes: j['minutes'] as int,
    feature: Feature.values.byName(j['feature'] as String),
    steps: List<String>.from(j['steps'] as List),
    practice: switch (j['practice']) {
      final String p => Practice.values.byName(p),
      _ => null,
    },
  );

  final String id;
  final String title;
  final int minutes;
  final Feature feature; // who may take it (the money lesson is 18+)
  final List<String> steps;
  final Practice? practice;

  static Future<List<Lesson>> load([
    String asset = 'assets/lessons/lessons.json',
  ]) async {
    final j = jsonDecode(await rootBundle.loadString(asset)) as Map;
    return [
      for (final l in j['lessons'] as List)
        Lesson.fromJson(l as Map<String, dynamic>),
    ];
  }
}

/// How far the learner got in each lesson, kept on this phone.
class LessonProgress {
  LessonProgress._(this._prefs);
  final SharedPreferences _prefs;

  static Future<LessonProgress> load() async =>
      LessonProgress._(await SharedPreferences.getInstance());

  int step(Lesson l) => _prefs.getInt('lesson_${l.id}_step') ?? 0;
  bool done(Lesson l) => _prefs.getBool('lesson_${l.id}_done') ?? false;
  bool doneId(String id) => _prefs.getBool('lesson_${id}_done') ?? false;

  Future<void> setStep(Lesson l, int step) =>
      _prefs.setInt('lesson_${l.id}_step', step);

  /// The first time a lesson is finished it counts as a task for the score.
  Future<void> finish(Lesson l) async {
    if (done(l)) return;
    await _prefs.setBool('lesson_${l.id}_done', true);
    await TaskLog.record(TaskKind.lesson);
  }
}
