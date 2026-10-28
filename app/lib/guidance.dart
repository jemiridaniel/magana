import 'dart:convert';

import 'package:flutter/services.dart';

import 'clips.dart';
import 'platform.dart';

/// English guidance (your instruction, 28 Oct 2026): with Hausa, Yorùbá or Igbo chosen and no
/// voice for it on the phone, Magana's own words (menus, cues, the tour, warnings) are said in
/// English with the English voice, after telling the person once. Only Magana's own phrases are
/// translated, by their ID in the app's texts (assets/voice/phrases.json, made by
/// scripts/export_phrases.py): page text never matches one, so it is never read by an English
/// voice. A sentence that isn't one of Magana's phrases is left unsaid (it is on the screen).
class EnglishGuidance {
  EnglishGuidance({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// For tests: these phrases (lang → text → ID), patterns and English texts.
  EnglishGuidance.of(
    Map<String, Map<String, String>> phrases,
    Map<String, String> english, [
    Map<String, List<ClipPattern>> patterns = const {},
  ]) : _bundle = rootBundle {
    _ready = _Guide(_normalised(phrases), english, patterns);
    _index = Future.value(_ready);
  }

  final AssetBundle _bundle;
  Future<_Guide>? _index;
  _Guide? _ready;

  Future<_Guide> get _loaded =>
      _index ??= _load().then((g) => _ready = g);

  Future<void> load() => _loaded;

  Future<_Guide> _load() async {
    try {
      final json =
          jsonDecode(await _bundle.loadString('assets/voice/phrases.json'))
              as Map;
      final phrases = <String, Map<String, String>>{
        for (final MapEntry(:key, :value) in json.entries)
          if (value is Map && !'$key'.startsWith('_'))
            '$key': {for (final e in value.entries) '${e.key}': '${e.value}'},
      };
      final english = <String, String>{
        for (final e in ((json['_english'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      };
      final patterns = <String, List<ClipPattern>>{
        for (final MapEntry(:key, :value)
            in ((json['_ui_patterns'] as Map?) ?? const {}).entries)
          '$key': [for (final p in value as List) ?ClipPattern.fromJson(p)],
      };
      return _Guide(_normalised(phrases), english, patterns);
    } catch (e) {
      devLog('guidance: phrases not read ($e)');
      return _Guide(const {}, const {}, const {});
    }
  }

  static Map<String, Map<String, String>> _normalised(
    Map<String, Map<String, String>> phrases,
  ) => {
    for (final MapEntry(key: lang, value: byText) in phrases.entries)
      lang: {
        for (final MapEntry(key: text, value: id) in byText.entries)
          ClipLibrary.normalise(text): id,
      },
  };

  /// [text] (in [lang]) as English, sentence by sentence; the longest run of sentences that is
  /// one of Magana's phrases is taken first ("Your answers help…. Magana does not diagnose." is
  /// one phrase). Sentences that aren't Magana's are dropped. Null when nothing could be said.
  Future<String?> toEnglish(String lang, String text) async {
    final g = _ready ?? await _loaded; // loaded at start (main.dart): no wait
    final byText = g.phrases[lang];
    if (byText == null) return null;
    String? one(String s) {
      final id = byText[ClipLibrary.normalise(s)];
      if (id != null) return g.english[id];
      for (final p in g.patterns[lang] ?? const <ClipPattern>[]) {
        // "{voice}. {speed}" would match any two sentences: a pattern needs real words of its own.
        if (!_hasOwnWords(p)) continue;
        final m = p.regex.firstMatch(s.trim());
        final en = g.english[p.id];
        if (m == null || en == null) continue;
        // A blank holds data (a number, a name, one of Magana's phrases), never a sentence
        // from a page: otherwise this isn't Magana's phrase, and nothing is said.
        final values = [
          for (var k = 1; k <= m.groupCount; k++) m.group(k)!.trim(),
        ];
        if (values.any(
          (v) => byText[ClipLibrary.normalise(v)] == null && !_isData(v),
        )) {
          continue;
        }
        var out = en;
        var i = 0;
        for (final name in p.slotNames) {
          final value = m.group(++i)!.trim();
          // A value that is itself one of Magana's phrases ("{paper}": a paper's name) in
          // English too; numbers and names as they are.
          final asPhrase = byText[ClipLibrary.normalise(value)];
          out = out.replaceAll(
            '{$name}',
            asPhrase != null ? (g.english[asPhrase] ?? value) : value,
          );
        }
        return out;
      }
      return null;
    }

    final whole = one(text);
    if (whole != null) return whole;
    final sentences = text
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final out = <String>[];
    var i = 0;
    while (i < sentences.length) {
      String? found;
      var j = sentences.length - 1;
      for (; j >= i; j--) {
        found = one(sentences.sublist(i, j + 1).join(' '));
        if (found != null) break;
      }
      if (found != null) {
        out.add(found);
        i = j + 1;
      } else {
        devLog('guidance: not one of Magana\'s phrases, not said: "${sentences[i]}"');
        i++;
      }
    }
    return out.isEmpty ? null : out.join(' ');
  }
}

/// At least 6 letters of fixed words outside the blanks.
bool _hasOwnWords(ClipPattern p) =>
    p.pieces
        .where((x) => !x.slot)
        .map((x) => x.text.replaceAll(RegExp(r'[^\p{L}]', unicode: true), ''))
        .join()
        .length >=
    6;

/// A blank's value that can go into English as it is: numbers and short names (up to 3 words,
/// no sentence inside), never a line of page text.
bool _isData(String v) =>
    !RegExp(r'[.!?…]\s').hasMatch(v) && v.split(RegExp(r'\s+')).length <= 3;

class _Guide {
  _Guide(this.phrases, this.english, this.patterns);
  final Map<String, Map<String, String>> phrases; // lang → normalised text → ID
  final Map<String, String> english; // ID → English text
  final Map<String, List<ClipPattern>> patterns; // lang → phrases with blanks
}
