import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../policy.dart';
import '../widgets.dart';

/// Shows onboarding until an age tier is chosen, the consent or classroom step
/// when a tier can't be used yet, and [home] otherwise.
class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => switch (profile.tier) {
        null => const _OnboardingFlow(),
        Tier.guided when !profile.guardianConsent => const ConsentStep(),
        Tier.classroom when !profile.teacherSession => const ClassroomStep(),
        _ => home,
      },
    );
  }
}

class _OnboardingFlow extends StatelessWidget {
  const _OnboardingFlow();

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateRoute: (_) =>
        MaterialPageRoute(builder: (_) => const LanguageStep()),
  );
}

// ---------- Step 1: language

class LanguageStep extends StatefulWidget {
  const LanguageStep({super.key});

  @override
  State<LanguageStep> createState() => _LanguageStepState();
}

class _LanguageStepState extends State<LanguageStep> {
  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.chooseLanguageTitle}. ${l.chooseLanguageBody} ${l.languageHearsHint}';
    });
  }

  Future<void> _choose(AppLanguage lang) async {
    final scope = AppScope.of(context);
    await scope.language.select(lang.code);
    await scope.speaker.setLanguage(lang.code);
    // Each option is heard in its own language.
    await scope.speaker.say(
      '${lang.name}. ${lookupAppLocalizations(Locale(lang.code)).welcome}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    return PageScaffold(
      body: [
        _StepTitle(
          step: 1,
          title: l.chooseLanguageTitle,
          body: l.chooseLanguageBody,
        ),
        for (final lang in appLanguages)
          ChoiceCard(
            title: lang.name,
            selected: lang.code == current,
            inGroup: true,
            leading: Icon(
              lang.code == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 28,
            ),
            onTap: () => _choose(lang),
          ),
        NoteBox(text: l.languageHearsHint),
      ],
      bottom: [
        PrimaryButton(
          label: l.continueLabel,
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AgeStep())),
        ),
      ],
    );
  }
}

// ---------- Step 2: age

class AgeStep extends StatefulWidget {
  const AgeStep({super.key});

  @override
  State<AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends State<AgeStep> {
  String _script(AppLocalizations l) => [
    l.ageTitle,
    l.ageBody,
    '${l.ageAdult}. ${l.ageAdultDetail}',
    '${l.ageTeen}. ${l.ageTeenDetail}',
    '${l.ageChild}. ${l.ageChildDetail}',
  ].join(' ');

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () => _script(AppLocalizations.of(context)));
  }

  void _next(Widget step) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => step));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        _StepTitle(step: 2, title: l.ageTitle, body: l.ageBody),
        ChoiceCard(
          title: l.ageAdult,
          detail: l.ageAdultDetail,
          onTap: () => _next(const ReadyStep()),
        ),
        ChoiceCard(
          title: l.ageTeen,
          detail: l.ageTeenDetail,
          onTap: () => _next(const ConsentStep()),
        ),
        ChoiceCard(
          title: l.ageChild,
          detail: l.ageChildDetail,
          onTap: () => _next(const ClassroomStep()),
        ),
        NoteBox(text: l.privacyNote, kind: NoteKind.privacy),
      ],
      bottom: [
        SecondaryButton(
          label: l.hearAgain,
          onTap: () => AppScope.of(context).speaker.say(_script(l)),
        ),
      ],
    );
  }
}

// ---------- Step 3: ready (18+), guardian consent (13–17) or classroom (under 13)

class ReadyStep extends StatefulWidget {
  const ReadyStep({super.key});

  @override
  State<ReadyStep> createState() => _ReadyStepState();
}

class _ReadyStepState extends State<ReadyStep> {
  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.readyTitle}. ${l.readyBody} ${l.privacyNote}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        _StepTitle(step: 3, title: l.readyTitle, body: l.readyBody),
        NoteBox(text: l.privacyNote, kind: NoteKind.privacy),
      ],
      bottom: [
        PrimaryButton(
          label: l.startLabel,
          onTap: () => AppScope.of(context).profile.setTier(Tier.standard),
        ),
      ],
    );
  }
}

class ConsentStep extends StatefulWidget {
  const ConsentStep({super.key});

  @override
  State<ConsentStep> createState() => _ConsentStepState();
}

class _ConsentStepState extends State<ConsentStep> {
  String _script(AppLocalizations l) => [
    l.consentTitle,
    l.consentBody,
    l.consentPoint1,
    l.consentPoint2,
    l.consentPoint3,
  ].join(' ');

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () => _script(AppLocalizations.of(context)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        _StepTitle(step: 3, title: l.consentTitle, body: l.consentBody),
        for (final point in [l.consentPoint1, l.consentPoint2, l.consentPoint3])
          NoteBox(text: point),
      ],
      bottom: [
        SecondaryButton(
          label: l.hearAgain,
          onTap: () => AppScope.of(context).speaker.say(_script(l)),
        ),
        PrimaryButton(
          label: l.consentConfirm,
          onTap: () =>
              AppScope.of(context).profile
                  .setTier(Tier.guided, guardianConsent: true),
        ),
      ],
    );
  }
}

class ClassroomStep extends StatefulWidget {
  const ClassroomStep({super.key});

  @override
  State<ClassroomStep> createState() => _ClassroomStepState();
}

class _ClassroomStepState extends State<ClassroomStep> {
  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.classroomTitle}. ${l.classroomBody}';
    });
  }

  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final profile = AppScope.of(context).profile;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l.classroomConfirmTitle,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        actions: [
          SecondaryButton(
            label: l.cancel,
            onTap: () => Navigator.of(dialog).pop(false),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: l.classroomConfirmYes,
            onTap: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (profile.tier != Tier.classroom) await profile.setTier(Tier.classroom);
      profile.startTeacherSession(); // this launch only: never saved
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onboarding = AppScope.of(context).profile.tier == null;
    return PageScaffold(
      body: [
        _StepTitle(
          step: onboarding ? 3 : null,
          title: l.classroomTitle,
          body: l.classroomBody,
        ),
      ],
      bottom: [PrimaryButton(label: l.classroomStart, onTap: _start)],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.step,
    required this.title,
    required this.body,
  });
  final int? step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Navigator.of(context).canPop())
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ScreenHeader(title: step == null ? '' : l.stepOf(step!, 3)),
          ),
        if (!Navigator.of(context).canPop() && step != null)
          Text(
            l.stepOf(step!, 3),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(fontSize: 19, height: 1.45)),
      ],
    );
  }
}
