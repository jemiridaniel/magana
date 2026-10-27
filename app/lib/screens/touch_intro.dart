import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../touch.dart';
import '../widgets.dart';

/// Shown once (board 10b) when the phone's screen reader is off and Touch to hear hasn't
/// been chosen: during setup after the language, or on the next start for people who set up
/// before it existed.
bool shouldIntroduceTouch(BuildContext context) {
  final touch = AppScope.of(context).touch;
  return touch.on && !touch.chosen && !screenReaderOn(context);
}

/// "Using Magana by touch" (board 10b): touch to hear, tap again to open, or say it, with a
/// box to practise on. "I use VoiceOver / TalkBack" turns Touch to hear off and skips it.
class TouchIntroScreen extends StatefulWidget {
  const TouchIntroScreen({super.key, required this.onDone});

  /// Where to go next (the age step, or back to Home).
  final void Function(BuildContext context) onDone;

  @override
  State<TouchIntroScreen> createState() => _TouchIntroScreenState();
}

class _TouchIntroScreenState extends State<TouchIntroScreen> {
  bool _practised = false;

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.touchIntroTitle}. ${l.touchIntroBody} '
          '${l.touchToHear}: ${l.touchStep1Body} '
          '${l.touchStep2Title}: ${l.touchStep2Body} '
          '${l.touchStep3Title}: ${l.touchStep3Body} '
          '${l.touchPractice}: ${l.touchPracticeBody}';
    });
  }

  Future<void> _finish(bool on) async {
    await AppScope.of(context).touch.set(on);
    if (mounted) widget.onDone(context);
  }

  void _practise() {
    setState(() => _practised = true);
    AppScope.of(context).speaker
        .say(AppLocalizations.of(context).touchPracticeDone);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget step(int n, String title, String body) => Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: MaganaColors.ink,
              foregroundColor: Colors.white,
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    color: MaganaColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return PageScaffold(
      body: [
        Semantics(
          header: true,
          child: Text(
            l.touchIntroTitle,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          l.touchIntroBody,
          style: const TextStyle(
            fontSize: 18,
            height: 1.4,
            color: MaganaColors.muted,
          ),
        ),
        step(1, l.touchToHear, l.touchStep1Body),
        step(2, l.touchStep2Title, l.touchStep2Body),
        step(3, l.touchStep3Title, l.touchStep3Body),
        Labelled(
          label: l.touchPractice,
          hint: l.touchPracticeBody,
          onTap: _practise,
          radius: 24,
          child: Container(
            constraints: const BoxConstraints(minHeight: 190),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _practised ? const Color(0xFFE3F1EA) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _practised ? MaganaColors.green : MaganaColors.ink,
                width: 3,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_practised)
                  const Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: MaganaColors.green,
                  ),
                Text(
                  l.touchPractice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _practised ? l.touchPracticeDone : l.touchPracticeBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    color: MaganaColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      bottom: [
        PrimaryButton(label: l.touchGotIt, onTap: () => _finish(true)),
        SecondaryButton(
          label: l.touchUseScreenReader,
          onTap: () => _finish(false),
        ),
      ],
    );
  }
}
