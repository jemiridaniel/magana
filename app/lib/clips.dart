import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'platform.dart';

/// Recorded prompts (docs/recording/RECORDING_GUIDE.md): every fixed phrase of the app (menus,
/// cues, warnings, health templates) can be played from a clip a native speaker recorded, in
/// each language. Where there is no clip, the phone's voice says it, as before.
///
/// - assets/voice/phrases.json: for each language, each fixed phrase's text → its ID. Made by
///   scripts/export_phrases.py from the app's texts (lib/l10n) and the health templates.
/// - assets/voice/clips.json: for each language, ID → clip file in assets/voice/. Made by
///   scripts/import_clips.py from the recordings. Empty until clips are recorded.
///
/// A phrase is matched whole, sentence by sentence: "Page read. Seven lines." plays the clip
/// for "Page read." and lets the phone's voice say "Seven lines." (it has a number in it, and
/// numbers are never recorded clips: they are read as printed).
class ClipLibrary {
  ClipLibrary({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<_Index>? _index;
  _Index? _ready;

  /// For tests: a library with these phrases and clips, no assets needed.
  ClipLibrary.of(
    Map<String, Map<String, String>> phrases,
    Map<String, Map<String, String>> clips,
    [Map<String, List<ClipPattern>> patterns = const {}]
  ) : _bundle = rootBundle,
      _ready = _Index(_normalised(phrases), clips, patterns) {
    _index = Future.value(_ready);
  }

  Future<_Index> get _loaded => _index ??= _load().then((i) => _ready = i);

  /// Starts loading the index (main.dart, at start), so [planNow] has it.
  Future<void> load() => _loaded;

  Future<_Index> _load() async {
    final patterns = <String, List<ClipPattern>>{};
    Future<Map<String, Map<String, String>>> read(String asset) async {
      try {
        final json = jsonDecode(await _bundle.loadString(asset)) as Map;
        if (json['_patterns'] case final Map byLang) {
          for (final MapEntry(:key, :value) in byLang.entries) {
            patterns['$key'] = [
              for (final p in value as List) ?ClipPattern.fromJson(p),
            ];
          }
        }
        return {
          for (final MapEntry(:key, :value) in json.entries)
            if (value is Map && !'$key'.startsWith('_'))
              '$key': {
                for (final e in value.entries) '${e.key}': '${e.value}',
              },
        };
      } catch (e) {
        devLog('clips: $asset not read ($e)');
        return {};
      }
    }

    return _Index(
      _normalised(await read('assets/voice/phrases.json')),
      await read('assets/voice/clips.json'),
      patterns,
    );
  }

  static Map<String, Map<String, String>> _normalised(
    Map<String, Map<String, String>> phrases,
  ) => {
    for (final MapEntry(key: lang, value: byText) in phrases.entries)
      lang: {
        for (final MapEntry(key: text, value: id) in byText.entries)
          normalise(text): id,
      },
  };

  /// How phrases are compared: case, spacing and the final full stop don't matter.
  static String normalise(String text) => text
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?…]+$'), '')
      .toLowerCase();

  /// [text] in [lang] as spoken pieces, or null when no part of it has a clip (the phone's
  /// voice says it all, as before).
  Future<List<ClipPart>?> plan(String lang, String text) async =>
      _plan(await _loaded, lang, text);

  /// As [plan], without waiting: null until the index has loaded. Speech never waits for it.
  List<ClipPart>? planNow(String lang, String text) {
    final index = _ready;
    if (index == null) {
      unawaited(_loaded);
      return null;
    }
    return _plan(index, lang, text);
  }

  List<ClipPart>? _plan(_Index index, String lang, String text) {
    final clips = index.clips[lang];
    final phrases = index.phrases[lang];
    if (clips == null || clips.isEmpty || phrases == null) return null;
    String? clipFor(String s) {
      final id = phrases[normalise(s)];
      return id == null ? null : clips[id];
    }

    final whole = clipFor(text);
    if (whole != null) return [ClipPart(text, whole)];
    final sentences = text
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final parts = [
      for (final s in sentences)
        if (clipFor(s) case final clip?)
          ClipPart(s, clip)
        else if (_template(index.patterns[lang], clips, s) case final pieces?)
          ...pieces
        else
          ClipPart(s, null),
    ];
    return parts.any((p) => p.clip != null) ? parts : null;
  }

  /// The IDs that have a clip in [lang] (diagnostics, tests).
  Future<Set<String>> recorded(String lang) async =>
      (await _loaded).clips[lang]?.keys.toSet() ?? {};

  /// A health template line ("Sha ƙwaya 2 sau 3 a rana."): its fixed words from their clips,
  /// its numbers by the phone's voice, exactly as on the page. Null if no template matches.
  List<ClipPart>? _template(
    List<ClipPattern>? patterns,
    Map<String, String> clips,
    String sentence,
  ) {
    for (final p in patterns ?? const <ClipPattern>[]) {
      final m = p.regex.firstMatch(sentence.trim());
      if (m == null) continue;
      var slot = 0;
      final out = <ClipPart>[];
      for (final piece in p.pieces) {
        if (piece.slot) {
          out.add(ClipPart(m.group(++slot)!, null));
        } else if (piece.text.trim().isNotEmpty) {
          out.add(ClipPart(piece.text.trim(), clips[piece.id]));
        }
      }
      return out.any((c) => c.clip != null) ? out : null;
    }
    return null;
  }
}

class _Index {
  _Index(this.phrases, this.clips, [this.patterns = const {}]);
  final Map<String, Map<String, String>> phrases; // lang → normalised text → ID
  final Map<String, Map<String, String>> clips; // lang → ID → file
  final Map<String, List<ClipPattern>> patterns; // lang → health templates
}

/// A health template, or one of the app's phrases with blanks, as fixed words and slots in order
/// (scripts/export_phrases.py). A slot's [text] is its name ("a", "language").
class ClipPattern {
  ClipPattern(this.id, this.pieces) : regex = _regex(pieces);

  final String id;
  final List<({String text, String? id, bool slot})> pieces;
  final RegExp regex;

  List<String> get slotNames => [
    for (final p in pieces)
      if (p.slot) p.text,
  ];

  static RegExp _regex(List<({String text, String? id, bool slot})> pieces) {
    final parts = <String>[];
    for (final (i, p) in pieces.indexed) {
      if (p.slot) {
        parts.add('(.+?)');
        continue;
      }
      var t = p.text.trim();
      // The final full stop is optional, as in ClipLibrary.normalise.
      if (i == pieces.length - 1) t = t.replaceAll(RegExp(r'[.!?…]+$'), '');
      if (t.isEmpty) continue;
      parts.add(RegExp.escape(t).replaceAll(' ', r'\s+'));
    }
    return RegExp(
      '^${parts.join(r'\s*')}[.!?…]*\$',
      caseSensitive: false,
      unicode: true,
    );
  }

  static ClipPattern? fromJson(Object? json) {
    if (json is! Map || json['pattern'] is! List) return null;
    return ClipPattern('${json['id']}', [
      for (final p in json['pattern'] as List)
        if (p is Map)
          p.containsKey('slot')
              ? (text: '${p['slot']}', id: null, slot: true)
              : (text: '${p['text']}', id: p['id'] as String?, slot: false),
    ]);
  }
}

/// A piece of an utterance: its text, and the clip file that says it (null: the phone's voice).
class ClipPart {
  const ClipPart(this.text, this.clip);
  final String text;
  final String? clip;
}

/// Plays a clip to the end. Replaceable in tests.
abstract class ClipPlayer {
  /// True when it played to the end; false when stopped or it couldn't play.
  Future<bool> play(String file);
  Future<void> stop();
}

class AssetClipPlayer implements ClipPlayer {
  AudioPlayer? _player;
  Completer<bool>? _playing;

  AudioPlayer get _p => _player ??= AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop)
    ..onPlayerComplete.listen((_) => _end(true));

  void _end(bool done) {
    final c = _playing;
    _playing = null;
    if (c != null && !c.isCompleted) c.complete(done);
  }

  @override
  Future<bool> play(String file) async {
    _end(false);
    final done = _playing = Completer<bool>();
    try {
      await _p.play(AssetSource('voice/$file'));
    } catch (e) {
      devLog('clips: $file not played ($e)');
      _end(false);
    }
    return done.future;
  }

  @override
  Future<void> stop() async {
    _end(false);
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
