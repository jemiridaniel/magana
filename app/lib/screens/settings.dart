import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../widgets.dart';
import 'home.dart';

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
