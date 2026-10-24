import 'package:flutter/material.dart';

/// Magana look: Atkinson Hyperlegible, high contrast, big targets.
abstract final class MaganaColors {
  static const green = Color(0xFF0A6B4B);
  static const amber = Color(0xFFFFC94A);
  static const ink = Color(0xFF14171A);
  static const ground = Color(0xFFFBFAF6);
  static const muted = Color(0xFF3D434A); // 9.6:1 on ground
  static const chip = Color(0xFFEDEAE1);
  static const camera = Color(0xFF0E1113);
  static const warnFill = Color(0xFFFFF1D6);
  static const warnBorder = Color(0xFF8A4B00);
  static const warnInk = Color(0xFF4A2800);
}

/// Every control is at least this tall and wide (CLAUDE.md: touch targets >= 64 px).
const double minTarget = 64;

ThemeData maganaTheme() {
  const font = 'AtkinsonHyperlegible';
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: font,
    scaffoldBackgroundColor: MaganaColors.ground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MaganaColors.green,
      primary: MaganaColors.green,
      secondary: MaganaColors.amber,
      surface: MaganaColors.ground,
      onSurface: MaganaColors.ink,
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Desktop browsers default to compact density, which shrinks buttons by 8 px.
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: MaganaColors.ink,
      displayColor: MaganaColors.ink,
    ),
    // A thick, visible focus ring for keyboard and switch-access users.
    focusColor: MaganaColors.amber.withValues(alpha: 0.6),
  );
}

/// Outlined white tile/button used across screens.
ButtonStyle outlinedTile({
  double radius = 18,
  Color fg = MaganaColors.ink,
  Color bg = Colors.white,
  Color border = MaganaColors.ink,
}) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(minTarget, minTarget),
    backgroundColor: bg,
    foregroundColor: fg,
    side: BorderSide(color: border, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(
      fontFamily: 'AtkinsonHyperlegible',
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}
