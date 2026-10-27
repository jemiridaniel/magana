import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'l10n/app_localizations.dart';
import 'layout.dart';
import 'theme.dart';
import 'touch.dart';
import 'voice_input.dart';

/// One screen-reader node for a control: our label plus its tap action.
/// (excludeSemantics drops the child's own semantics, so the tap must be restated.)
/// The same label and hint are what Touch to hear says (touch.dart), so the two never differ.
class Labelled extends StatefulWidget {
  const Labelled({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.hint,
    this.selected,
    this.toggled,
    this.inGroup = false,
    this.counted = true,
    this.radius = 20,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final String? hint;
  final bool? selected;
  final bool? toggled;
  final bool inGroup;

  /// Counted among the screen's choices ("3 of 7"); false for Back.
  final bool counted;

  /// Corner radius of the yellow Touch to hear outline.
  final double radius;

  @override
  State<Labelled> createState() => _LabelledState();
}

class _LabelledState extends State<Labelled> implements TouchTarget {
  TouchToHear? _touch;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final touch = AppScope.maybeOf(context)?.touch;
    if (touch != _touch) {
      _touch?.unregister(this);
      _touch = touch?..register(this);
    }
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _touch?.unregister(this);
    super.dispose();
  }

  @override
  String get label => widget.label;
  @override
  String? get hint => widget.hint;
  @override
  VoidCallback? get onTap => widget.onTap;
  @override
  bool get enabled => widget.onTap != null;
  @override
  bool get counted => widget.counted;
  @override
  ModalRoute<Object?>? get route => _route;
  @override
  RenderBox? get box {
    final box = mounted ? context.findRenderObject() : null;
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  @override
  void reveal() {
    if (!mounted) return;
    for (final policy in [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(context, alignmentPolicy: policy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantics = Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inGroup,
      label: widget.label,
      hint: widget.hint,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: widget.child,
    );
    final touch = _touch;
    if (touch == null) return semantics;
    return ListenableBuilder(
      listenable: Listenable.merge([touch, touch.focused]),
      builder: (context, _) {
        if (!touch.activeIn(context)) return semantics;
        // Touch to hear: the first touch says it (TouchExplorer), so the control itself
        // never takes the tap; a second tap opens it through [onTap].
        return MetaData(
          metaData: this,
          behavior: HitTestBehavior.opaque,
          child: IgnorePointer(
            child: TouchOutline(
              show: touch.focused.value == this,
              radius: widget.radius,
              child: semantics,
            ),
          ),
        );
      },
    );
  }
}

/// Back button + title (+ subtitle), as on every design board. With [introduce], the
/// screen says its title and how many choices it has when it opens (board 10), for screens
/// that don't speak on their own.
class ScreenHeader extends StatefulWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.introduce = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing; // e.g. the quiz score
  final bool introduce;

  @override
  State<ScreenHeader> createState() => _ScreenHeaderState();
}

class _ScreenHeaderState extends State<ScreenHeader> {
  @override
  void initState() {
    super.initState();
    if (widget.introduce) speakOnOpen(context, () => widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final back = widget.onBack ?? () => Navigator.of(context).maybePop();
    return Row(
      children: [
        if (Navigator.of(context).canPop() || widget.onBack != null) ...[
          Labelled(
            label: l.back,
            onTap: back,
            counted: false,
            radius: 32,
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
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: MaganaColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        ?widget.trailing,
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
    this.icon,
  });

  /// Replaces the kind's icon (the offline banner's "no connection").
  final IconData? icon;
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
            Icon(this.icon ?? icon, size: 26, color: iconColor),
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

/// A scrollable page body with standard padding; [bottom] stays at the foot. With [sayName]
/// (list screens), "Say a name" opens any choice by voice (board 10). On a tablet the body is
/// a centred column ([tabletBodyWidth]) and the targets are larger (layout.dart).
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    this.bottom = const [],
    required this.body,
    this.sayName = false,
  });

  final List<Widget> bottom;
  final List<Widget> body;
  final bool sayName;

  @override
  Widget build(BuildContext context) {
    final foot = [...bottom, if (sayName) const SayNameButton()];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet(context) ? tabletBodyWidth : double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // The last item can always be scrolled fully into view, clear of
                    // the screen's foot (the Everyday list was cut off, board 10).
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
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
                  for (final b in foot)
                    Padding(padding: const EdgeInsets.only(top: 10), child: b),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Speaks [text] once when the screen first appears, with how many choices it has
/// (introduceScreen, board 10).
void speakOnOpen(BuildContext context, String Function() text) =>
    introduceScreen(context, text);

/// "Say a name" (boards 10, 10b): hear a name, and open the control on this screen that
/// has it ("medicine label"). The same names the screen reader and Touch to hear use.
class SayNameButton extends StatefulWidget {
  const SayNameButton({super.key});

  @override
  State<SayNameButton> createState() => _SayNameButtonState();
}

class _SayNameButtonState extends State<SayNameButton> {
  late final VoiceInput _voice = voiceInputFor(context);
  bool? _works;
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) _voice.stop();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final route = ModalRoute.of(context);
    _works ??= await _voice.init();
    if (!mounted) return;
    if (_works != true) {
      scope.speaker.say(l.voiceCommandsUnavailable);
      return;
    }
    await scope.speaker.stop();
    setState(() => _listening = true);
    List<String> heard;
    try {
      heard = await _voice.listen(language: 'en');
    } on VoiceStepFailed {
      heard = const [];
      if (mounted) scope.speaker.say(l.voiceCommandsUnavailable);
    }
    if (!mounted) return;
    setState(() => _listening = false);
    if (heard.isEmpty) {
      scope.speaker.say(l.commandNothingHeard);
      return;
    }
    // Any of the recogniser's guesses that names something here.
    for (final h in heard) {
      if (scope.touch.openByName(route, h)) return;
    }
    scope.speaker.say(l.nameNotFound(heard.first));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = _listening ? l.listeningCommand : l.sayName;
    return Labelled(
      label: label,
      onTap: _tap,
      counted: false,
      radius: 36,
      child: OutlinedButton.icon(
        onPressed: _tap,
        icon: Icon(_listening ? Icons.stop : Icons.mic_none, size: 28),
        label: Text(label),
        style: outlinedTile(radius: 36, bg: MaganaColors.amber).copyWith(
          minimumSize: WidgetStatePropertyAll(
            Size.fromHeight(isTablet(context) ? 80 : 64),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: MaganaColors.ink, width: 3),
          ),
        ),
      ),
    );
  }
}
