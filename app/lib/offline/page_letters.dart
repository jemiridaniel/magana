import 'language_words.dart';
import 'word_lists.dart';

/// The server's letter rules for offline reading (backend letters.py): which page is
/// Hausa, Yorùbá or Igbo; a digit inside a word on such a page, which is an unclear
/// letter, never a number (Tesseract read Igbo ọ as "9"; ML Kit can too); and a word that
/// may have lost a special letter, from the same word lists as the server.

final _word = RegExp(r"\p{L}+(?:['’]\p{L}+)*", unicode: true);
final _combining = RegExp(r'[̀-ͯ]');

/// The word with every accent, dot and hook taken off (letters.plain).
String plainWord(String word) => word
    .toLowerCase()
    .split('')
    .map((c) => plainLetters[c] ?? c)
    .join()
    .replaceAll(_combining, '');

/// "ha", "yo" or "ig" when the page is clearly in that language, else null
/// (letters.page_language).
String? pageLanguageOf(String text) {
  final counts = {for (final l in functionWords.keys) l: 0};
  for (final m in _word.allMatches(text)) {
    final w = plainWord(m.group(0)!);
    for (final MapEntry(key: lang, value: words) in functionWords.entries) {
      if (words.contains(w)) counts[lang] = counts[lang]! + 1;
    }
  }
  final best = [
    'ha',
    'yo',
    'ig',
  ].reduce((a, b) => counts[b]! > counts[a]! ? b : a);
  final english = counts['en']! > 1 ? counts['en']! : 1;
  return counts[best]! >= minWords && counts[best]! >= margin * english
      ? best
      : null;
}

// A number with its unit or an ordinal, written as one word ("500mg", "2nd"): a number.
final _numberWord = RegExp(
  r'^\d+(?:[.,]\d+)?(?:mg|mcg|ml|l|g|kg|km|cm|mm|m|am|pm|st|nd|rd|th|h|hr|hrs|min|s|x)$',
  caseSensitive: false,
);
final _edges = RegExp(
  '^[()\\[\\]{},.;:!?"\'“”‘’]+|[()\\[\\]{},.;:!?"\'“”‘’]+\$',
);
final _digit = RegExp(r'\d');

bool _lowerLetter(String c) => c != c.toUpperCase() && c == c.toLowerCase();

/// A digit inside a word made of letters ("uz9", "9zo"): not digits alone ("929"), a
/// number with its unit ("500mg") or capitals with digits ("SS2", "B12", "N500")
/// (letters.digit_in_word).
bool digitInWord(String token) {
  for (final part in token.replaceAll(_edges, '').split(RegExp('[-/–—]'))) {
    if (_digit.hasMatch(part) &&
        part.split('').any(_lowerLetter) &&
        !_numberWord.hasMatch(part)) {
      return true;
    }
  }
  return false;
}

final _tones = RegExp('[\u0300\u0301\u0304]');

/// The word without tone marks, keeping dotted and hooked letters (letters.untoned).
String untonedWord(String word) => word
    .toLowerCase()
    .split('')
    .map((c) => untonedLetters[c] ?? c)
    .join()
    .replaceAll(_tones, '');

final _index = <String, Map<String, List<String>>>{};

/// Plain form → the list's words with that form (letters._index), parsed when first needed.
Map<String, List<String>> _wordIndex(String lang) => _index[lang] ??= {
  for (final line in (wordListLines[lang] ?? '').split('\n'))
    if (line.trim().isNotEmpty)
      line.split(' ').first: line.split(' ').skip(1).toList(),
};

/// True when a listed word spelled like [token] has a special letter [token] lacks
/// (letters.may_miss_letter): "kwaya" (ƙwaya) is marked; "ƙwaya" and "da" are not.
bool mayMissLetter(String token, String lang) {
  final m = _word.firstMatch(token);
  if (m == null) return false;
  final found = untonedWord(m.group(0)!);
  return (_wordIndex(lang)[plainWord(found)] ?? const []).any(
    (c) => c != found,
  );
}

final _sentenceEnd = RegExp('[.!?]["\'”’)\\]]*\$');
final _letter = RegExp(r'\p{L}', unicode: true);
const _strokeD = {'đ': 'ɗ', 'Đ': 'Ɗ'};

/// A plain letter right before its own hooked form, any case, đ counted as ɗ ("hadđaka"):
/// left as read and marked (letters._PAIR). The word list holds one such word (habɓakar).
final _pair = RegExp('[dD][ɗƊđĐ]|[bB][ɓƁ]|[kK][ƙƘ]|[yY][ƴƳ]');

/// The word's letters with K made ƙ, or null (letters._k_word): [token] is a capital K word
/// ("Kasa", or "Ƙasa" already restored), the rest in small letters, and the ƙ word is listed.
String? _kWord(String? token) {
  final m = token == null ? null : _word.firstMatch(token);
  if (m == null) return null;
  final w = m.group(0)!;
  final rest = w.substring(1);
  if (w.length < 2 || !'KƘ'.contains(w[0]) || rest != rest.toLowerCase()) {
    return null;
  }
  final hooked = 'ƙ$rest';
  final listed = _wordIndex('ha')[plainWord(hooked)] ?? const [];
  return listed.contains(untonedWord(hooked)) ? hooked : null;
}

/// [token] with its capital K made ƙ, or null (letters._hooked_k): mid-sentence only (not the
/// line's first word, not after . ! ?), the rest of the word in small letters, and the ƙ word
/// in the list. [previous] is the nearest earlier word with a letter in it, so a heading's
/// "== Kuruciya ==" or a list's "• Kasar" starts its line. The capital stays (Ƙ) when the word
/// right [before] or [after] it is such a K word too ("Kungiyoyin Kasa da Kasa": Ƙungiyoyin
/// Ƙasa); a name doesn't count ("Kasar Najeriya": ƙasar). restoreHausa looks through "da".
String? _hookedK(
  String token,
  String? previous, [
  String? before,
  String? after,
]) {
  if (previous == null || _sentenceEnd.hasMatch(previous)) return null;
  final m = _word.firstMatch(token);
  if (m == null || !m.group(0)!.startsWith('K')) return null;
  var hooked = _kWord(token);
  if (hooked == null) return null;
  if (_kWord(before) != null || _kWord(after) != null) {
    hooked = 'Ƙ${hooked.substring(1)}';
  }
  return token.replaceRange(m.start, m.end, hooked);
}

/// A Hausa line's words as the server makes them (letters.restore_hausa): "đ"/"Đ" become ɗ/Ɗ,
/// and a mid-sentence capital K becomes ƙ (or Ƙ) where the ƙ word is listed. [changed] holds
/// each changed word's index; [held], each word with a plain letter before its own hooked one,
/// left as read. Both are marked, so a person still checks them.
({List<String> words, Set<int> changed, Set<int> held}) restoreHausa(
  List<String> tokens,
) {
  final held = {
    for (final (j, t) in tokens.indexed)
      if (_pair.hasMatch(t)) j,
  };
  final words = [
    for (final (j, t) in tokens.indexed)
      held.contains(j) ? t : t.split('').map((c) => _strokeD[c] ?? c).join(),
  ];
  final changed = {
    for (final (j, t) in tokens.indexed)
      if (words[j] != t) j,
  };
  final restoredK = <int>{};
  for (var j = 0; j < words.length; j++) {
    if (held.contains(j)) continue;
    String? previous;
    for (var i = j - 1; i >= 0; i--) {
      if (_letter.hasMatch(words[i])) {
        previous = words[i];
        break;
      }
    }
    final (before, after) = _neighbours(words, j);
    final k = _hookedK(words[j], previous, before, after);
    if (k != null) {
      words[j] = k;
      changed.add(j);
      restoredK.add(j);
    }
  }
  // "X da X": a restored X gives its partner the same first letter (_daPartners).
  for (final (a, b) in _daPartners(words, restoredK, held)) {
    words[b] = _withFirst(words[b], _first(words[a]));
    changed.add(b);
  }
  return (words: words, changed: changed, held: held);
}

bool _isDa(String token) => token.toLowerCase() == 'da';

/// The words next to [j] for the K word check, looking through "da" (letters._neighbours):
/// in "Kasa da Kasa" each Kasa's neighbour is the other.
(String?, String?) _neighbours(List<String> words, int j) {
  var before = j > 0 ? words[j - 1] : null;
  if (before != null && _isDa(before) && j >= 2) before = words[j - 2];
  var after = j + 1 < words.length ? words[j + 1] : null;
  if (after != null && _isDa(after) && j + 2 < words.length) {
    after = words[j + 2];
  }
  return (before, after);
}

String _fold(String token) {
  final m = _word.firstMatch(
    token.split('').map((c) => _strokeD[c] ?? c).join(),
  );
  return m == null ? '' : plainWord(m.group(0)!);
}

String _first(String token) => _word.firstMatch(token)!.group(0)![0];

String _withFirst(String token, String letter) {
  final m = _word.firstMatch(token)!;
  return token.replaceRange(m.start, m.start + 1, letter);
}

/// (restored X, its partner) for each "X da X" whose two words fold to one, hooks and case
/// ignored (letters._da_partners): the partner, starting with K or k, takes X's letter; the
/// first X wins when both were restored differently. "kowa da kowa" has no restored word.
List<(int, int)> _daPartners(
  List<String> words,
  Set<int> restored,
  Set<int> held,
) {
  final out = <(int, int)>[];
  for (var j = 0; j + 2 < words.length; j++) {
    final f = _fold(words[j]);
    if (!_isDa(words[j + 1]) || f.isEmpty || f != _fold(words[j + 2])) continue;
    final (a, b) = restored.contains(j) ? (j, j + 2) : (j + 2, j);
    if (!restored.contains(a) || held.contains(b)) continue;
    final letter = _first(words[a]), other = _first(words[b]);
    if ('Kk'.contains(other) || (restored.contains(b) && other != letter)) {
      out.add((a, b));
    }
  }
  return out;
}
