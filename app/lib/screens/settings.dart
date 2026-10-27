import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../policy.dart';
import '../profile.dart';
import '../theme.dart';
import '../widgets.dart';
import 'about.dart';
import 'home.dart';
import 'class_code.dart';
import 'diagnostics.dart';
import 'onboarding.dart' show GoalsStep, classLevelChoices;
import 'report_problem.dart';

/// The installed build's version; replaceable in tests.
Future<({String version, String build})> Function() appVersion = () async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, build: info.buildNumber);
};

/// Settings: app language, the version testers report, and how to report a problem.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ({String version, String build})? _version;
  int _versionTaps = 0; // 7 taps on the version: diagnostics

  @override
  void initState() {
    super.initState();
    appVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
    speakOnOpen(context, () => AppLocalizations.of(context).settings);
  }

  String? _className(AppLocalizations l) {
    final profile = AppScope.of(context).profile;
    final link = profile.link;
    if (link != null) return link.className;
    if (profile.classLevel == ProfileController.notInSchool) {
      return l.classNotInSchool;
    }
    return profile.level?.name;
  }

  /// A 13–17 learner linked to a class changes class only with their teacher's
  /// own code (checked by the backend, A4). Everyone else joins a class with
  /// its code; without one, they pick a level for the practice packs.
  Future<void> _changeClass() async {
    final scope = AppScope.of(context);
    final profile = scope.profile;
    final Widget screen;
    if (profile.link != null && profile.tier == Tier.guided) {
      screen = const TeacherCodeScreen();
    } else {
      screen = JoinClassScreen(
        tier: profile.tier ?? Tier.standard,
        onJoined: (page, link) async {
          await profile.setWho('in_school');
          await profile.setLink(link);
          if (page.mounted) Navigator.of(page).pop();
        },
        onNoCode: profile.link == null ? _pickLevel : null,
      );
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  /// Without a class code: the level for practice packs.
  Future<void> _pickLevel() async {
    final l = AppLocalizations.of(context);
    final profile = AppScope.of(context).profile;
    final nav = Navigator.of(context);
    await nav.push(
      MaterialPageRoute(
        builder: (page) => PageScaffold(
          body: [
            ScreenHeader(title: l.practiceLevelTitle),
            if (profile.tier == Tier.standard)
              ChoiceCard(
                title: l.classNotInSchool,
                selected: profile.classLevel == ProfileController.notInSchool,
                inGroup: true,
                onTap: () async {
                  await profile.setClassLevel(ProfileController.notInSchool);
                  if (page.mounted) Navigator.of(page).pop();
                },
              ),
            ...classLevelChoices(
              l,
              selected: profile.classLevel ?? '',
              onTap: (level) async {
                await profile.setClassLevel(level);
                if (page.mounted) Navigator.of(page).pop();
              },
            ),
          ],
        ),
      ),
    );
    nav.pop(); // back to Settings from the join screen
  }

  String _goalNames(AppLocalizations l, List<String> goals) => [
    for (final g in goals)
      switch (g) {
        'jamb' => l.goalJamb,
        'waec' => l.goalWaec,
        'reading' => l.goalReading,
        'skills' => l.goalSkills,
        _ => l.goalPapers,
      },
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = languageFor(Localizations.localeOf(context));
    final v = _version;
    final profile = AppScope.of(context).profile;
    return PageScaffold(
      sayName: true,
      body: [
        ScreenHeader(title: l.settings),
        ChoiceCard(
          title: l.appLanguageTitle,
          detail: language.name,
          leading: const Icon(Icons.translate, size: 30),
          onTap: () => showLanguagePicker(context),
        ),
        const TouchToHearSwitch(),
        ChoiceCard(
          title: l.settingsClass,
          detail: [
            _className(l),
            profile.link != null && profile.tier == Tier.guided
                ? l.settingsChangeClass
                : l.changeClassTitle,
          ].whereType<String>().join('. '),
          leading: const Icon(Icons.school_outlined, size: 30),
          onTap: _changeClass,
        ),
        if (profile.tier == Tier.standard && profile.who == 'finished')
          ChoiceCard(
            title: l.settingsGoals,
            detail: profile.goals.isEmpty ? null : _goalNames(l, profile.goals),
            leading: const Icon(Icons.flag_outlined, size: 30),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const GoalsStep(tier: Tier.standard, inSettings: true),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
        if (v != null) ...[
          // Tapped 7 times: the hidden diagnostics screen, for testing on real phones.
          GestureDetector(
            onTap: () {
              if (++_versionTaps < 7) return;
              _versionTaps = 0;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiagnosticsScreen(
                    version: l.settingsVersion(v.version, v.build),
                  ),
                ),
              );
            },
            child: Semantics(
              header: true,
              child: Text(
                l.settingsVersion(v.version, v.build),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          NoteBox(text: l.settingsVersionNote),
        ],
        Semantics(
          header: true,
          child: Text(
            l.reportProblem,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        ChoiceCard(
          title: l.reportProblem,
          detail: l.reportGoesTo,
          leading: const Icon(Icons.flag_circle_outlined, size: 30),
          onTap: () => openReportProblem(context, screen: 'settings'),
        ),
        SecondaryButton(
          label: l.emailSupport(supportEmail),
          onTap: emailSupport,
        ),
        NoteBox(text: l.privacyNote, kind: NoteKind.privacy),
        ChoiceCard(
          title: l.aboutTitle,
          detail: l.aboutModels,
          leading: const Icon(Icons.info_outline, size: 30),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AboutScreen(
                version: v == null
                    ? null
                    : l.settingsVersion(v.version, v.build),
              ),
            ),
          ),
        ),
        SecondaryButton(
          label: l.hearAgain,
          onTap: () => AppScope.of(context).speaker.say(
            [
              if (v != null) l.settingsVersion(v.version, v.build),
              '${l.reportProblem}. ${l.reportGoesTo}.',
            ].join(' '),
          ),
        ),
      ],
    );
  }
}

/// Touch to hear on or off (board 10). Off makes no difference while VoiceOver or TalkBack
/// is on: the screen reader does it then.
class TouchToHearSwitch extends StatelessWidget {
  const TouchToHearSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final touch = scope.touch;
    return ListenableBuilder(
      listenable: touch,
      builder: (context, _) {
        void flip() {
          touch.set(!touch.on);
          scope.speaker.say(touch.on ? l.touchToHearOn : l.touchToHearOff);
        }

        return Labelled(
          label: l.touchToHear,
          hint: l.touchToHearDetail,
          toggled: touch.on,
          onTap: flip,
          radius: 18,
          child: SwitchListTile(
            value: touch.on,
            onChanged: (_) => flip(),
            secondary: const Icon(Icons.touch_app_outlined, size: 30),
            title: Text(
              l.touchToHear,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              l.touchToHearDetail,
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
            minTileHeight: 72,
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: MaganaColors.ink, width: 3),
            ),
          ),
        );
      },
    );
  }
}
