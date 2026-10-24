import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets.dart';

/// The credit lines the N-ATLaS Terms of Use v1.0 require "in all public use", quoted
/// verbatim from each model card (docs/MODELS.md). Kept in English: they are quotations.
const natlasAttribution =
    'N-ATLaS is an initiative of the Federal Ministry of Communications, Innovation '
    'and Digital Economy, and powered by Awarri Technologies.';
const asrAttributions = [
  'Hausa-ASR is powered by Awarri Technologies in an initiative of the Federal '
      'Ministry of Communications, Innovation and Digital Economy',
  'Yoruba-ASR is developed by Awarri Technologies in partnership with the Federal '
      'Government of Nigeria.',
  'Igbo-ASR is powered by Awarri Technologies in an initiative of the Federal '
      'Ministry of Communications, Innovation and Digital Economy.',
  'NigerianAccentedEnglish is powered by Awarri Technologies and an initiative of the '
      'Federal Ministry of Communications, Innovation and Digital Economy.',
];

/// Where testers and users write to (also in docs/PRIVACY.md and docs/TESTER_INSTALL.md).
const supportEmail = 'maganasupport@gmail.com';

const termsCondition =
    'Awarri Technologies and the Federal Ministry of Communications, Innovation and '
    'Digital Economy.';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.version});
  final String? version;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget heading(String text) => Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
    return PageScaffold(
      body: [
        ScreenHeader(title: l.aboutTitle, subtitle: version),
        NoteBox(text: l.aboutContact(supportEmail)),
        heading(l.aboutModels),
        NoteBox(text: l.aboutModelsNote),
        heading('${l.aboutExplain}: N-ATLaS (NCAIR1/N-ATLaS)'),
        NoteBox(text: natlasAttribution),
        heading(
          '${l.aboutSpeech}: NCAIR1 Hausa-ASR, Yoruba-ASR, Igbo-ASR, NigerianAccentedEnglish',
        ),
        for (final line in asrAttributions) NoteBox(text: line),
        NoteBox(text: termsCondition),
        SecondaryButton(
          label: l.openSourceLicences,
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Magana',
            applicationVersion: version,
          ),
        ),
      ],
    );
  }
}
