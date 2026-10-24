import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'l10n/app_localizations.dart';
import 'theme.dart';

/// One screen-reader node for a control: our label plus its tap action.
/// (excludeSemantics drops the child's own semantics, so the tap must be restated.)
class Labelled extends StatelessWidget {
  const Labelled({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.hint,
    this.selected,
    this.inGroup = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final String? hint;
  final bool? selected;
  final bool inGroup;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    selected: selected,
    inMutuallyExclusiveGroup: inGroup,
    label: label,
    hint: hint,
    onTap: onTap,
    excludeSemantics: true,
    child: child,
  );
}

/// Back button + title (+ subtitle), as on every design board.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing; // e.g. the quiz score

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final back = onBack ?? () => Navigator.of(context).maybePop();
    return Row(
      children: [
        if (Navigator.of(context).canPop() || onBack != null) ...[
          Labelled(
            label: l.back,
            onTap: back,
            child: OutlinedButton(
              onPressed: back,
              style: outlinedTile(radius: 32).copyWith(
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              child: const Icon(Icons.chevron_left, size: 32),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: MaganaColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A large card-like choice: title and an explanation line.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    this.detail,
    required this.onTap,
    this.selected = false,
    this.inGroup = false,
    this.leading,
  });

  final String title;
  final String? detail;
  final VoidCallback? onTap;
  final bool selected;
  final bool inGroup;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Labelled(
      label: detail == null ? title : '$title. $detail',
      onTap: onTap,
      selected: inGroup ? selected : null,
      inGroup: inGroup,
      child: OutlinedButton(
        onPressed: onTap,
        style:
            outlinedTile(
              radius: 20,
              bg: selected ? const Color(0xFFE3F1EA) : Colors.white,
              border: selected ? MaganaColors.green : MaganaColors.ink,
            ).copyWith(
              alignment: Alignment.centerLeft,
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(72)),
              padding: const WidgetStatePropertyAll(EdgeInsets.all(18)),
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: selected ? MaganaColors.green : MaganaColors.ink,
                  width: 3,
                ),
              ),
            ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail!,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: MaganaColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main action at the bottom of a screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Labelled(
    label: semanticLabel ?? label,
    onTap: onTap,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: MaganaColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// A secondary, outlined action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Labelled(
    label: semanticLabel ?? label,
    onTap: onTap,
    child: OutlinedButton(
      onPressed: onTap,
      style: outlinedTile(radius: 30).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

enum NoteKind { info, privacy, success, warning, emergency }

/// Coloured note boxes from the designs: privacy (green), info (sand), warning
/// (amber) and the dark emergency banner.
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.text,
    this.kind = NoteKind.info,
    this.bold,
  });

  final String text;
  final String? bold; // leading bold phrase, e.g. "Emergency?"
  final NoteKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, icon, iconColor) = switch (kind) {
      NoteKind.privacy => (
        const Color(0xFFE3F1EA),
        MaganaColors.ink,
        MaganaColors.green,
        Icons.shield_outlined,
        MaganaColors.green,
      ),
      NoteKind.success => (
        const Color(0xFFE3F1EA),
        MaganaColors.ink,
        MaganaColors.green,
        Icons.check_circle_outline,
        MaganaColors.green,
      ),
      NoteKind.warning => (
        MaganaColors.warnFill,
        MaganaColors.warnInk,
        MaganaColors.warnBorder,
        Icons.warning_amber_rounded,
        MaganaColors.warnBorder,
      ),
      NoteKind.emergency => (
        MaganaColors.ink,
        Colors.white,
        MaganaColors.ink,
        Icons.call,
        MaganaColors.amber,
      ),
      NoteKind.info => (
        MaganaColors.chip,
        MaganaColors.ink,
        MaganaColors.chip,
        Icons.info_outline,
        MaganaColors.ink,
      ),
    };
    return Semantics(
      container: true,
      label: bold == null ? text : '$bold $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (bold != null)
                      TextSpan(
                        text: '$bold ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    TextSpan(text: text),
                  ],
                ),
                style: TextStyle(fontSize: 17, height: 1.4, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrollable page body with standard padding; [bottom] stays at the foot.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, this.bottom = const [], required this.body});

  final List<Widget> bottom;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in body)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: c,
                        ),
                    ],
                  ),
                ),
              ),
              for (final b in bottom)
                Padding(padding: const EdgeInsets.only(top: 10), child: b),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speaks [text] once when the screen first appears.
void speakOnOpen(BuildContext context, String Function() text) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) AppScope.of(context).speaker.say(text());
  });
}
