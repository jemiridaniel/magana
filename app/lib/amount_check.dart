/// Money amounts on receipts, screenshots and bank papers are said only when two separate
/// readings agree exactly (27 Oct 2026: Tesseract read the "₦" of a dark-mode transfer receipt
/// as "4", "#" or "N"). The server's reading is checked against this phone's own (Apple Vision
/// on the iPhone, ML Kit on Android): an amount the phone didn't read character for character,
/// currency sign included, is said "I can't read the amount clearly"; one whose digits agree
/// but not its sign is said as its digits, then "I can't read the currency sign clearly".
/// "Naira" is said only for a "₦" or "NGN" both read (spoken_numbers.dart). A page read only once
/// (on the phone, without the server; or where this phone can't read, the web) has no second
/// reading, so none of its amounts are said. The first reading is never changed: amounts are
/// only held back.
library;

import 'dart:typed_data';

import 'api.dart';
import 'offline/offline_reader.dart';

/// One amount as printed: a currency sign then digits, or digits grouped in thousands or with
/// two decimals ("₦8,000.00", "#500", "N1,250", "8,000.00", "45.50"). Plain numbers ("2",
/// "2026", "0123456789") are not amounts: the number rules cover them.
/// Any currency symbol counts as a sign: Apple Vision read the "₦" of a receipt as "₩" (FINDINGS).
final _amount = RegExp(
  r'^(\p{Sc}|NGN|N|#)?(\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2}|\d+)$',
  unicode: true,
);
const _signs = {'₦', 'NGN', 'N', '#'};

/// Signs an amount on a Nigerian paper may really have. Any other ("₩", "¥": "₦" misread) is
/// held back even when both readings agree on it.
const _likelySigns = {'', '₦', 'NGN', 'N', '#', r'$', '£', '€'};

/// The amount [word] holds, exactly as printed and with [sign] (a sign word just before it,
/// "NGN 8,000.00"), or null. Trailing punctuation isn't part of it.
String? amountIn(String word, {String? sign}) {
  final w = word.replaceAll(RegExp(r'^[(\[]+|[.,;:)\]]+$'), '');
  final m = _amount.firstMatch(w);
  if (m == null) return null;
  final own = m[1];
  final digits = m[2]!;
  final s = own ?? sign;
  if (s == null && !digits.contains(',') && !digits.contains('.')) return null;
  if (s == 'N' && !digits.contains(',') && !digits.contains('.')) {
    return null; // "N5": a code or a room, not an amount
  }
  return '${s ?? ''}$digits';
}

/// A bare currency sign word ("₦", "NGN") right before an amount.
bool isSignWord(String word) {
  final w = word.trim();
  return _signs.contains(w) || RegExp(r'^\p{Sc}$', unicode: true).hasMatch(w);
}

typedef _Spot = ({
  String amount,
  String sign,
  int? line,
  int? word,
  (int, int, int)? cell,
});

List<String> _words(Map<String, dynamic> line) {
  final words = line['words'] as List?;
  return words != null && words.isNotEmpty
      ? [for (final w in words) (w as Map)['text'] as String? ?? '']
      : (line['text'] as String? ?? '').split(' ');
}

String _signOf(String amount) =>
    amount.substring(0, amount.indexOf(RegExp(r'\d')));

List<_Spot> _amounts(Map<String, dynamic> json) {
  final out = <_Spot>[];
  final lines = (json['lines'] as List? ?? const []).cast<Map>();
  for (var i = 0; i < lines.length; i++) {
    final words = _words(lines[i].cast<String, dynamic>());
    for (var j = 0; j < words.length; j++) {
      final sign = j > 0 && isSignWord(words[j - 1])
          ? words[j - 1].trim()
          : null;
      final a = amountIn(words[j], sign: sign);
      if (a != null) {
        out.add((amount: a, sign: _signOf(a), line: i, word: j, cell: null));
      }
    }
  }
  final tables = (json['tables'] as List? ?? const []).cast<Map>();
  for (var t = 0; t < tables.length; t++) {
    final rows = tables[t]['rows'] as List? ?? const [];
    for (var r = 0; r < rows.length; r++) {
      for (final c in (rows[r] as List).cast<Map>()) {
        final text = (c['text'] as String? ?? '').trim();
        final parts = text.split(RegExp(r'\s+'));
        final a = parts.length == 2 && isSignWord(parts[0])
            ? amountIn(parts[1], sign: parts[0])
            : amountIn(text);
        if (a != null) {
          final cell = (t, c['row'] as int? ?? r, c['col'] as int? ?? 0);
          out.add((
            amount: a,
            sign: _signOf(a),
            line: null,
            word: null,
            cell: cell,
          ));
        }
      }
    }
  }
  return out;
}

/// [server]'s reading (the /read response) checked against [phone] (this phone's own reading
/// of the same picture, null if there is none). Each of the phone's amounts confirms one of the
/// server's: exactly first, then by its digits alone.
/// - The same amount, sign included, with a likely sign: said as printed.
/// - The same digits (commas and decimal point included) but another sign, or an unlikely sign
///   both agree on ("₩"): the digits, then "I can't read the currency sign clearly"
///   ("currency_unclear").
/// - Otherwise: "I can't read the amount clearly" ("amount_unconfirmed").
Map<String, dynamic> confirmAmounts(
  Map<String, dynamic> server,
  Map<String, dynamic>? phone,
) {
  final spots = _amounts(server);
  if (spots.isEmpty) return server;
  final exact = <String, int>{};
  final digits = <String, int>{};
  for (final s in phone == null ? const <_Spot>[] : _amounts(phone)) {
    exact[s.amount] = (exact[s.amount] ?? 0) + 1;
    digits[_digits(s)] = (digits[_digits(s)] ?? 0) + 1;
  }
  final warnings = [...(server['warnings'] as List? ?? const [])];
  final cellWarnings = [...(server['cell_warnings'] as List? ?? const [])];
  var held = 0, signs = 0;
  void mark(_Spot s, String code) {
    if (s.cell case (final t, final r, final c)) {
      cellWarnings.add({'table_index': t, 'row': r, 'col': c, 'code': code});
    } else {
      warnings.add({'block_index': s.line, 'word_index': s.word, 'code': code});
    }
  }

  final pending = <_Spot>[];
  for (final s in spots) {
    if ((exact[s.amount] ?? 0) > 0) {
      exact[s.amount] = exact[s.amount]! - 1;
      digits[_digits(s)] = digits[_digits(s)]! - 1;
      if (!_likelySigns.contains(s.sign)) {
        signs++;
        mark(s, 'currency_unclear');
      }
    } else {
      pending.add(s);
    }
  }
  for (final s in pending) {
    if ((digits[_digits(s)] ?? 0) > 0) {
      digits[_digits(s)] = digits[_digits(s)]! - 1;
      signs++;
      mark(s, 'currency_unclear');
    } else {
      held++;
      mark(s, 'amount_unconfirmed');
    }
  }
  return {
    ...server,
    'warnings': warnings,
    'cell_warnings': cellWarnings,
    'amounts_checked': spots.length,
    'amounts_held': held,
    'amounts_sign_unclear': signs,
  };
}

String _digits(_Spot s) => s.amount.substring(s.sign.length);

/// The digits of the amount in [word] ("#8,000.00" → "8,000.00"), as said and shown when only
/// its currency sign is unclear.
String digitsOf(String word, {String? sign}) {
  final parts = word.trim().split(RegExp(r'\s+'));
  final a = parts.length == 2 && isSignWord(parts[0])
      ? amountIn(parts[1], sign: parts[0])
      : amountIn(word, sign: sign);
  return a == null ? word : a.substring(_signOf(a).length);
}

/// Whether [page]'s amounts are checked: a screenshot (as the phone or the server found it),
/// or a money paper (a receipt, a bank statement).
bool checksAmounts(
  ReadResult page, {
  required String mode,
  bool screenshot = false,
}) => screenshot || page.json?['screenshot'] == true || mode == 'money';

/// [page] (the server's reading of [bytes]) with each money amount held back unless this
/// phone's own reading of the same picture ([phone], or one made now) holds it exactly. A page
/// read only on the phone has no second reading: all its amounts are held back.
Future<ReadResult> confirmOnPhone(
  ReadResult page,
  Uint8List bytes, {
  ReadResult? phone,
}) async {
  final json = page.json;
  if (json == null) return page;
  Map<String, dynamic>? second;
  if (identical(phone, page) || page.offline) {
    second = null;
  } else if (phone != null) {
    second = phone.json;
  } else {
    try {
      // Every line as the phone read it (no money-page check dropping lines): only its text
      // is compared.
      second = (await readOnPhone(
        bytes,
        mode: 'school',
      ).timeout(const Duration(seconds: 15)))?.json;
    } catch (_) {
      second = null;
    }
  }
  final checked = confirmAmounts(json, second);
  return identical(checked, json) ? page : ReadResult.fromJson(checked);
}
