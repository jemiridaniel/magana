import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'papers.dart';

/// A reading the learner chose to keep: the page text, never the photo.
class SavedReading {
  const SavedReading({
    required this.id,
    required this.paper,
    required this.savedAt,
    required this.json,
  });

  factory SavedReading.fromJson(Map<String, dynamic> j) => SavedReading(
    id: j['id'] as String,
    paper: switch (j['paper']) {
      final String p => Paper.values.byName(p),
      _ => null,
    },
    savedAt: DateTime.parse(j['saved_at'] as String),
    json: j['result'] as Map<String, dynamic>,
  );

  final String id;
  final Paper? paper;
  final DateTime savedAt;
  final Map<String, dynamic> json; // the backend's /read response

  DateTime get deleteAt => savedAt.add(Library.keep);
  ReadResult get result => ReadResult.fromJson(json);

  /// The page's first readable line, for the library list. Numbers the backend
  /// marked unreliable are never shown: they become [unclear].
  String title(String unclear) {
    final first = result.items.where((i) => !i.isFaint).firstOrNull;
    if (first == null) return '';
    final words = first.isRow
        ? [for (final c in first.cells) c.unclear ? '[$unclear]' : c.value]
        : [
            for (final (i, w) in first.words.indexed)
              first.unclearWords.contains(i) ? '[$unclear]' : w,
          ];
    // Shorten at whole words only, so no number is ever cut in half.
    final kept = <String>[];
    for (final w in words) {
      if (kept.isNotEmpty && [...kept, w].join(' ').length > 60) {
        return '${kept.join(' ')} …';
      }
      kept.add(w);
    }
    return kept.join(' ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paper': paper?.name,
    'saved_at': savedAt.toIso8601String(),
    'result': json,
  };
}

/// Saved readings, kept on this phone for 30 days and then deleted.
class Library {
  static const keep = Duration(days: 30);
  static const _key = 'library';

  /// Newest first; anything older than 30 days is deleted on the way.
  static Future<List<SavedReading>> load({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    final all = [
      for (final s in prefs.getStringList(_key) ?? const <String>[])
        SavedReading.fromJson(jsonDecode(s) as Map<String, dynamic>),
    ];
    final kept = all.where((r) => today.isBefore(r.deleteAt)).toList();
    if (kept.length != all.length) await _store(prefs, kept);
    return kept..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  static Future<SavedReading> save(
    ReadResult result,
    Paper? paper, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final reading = SavedReading(
      id: at.microsecondsSinceEpoch.toString(),
      paper: paper,
      savedAt: at,
      json: result.json ?? const {},
    );
    final prefs = await SharedPreferences.getInstance();
    await _store(prefs, [...await load(now: at), reading]);
    return reading;
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _store(prefs, [
      for (final r in await load())
        if (r.id != id) r,
    ]);
  }

  static Future<void> _store(SharedPreferences p, List<SavedReading> all) =>
      p.setStringList(_key, [for (final r in all) jsonEncode(r.toJson())]);
}
