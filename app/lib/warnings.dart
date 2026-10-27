import 'api.dart';
import 'l10n/app_localizations.dart';
import 'messages.dart';

/// What the Reader says about what it isn't sure of, grouped so it doesn't tire the listener
/// (docs/FINDINGS.md, 27 Oct 2026: 32 spoken warnings for 14 lines on a boarding pass).
///
/// - Before the page: one short summary ("3 numbers are unclear. 4 lines are hard to read.
///   Say 'what's unclear' to hear where."), after the page's own tips.
/// - At each spot: a number Magana isn't sure of is said as "unclear number" in place of the
///   digits, as before; a line with other doubt ends with "Unclear."
/// - On request ("what's unclear?"): every spot with its full warning.
///
/// Number safety is unchanged: which numbers are unclear is the backend's decision, and an
/// unclear number is never spoken as digits. A line flagged for a number with no word to mark
/// still says "unclear number" at its end.
class PageWarnings {
  PageWarnings(this.items);
  final List<ReadItem> items;

  static bool _number(String code) => numberCodes.contains(code);

  /// Something on [i] other than a number is unclear: a word, the line's end, a part of it.
  static bool unclearText(ReadItem i) =>
      !i.isFaint && i.codes.any((c) => !_number(c));

  /// A number warning on [i] that no word or cell carries: said at the line's end.
  static bool unmarkedNumber(ReadItem i) =>
      i.codes.any(_number) &&
      i.unclearWords.isEmpty &&
      !i.cells.any((c) => c.unclear);

  /// Numbers said as "unclear number" on the page.
  int get unclearNumbers => items.fold(
    0,
    (n, i) =>
        n +
        i.unclearWords.length +
        i.cells.where((c) => c.unclear).length +
        (unmarkedNumber(i) ? 1 : 0),
  );

  /// Lines or rows with unclear text (not counting numbers).
  int get unclearLines => items.where(unclearText).length;

  /// Whole lines the server found ink for but no words: "I may have missed a line here".
  int get missedLines =>
      items.where((i) => i.codes.contains('missed_line')).length;

  bool get any => unclearNumbers > 0 || unclearLines > 0 || missedLines > 0;

  /// The page summary, said once before the page.
  List<String> summary(AppLocalizations l) => [
    if (unclearNumbers > 0) l.summaryNumbers(unclearNumbers),
    if (unclearLines > 0) l.summaryLines(unclearLines),
    if (missedLines > 0) l.summaryMissed(missedLines),
    if (any) l.summaryAsk,
  ];

  /// What is said at the end of [i] itself: "Unclear." and/or "unclear number".
  static List<String> marks(AppLocalizations l, ReadItem i) => [
    if (unmarkedNumber(i)) l.unclearNumber,
    if (unclearText(i)) l.unclearMark,
  ];

  /// Every spot and its full warnings, for "what's unclear?". [where] names an item
  /// ("line 3", "row 2").
  List<String> details(AppLocalizations l, String Function(ReadItem) where) => [
    for (final i in items)
      if (i.codes.isNotEmpty)
        [
          for (final code in i.codes.toSet())
            messageFor(l, code, where: where(i)),
        ].join(' '),
  ];
}
