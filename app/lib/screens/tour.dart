import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../widgets.dart';

/// The guided start (Nurse Balogun, build 7): about a minute, spoken, on what Magana does,
/// where the big buttons are and how to use voice and touch. After language and age in
/// onboarding; skippable; heard again from Settings or by saying "tour" on Home.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key, required this.onDone});

  /// Continue or Skip: onboarding goes on to the next step; from Settings, back.
  final void Function(BuildContext context) onDone;

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    AppScope.of(context).speaker.say('${l.tourTitle}. ${l.tourScript}');
  }

  void _done() {
    AppScope.of(context).speaker.stop();
    widget.onDone(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        ScreenHeader(title: l.tourTitle),
        for (final paragraph in l.tourScript.split(RegExp(r'(?<=\.)\s+')))
          Text(paragraph, style: const TextStyle(fontSize: 20, height: 1.4)),
      ],
      bottom: [
        PrimaryButton(label: l.tourContinue, onTap: _done),
        SecondaryButton(label: l.tourAgain, onTap: _play),
        SecondaryButton(label: l.tourSkip, onTap: _done),
      ],
    );
  }
}
