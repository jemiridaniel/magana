import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Web only. Browsers won't speak until the person has pressed something
/// (Chrome's autoplay rule), so the PWA opens with one button that covers the
/// screen. It has focus, so Enter or Space presses it, and screen readers read
/// "Start Magana". Speech starts with that press. Never shown on phones.
class StartMagana extends StatefulWidget {
  const StartMagana({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  State<StartMagana> createState() => _StartMaganaState();
}

class _StartMaganaState extends State<StartMagana> {
  // It sits above the Navigator, where autofocus doesn't reach: ask directly.
  final _focus = FocusNode(debugLabel: 'Start Magana');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onStart = widget.onStart;
    final label = AppLocalizations.of(context).startMagana;
    return Material(
      color: MaganaColors.ground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          button: true,
          label: label,
          onTap: onStart,
          excludeSemantics: true,
          child: SizedBox.expand(
            child: FilledButton(
              focusNode: _focus,
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: MaganaColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: const BorderSide(color: MaganaColors.ink, width: 3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/brand/magana_mark.svg',
                    width: 120,
                    height: 120,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
