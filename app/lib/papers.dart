import 'package:flutter/material.dart';

import 'api.dart';
import 'l10n/app_localizations.dart';
import 'policy.dart';

/// Everyday papers (18+): each reads through the normal Capture and Reader, in
/// the backend's health or money mode (second OCR pass, stricter number checks).
enum Paper {
  medicine(Icons.medication_outlined, 'health', Feature.everydayHealth),
  report(Icons.monitor_heart_outlined, 'health', Feature.everydayHealth),
  statement(Icons.account_balance_outlined, 'money', Feature.everydayMoney),
  letter(Icons.mail_outline, 'letter', Feature.everydayLetters);

  const Paper(this.icon, this.mode, this.feature);

  final IconData icon;
  final String mode; // backend /read mode
  final Feature feature;

  bool get isHealth => mode == 'health';

  String title(AppLocalizations l) => switch (this) {
    Paper.medicine => l.paperMedicine,
    Paper.report => l.paperReport,
    Paper.statement => l.paperStatement,
    Paper.letter => l.paperLetter,
  };

  String detail(AppLocalizations l) => switch (this) {
    Paper.medicine => l.paperMedicineDetail,
    Paper.report => l.paperReportDetail,
    Paper.statement => l.paperStatementDetail,
    Paper.letter => l.paperLetterDetail,
  };

  /// The "read exactly as printed" note shown and spoken with the reading.
  String note(AppLocalizations l) => switch (this) {
    Paper.medicine => l.noteMedicine,
    Paper.report => l.noteReport,
    Paper.statement => l.noteStatement,
    Paper.letter => l.noteLetter,
  };
}

// "Read any paper": fixed word rules, never a guess about what the page says.
// The photo is read in the strict letter mode either way; this only picks which
// note and buttons the Reader shows. Unsure: a letter.
final _signs = <Paper, List<RegExp>>{
  Paper.medicine: [
    for (final p in [
      r'\bmg\b',
      r'\btablets?\b',
      r'\bcapsules?\b',
      r'\bdoses?\b',
      r'\bsyrup\b',
      r'\bml\b',
      r'\bexpiry\b',
      r'\bprescri',
    ])
      RegExp(p),
  ],
  Paper.report: [
    for (final p in [
      r'g/dl',
      r'mmol',
      r'\branges?\b',
      r'\bresults?\b',
      r'h(a)?emoglobin',
      r'\breference\b',
      r'\blaboratory\b',
      r'x\s?10',
    ])
      RegExp(p),
  ],
  Paper.statement: [
    for (final p in [
      r'\bbalance\b',
      r'\bdebit\b',
      r'\bcredit\b',
      r'\btransactions?\b',
      r'\baccount\b',
      r'₦',
      r'\bngn\b',
      r'\bstatement\b',
    ])
      RegExp(p),
  ],
};

/// The kind of paper, when at least two of its signs are on the page and no
/// other kind has as many; otherwise [Paper.letter].
Paper detectPaper(ReadResult result) {
  final text = [
    for (final item in result.items) ...[
      item.text,
      for (final c in item.cells) '${c.header} ${c.value}',
    ],
  ].join(' ').toLowerCase();
  final hits = {
    for (final MapEntry(key: paper, value: signs) in _signs.entries)
      paper: signs.where((s) => s.hasMatch(text)).length,
  };
  final best = hits.entries.reduce((a, b) => b.value > a.value ? b : a);
  final tied = hits.values.where((v) => v == best.value).length > 1;
  return best.value >= 2 && !tied ? best.key : Paper.letter;
}
