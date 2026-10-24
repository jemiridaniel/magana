import 'package:shared_preferences/shared_preferences.dart';

import 'papers.dart';
import 'policy.dart';

/// Real tasks finished in Magana, kept only on this phone. They feed the
/// Independence Score; nothing here leaves the device.
enum TaskKind {
  readSchool,
  readMedicine,
  readReport,
  readStatement,
  readLetter,
  quiz,
  lesson;

  static TaskKind forPaper(Paper? paper) => switch (paper) {
    null => readSchool,
    Paper.medicine => readMedicine,
    Paper.report => readReport,
    Paper.statement => readStatement,
    Paper.letter => readLetter,
  };
}

/// Score areas, each shown only to tiers that can do its tasks.
/// [target] tasks in 30 days make 100 in that area.
enum Area {
  learning(Feature.readSchoolwork, 10, {TaskKind.readSchool, TaskKind.quiz}),
  health(Feature.everydayHealth, 4, {
    TaskKind.readMedicine,
    TaskKind.readReport,
  }),
  money(Feature.everydayMoney, 4, {
    TaskKind.readStatement,
    TaskKind.readLetter,
  }),
  skills(Feature.skills, 3, {TaskKind.lesson});

  const Area(this.feature, this.target, this.kinds);
  final Feature feature;
  final int target;
  final Set<TaskKind> kinds;
}

typedef TaskRecord = ({TaskKind kind, DateTime at});

class TaskLog {
  static const _key = 'tasks';
  static const keep = Duration(days: 90);

  static Future<List<TaskRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final s in prefs.getStringList(_key) ?? const <String>[]) ?_parse(s),
    ];
  }

  static Future<void> record(TaskKind kind, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final kept = [
      for (final r in await load())
        if (at.difference(r.at) < keep)
          '${r.kind.name}|${r.at.toIso8601String()}',
      '${kind.name}|${at.toIso8601String()}',
    ];
    await prefs.setStringList(_key, kept);
  }

  static TaskRecord? _parse(String s) {
    if (s.split('|') case [final kind, final at]) {
      final k = TaskKind.values.where((v) => v.name == kind).firstOrNull;
      final t = DateTime.tryParse(at);
      if (k != null && t != null) return (kind: k, at: t);
    }
    return null;
  }
}

/// 0–100 per area: tasks in the last 30 days against the area's target.
/// The overall score is the average of the areas this tier can use.
class IndependenceScore {
  IndependenceScore._(this.byArea, this.thisWeek);

  factory IndependenceScore.from(
    List<TaskRecord> tasks,
    Tier tier, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    bool within(TaskRecord r, int days) =>
        !r.at.isAfter(today) && today.difference(r.at).inDays < days;
    final month = tasks.where((r) => within(r, 30)).toList();
    final week = tasks.where((r) => within(r, 7));
    return IndependenceScore._(
      {
        for (final area in Area.values)
          if (allows(tier, area.feature))
            area:
                (100 *
                        month
                            .where((r) => area.kinds.contains(r.kind))
                            .length
                            .clamp(0, area.target) /
                        area.target)
                    .round(),
      },
      {
        for (final kind in TaskKind.values)
          if (week.where((r) => r.kind == kind).length case final n when n > 0)
            kind: n,
      },
    );
  }

  final Map<Area, int> byArea;
  final Map<TaskKind, int> thisWeek;

  int get overall => byArea.isEmpty
      ? 0
      : (byArea.values.reduce((a, b) => a + b) / byArea.length).round();
}

/// The score when the learner first opened My score, kept on this phone, so the
/// screen can say how far they have come (design L3). Shown after a week.
class ScoreHistory {
  static const _score = 'score_start';
  static const _at = 'score_start_at';

  /// Remembers [overall] the first time; returns the starting point and how many
  /// whole weeks ago it was, or null until a week has passed.
  static Future<({int start, int weeks})?> since(
    int overall, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    final at = DateTime.tryParse(prefs.getString(_at) ?? '');
    if (at == null) {
      await prefs.setInt(_score, overall);
      await prefs.setString(_at, today.toIso8601String());
      return null;
    }
    final weeks = today.difference(at).inDays ~/ 7;
    return weeks < 1 ? null : (start: prefs.getInt(_score) ?? 0, weeks: weeks);
  }

  /// "Share my score with my teacher": the learner's choice, nothing is sent
  /// until the class is connected to the teacher portal.
  static Future<bool> sharing() async =>
      (await SharedPreferences.getInstance()).getBool('share_score') ?? false;

  static Future<void> setSharing(bool on) async =>
      (await SharedPreferences.getInstance()).setBool('share_score', on);
}
