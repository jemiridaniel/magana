import 'language_words.dart';

/// The server's letter rules for offline reading (backend letters.py): which page is
/// Hausa, Yorùbá or Igbo, and a digit inside a word on such a page, which is an unclear
/// letter, never a number (Tesseract read Igbo ọ as "9"; ML Kit can too).

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
