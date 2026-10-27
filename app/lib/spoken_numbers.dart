/// How numbers are said aloud; what is shown stays exactly as printed. For bank receipts and
/// statements (tester's dark-mode transfer receipt, 27 Oct 2026):
/// - a naira amount ("₦8,000.00", or "#8,000.00" as Nigerian keyboards write it, or OCR's
///   "N8,000.00") is said "8,000 naira", with its kobo when there are any ("8,000 naira 50 kobo");
/// - a run of 7 digits or more (an account number, a reference) is said digit by digit:
///   "0 1 2 3 4 5 6 7 8 9", never "twelve million...".
/// The digits themselves are never changed: only spaces and the words naira and kobo.
String spokenNumbers(String text) {
  final naira = RegExp(
    r'(?<![\w#₦])([₦#N])(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{2}))?(?![\d.,]*\d)',
  );
  var out = text.replaceAllMapped(naira, (m) {
    final sign = m[1]!, whole = m[2]!, kobo = m[3];
    // "N" only before what is clearly an amount (grouped or with kobo): not "N5" in a code.
    if (sign == 'N' && !whole.contains(',') && kobo == null) return m[0]!;
    return [
      '$whole naira',
      if (kobo != null && kobo != '00') '$kobo kobo',
    ].join(' ');
  });
  out = out.replaceAllMapped(
    RegExp(r'\d{7,}'),
    (m) => ' ${m[0]!.split('').join(' ')} ',
  );
  return out.replaceAll(RegExp(r' {2,}'), ' ').trim();
}
