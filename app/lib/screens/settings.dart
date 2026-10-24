import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../policy.dart';
import '../profile.dart';
import '../widgets.dart';
import 'about.dart';
import 'home.dart';
import 'onboarding.dart' show classLevelChoices;

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
    if (profile.classLevel == ProfileController.notInSchool) {
      return l.classNotInSchool;
    }
    return profile.level?.name;
  }

  /// The class is chosen once in onboarding; afterwards only a teacher should
  /// change it. Until teachers sign in, the app takes their word for it.
  Future<void> _changeClass() async {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    scope.speaker.say(l.changeClassConfirmTitle);
    final teacher = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l.changeClassConfirmTitle,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        actions: [
          SecondaryButton(
            label: l.cancel,
            onTap: () => Navigator.of(dialog).pop(false),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: l.changeClassYes,
            onTap: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (teacher != true || !mounted) return;
    final profile = scope.profile;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (page) => PageScaffold(
          body: [
            ScreenHeader(title: l.settingsClass),
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = languageFor(Localizations.localeOf(context));
    final v = _version;
    return PageScaffold(
      body: [
        ScreenHeader(title: l.settings),
        ChoiceCard(
          title: l.appLanguageTitle,
          detail: language.name,
          leading: const Icon(Icons.translate, size: 30),
          onTap: () => showLanguagePicker(context),
        ),
        ChoiceCard(
          title: l.settingsClass,
          detail: [
            _className(l),
            l.settingsChangeClass,
          ].whereType<String>().join('. '),
          leading: const Icon(Icons.school_outlined, size: 30),
          onTap: _changeClass,
        ),
        if (v != null) ...[
          Semantics(
            header: true,
            child: Text(
              l.settingsVersion(v.version, v.build),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
        NoteBox(text: l.reportHow),
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
              l.reportHow,
            ].join(' '),
          ),
        ),
      ],
    );
  }
}
