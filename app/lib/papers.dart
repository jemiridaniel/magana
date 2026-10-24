import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'policy.dart';

/// Everyday papers (18+): each reads through the normal Capture and Reader, in
/// the backend's health or money mode (second OCR pass, stricter number checks).
enum Paper {
  medicine(Icons.medication_outlined, 'health', Feature.everydayHealth),
  report(Icons.monitor_heart_outlined, 'health', Feature.everydayHealth),
  statement(Icons.account_balance_outlined, 'money', Feature.everydayMoney);

  const Paper(this.icon, this.mode, this.feature);

  final IconData icon;
  final String mode; // backend /read mode
  final Feature feature;

  bool get isHealth => mode == 'health';

  String title(AppLocalizations l) => switch (this) {
    Paper.medicine => l.paperMedicine,
    Paper.report => l.paperReport,
    Paper.statement => l.paperStatement,
  };

  String detail(AppLocalizations l) => switch (this) {
    Paper.medicine => l.paperMedicineDetail,
    Paper.report => l.paperReportDetail,
    Paper.statement => l.paperStatementDetail,
  };

  /// The "read exactly as printed" note shown and spoken with the reading.
  String note(AppLocalizations l) => switch (this) {
    Paper.medicine => l.noteMedicine,
    Paper.report => l.noteReport,
    Paper.statement => l.noteStatement,
  };
}
