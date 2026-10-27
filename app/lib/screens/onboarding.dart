import 'package:flutter/material.dart';

import '../api.dart' show ClassLink;
import '../app_scope.dart';
import '../curriculum.dart';
import '../help_check.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../policy.dart';
import '../profile.dart';
import '../route_speech.dart';
import '../widgets.dart';
import '../offline/photo_queue.dart';
import '../platform/shared_pdf.dart';
import 'class_code.dart';
import 'pdf.dart';
import 'touch_intro.dart';

/// Shows onboarding until an age tier is chosen, the classroom step when a
/// Classroom session hasn't started, and [home] otherwise. A Guided learner whose
/// guardian hasn't agreed yet goes Home too, where only reading pages works.
///
/// On start and whenever the app comes back to the front, a phone linked to a
/// class asks the backend how the link stands: consent recorded by the teacher,
/// or removed from the class.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.home});
  final Widget home;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _sharedPdfs();
      _fullReadings();
    });
  }

  /// A PDF opened with Magana (or shared to it) goes to Read a PDF, once the
  /// profile is set up and its tier may read pages (not a Classroom phone).
  Future<void> _sharedPdfs() async {
    void open(SharedPdf pdf) {
      if (!mounted) return;
      final profile = AppScope.of(context).profile;
      if (profile.tier == null || profile.tier == Tier.classroom) return;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => PdfScreen(shared: pdf)));
    }

    listenForSharedPdfs(open);
    final pdf = await takeSharedPdf();
    if (pdf != null) open(pdf);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _fullReadings();
    }
  }

  /// Pages read offline get their full reading when the phone is online again
  /// (board 5e); the readings go to My library and the photos are deleted.
  Future<void> _fullReadings() async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final profile = scope.profile;
    // "Did you need help?" totals for the teacher, if this learner shares (board 8).
    if (profile.link case final link? when profile.tier != Tier.classroom) {
      ProgressShare.send(scope.api, link);
    }
    if (!profile.can(Feature.library) || profile.tier == Tier.classroom) return;
    try {
      final n = await photoQueue.drain(scope.api);
      if (n > 0 && mounted) scope.speaker.say(l.fullReadingsReady(n));
    } catch (_) {
      // No queue on this platform, or still offline: try again next time.
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    if (scope.profile.link == null) return;
    try {
      final s = await scope.api.learnerStatus();
      await scope.profile.applyLinkStatus(s.status, s.classInfo);
    } catch (_) {
      // Offline or asleep: keep what the phone knows.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => switch (profile.tier) {
        null => const _OnboardingFlow(),
        Tier.classroom when !profile.teacherSession => const ClassroomStep(),
        _ => widget.home,
      },
    );
  }
}

class _OnboardingFlow extends StatelessWidget {
  const _OnboardingFlow();

  @override
  Widget build(BuildContext context) => Navigator(
    observers: [
      SpeechRouteObserver(
        AppScope.of(context).voice,
        AppScope.of(context).touch,
      ),
    ],
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
          total: 4,
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
          onTap: () {
            final nav = Navigator.of(context);
            void age(BuildContext _) =>
                nav.push(MaterialPageRoute(builder: (_) => const AgeStep()));
            // Screen reader off: how to use Magana by touch first (board 10b).
            if (shouldIntroduceTouch(context)) {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => TouchIntroScreen(onDone: age),
                ),
              );
            } else {
              age(context);
            }
          },
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
        _StepTitle(step: 2, total: 4, title: l.ageTitle, body: l.ageBody),
        ChoiceCard(
          title: l.ageAdult,
          detail: l.ageAdultDetail,
          onTap: () => _next(const WhoStep(tier: Tier.standard)),
        ),
        ChoiceCard(
          title: l.ageTeen,
          detail: l.ageTeenDetail,
          onTap: () => _next(const WhoStep(tier: Tier.guided)),
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

// ---------- Step 3 (18+ and 13–17): who is using Magana (A1)

/// In school (join with the class code), finished school (goals) or university
/// and other (no class).
class WhoStep extends StatefulWidget {
  const WhoStep({super.key, required this.tier});
  final Tier tier;

  @override
  State<WhoStep> createState() => _WhoStepState();
}

class _WhoStepState extends State<WhoStep> {
  String _script(AppLocalizations l) => [
    l.whoTitle,
    l.whoBody,
    '${l.whoInSchool}. ${l.whoInSchoolDetail}',
    '${l.whoFinished}. ${l.whoFinishedDetail}',
    '${l.whoOther}. ${l.whoOtherDetail}',
  ].join(' ');

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () => _script(AppLocalizations.of(context)));
  }

  void _push(Widget step) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => step));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tier = widget.tier;
    final adult = tier == Tier.standard;
    return PageScaffold(
      body: [
        _StepTitle(step: 3, total: 4, title: l.whoTitle, body: l.whoBody),
        ChoiceCard(
          title: l.whoInSchool,
          detail: l.whoInSchoolDetail,
          leading: const Icon(Icons.school_outlined, size: 28),
          onTap: () => _push(
            JoinClassScreen(
              tier: tier,
              onJoined: (ctx, link) => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => JoinedScreen(
                    link: link,
                    onStart: () => finishInSchool(ctx, tier, link),
                  ),
                ),
              ),
              onNoCode: () => _push(
                ClassStep(
                  adult: adult,
                  onChosen: (ctx, level) async {
                    final profile = AppScope.of(ctx).profile;
                    await profile.setWho('in_school');
                    if (adult) {
                      if (ctx.mounted) {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(builder: (_) => const ReadyStep()),
                        );
                      }
                    } else {
                      await profile.setTier(
                        Tier.guided,
                      ); // waiting for a class and consent
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        ChoiceCard(
          title: l.whoFinished,
          detail: l.whoFinishedDetail,
          leading: const Icon(Icons.menu_book_outlined, size: 28),
          onTap: () => _push(GoalsStep(tier: tier)),
        ),
        ChoiceCard(
          title: l.whoOther,
          detail: l.whoOtherDetail,
          leading: const Icon(Icons.account_balance_outlined, size: 28),
          onTap: () async {
            final profile = AppScope.of(context).profile;
            await profile.setWho('other');
            await profile.setClassLevel(ProfileController.notInSchool);
            if (adult) {
              _push(const ReadyStep());
            } else {
              await profile.setTier(Tier.guided);
            }
          },
        ),
      ],
    );
  }
}

/// After A3: the age group, then the class link (which, for 13–17, carries the
/// teacher-recorded consent: until then the learner is waiting).
Future<void> finishInSchool(
  BuildContext context,
  Tier tier,
  ClassLink link,
) async {
  final profile = AppScope.of(context).profile;
  await profile.setWho('in_school');
  await profile.setTier(tier);
  await profile.setLink(link);
}

// ---------- Step 4 (finished school): goals (A5); adults change them freely

const examGoals = {'jamb', 'waec'};

class GoalsStep extends StatefulWidget {
  const GoalsStep({super.key, required this.tier, this.inSettings = false});
  final Tier tier;
  final bool inSettings;

  @override
  State<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends State<GoalsStep> {
  late final Set<String> _chosen = {...AppScope.of(context).profile.goals};

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.goalsTitle}. ${l.goalsBody}';
    });
  }

  List<(String, String, String)> _goals(AppLocalizations l) => [
    ('jamb', l.goalJamb, l.goalJambDetail),
    ('waec', l.goalWaec, l.goalWaecDetail),
    ('reading', l.goalReading, l.goalReadingDetail),
    ('skills', l.goalSkills, l.goalSkillsDetail),
    ('papers', l.goalPapers, l.goalPapersDetail),
  ];

  Future<void> _save() async {
    final profile = AppScope.of(context).profile;
    await profile.setGoals(_chosen.toList());
    // Exam practice is at SS3 level; otherwise no class level.
    await profile.setClassLevel(
      _chosen.any(examGoals.contains) ? 'sss3' : ProfileController.notInSchool,
    );
    if (!mounted) return;
    if (widget.inSettings) {
      Navigator.of(context).pop();
      return;
    }
    await profile.setWho('finished');
    if (widget.tier == Tier.standard) {
      if (mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ReadyStep()));
      }
    } else {
      await profile.setTier(Tier.guided);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        if (widget.inSettings)
          ScreenHeader(title: l.goalsTitle, subtitle: l.goalsBody)
        else
          _StepTitle(step: 4, total: 4, title: l.goalsTitle, body: l.goalsBody),
        for (final (id, title, detail) in _goals(l))
          Semantics(
            checked: _chosen.contains(id),
            child: ChoiceCard(
              title: title,
              detail: detail,
              selected: _chosen.contains(id),
              leading: Icon(
                _chosen.contains(id)
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 28,
              ),
              onTap: () => setState(() {
                if (!_chosen.remove(id)) _chosen.add(id);
                AppScope.of(context).speaker.say(title);
              }),
            ),
          ),
        NoteBox(text: l.goalsNote),
      ],
      bottom: [PrimaryButton(label: l.saveLabel, onTap: _save)],
    );
  }
}

// ---------- Step 4: ready (18+) or classroom (under 13)

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
        _StepTitle(step: 4, total: 4, title: l.readyTitle, body: l.readyBody),
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

// ---------- Step 3 (18+ and 13–17): class

/// Without a class code: the level, which picks the practice packs. With a class
/// code, the class's own level is used instead.
class ClassStep extends StatefulWidget {
  const ClassStep({super.key, required this.onChosen, this.adult = false});
  final Future<void> Function(BuildContext context, String level) onChosen;

  /// 18+ may not be in school.
  final bool adult;

  @override
  State<ClassStep> createState() => _ClassStepState();
}

class _ClassStepState extends State<ClassStep> {
  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.classTitle} ${l.classBody}';
    });
  }

  Future<void> _choose(String level) async {
    await AppScope.of(context).profile.setClassLevel(level);
    if (!mounted) return;
    await widget.onChosen(context, level);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        _StepTitle(step: 4, total: 4, title: l.classTitle, body: l.classBody),
        if (widget.adult)
          ChoiceCard(
            title: l.classNotInSchool,
            onTap: () => _choose(ProfileController.notInSchool),
          ),
        ...classLevelChoices(l, onTap: _choose),
      ],
    );
  }
}

/// The levels as choices under "Primary school", "Junior secondary" and
/// "Senior secondary" headings (onboarding and Settings).
List<Widget> classLevelChoices(
  AppLocalizations l, {
  required void Function(String level) onTap,
  String? selected,
}) => [
  for (final (heading, band) in [
    (l.classGroupPrimary, null),
    (l.classGroupJss, Band.jss),
    (l.classGroupSss, Band.sss),
  ]) ...[
    Semantics(
      header: true,
      child: Text(
        heading,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    ),
    for (final level in classLevels.where(
      (lv) => band == null ? lv.band.primary : lv.band == band,
    ))
      ChoiceCard(
        title: level.label,
        // In Settings the current class reads as selected.
        selected: selected == level.id,
        inGroup: selected != null,
        onTap: () => onTap(level.id),
      ),
  ],
];

class ClassroomStep extends StatefulWidget {
  const ClassroomStep({super.key});

  @override
  State<ClassroomStep> createState() => _ClassroomStepState();
}

class _ClassroomStepState extends State<ClassroomStep> {
  String? _level;

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
    final level = _level;
    if (level == null) {
      AppScope.of(context).speaker.say(l.classroomNeedsClass);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.classroomNeedsClass)));
      return;
    }
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
      await profile.setClassLevel(level); // never saved for Classroom
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
          total: 3,
          title: l.classroomTitle,
          body: l.classroomBody,
        ),
        // Kept for this session only, like the session itself.
        Semantics(
          header: true,
          child: Text(
            l.classroomChooseClass,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        for (final level in classLevels.take(7)) // Primary 1 to JSS 1
          ChoiceCard(
            title: level.label,
            selected: _level == level.id,
            inGroup: true,
            leading: Icon(
              _level == level.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 28,
            ),
            onTap: () {
              setState(() => _level = level.id);
              AppScope.of(context).speaker.say(level.label);
            },
          ),
      ],
      bottom: [PrimaryButton(label: l.classroomStart, onTap: _start)],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.step,
    required this.total,
    required this.title,
    required this.body,
  });
  final int? step;
  final int total;
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
            child: ScreenHeader(
              title: step == null ? '' : l.stepOf(step!, total),
            ),
          ),
        if (!Navigator.of(context).canPop() && step != null)
          Text(
            l.stepOf(step!, total),
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
