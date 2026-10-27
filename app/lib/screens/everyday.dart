import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../papers.dart';
import '../policy.dart';
import '../widgets.dart';
import 'capture.dart';
import 'health_worker.dart';
import 'pdf.dart';
import 'reminders.dart';

/// Everyday papers hub (18+): medicine labels, medical reports, bank statements.
class EverydayScreen extends StatefulWidget {
  const EverydayScreen({super.key});

  @override
  State<EverydayScreen> createState() => _EverydayScreenState();
}

class _EverydayScreenState extends State<EverydayScreen> {
  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.everydayPapers}. ${l.everydaySubtitle}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = AppScope.of(context).profile;
    if (!profile.can(Feature.everydayHealth)) return const AdultsOnlyScreen();
    return PageScaffold(
      sayName: true,
      body: [
        ScreenHeader(title: l.everydayPapers, subtitle: l.everydaySubtitle),
        if (profile.can(Feature.everydayLetters))
          ChoiceCard(
            title: l.readAnyPaper,
            detail: l.readAnyPaperDetail,
            selected: true, // the design's highlighted first choice
            leading: const Icon(Icons.document_scanner_outlined, size: 34),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CaptureScreen(detect: true),
              ),
            ),
          ),
        if (profile.can(Feature.everydayLetters))
          ChoiceCard(
            title: l.readPdf,
            detail: l.readPdfDetail,
            leading: const Icon(Icons.picture_as_pdf_outlined, size: 34),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const PdfScreen())),
          ),
        for (final paper in Paper.values)
          if (profile.can(paper.feature))
            ChoiceCard(
              title: paper.title(l),
              detail: paper.detail(l),
              leading: Icon(paper.icon, size: 34),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CaptureScreen(paper: paper)),
              ),
            ),
        if (profile.can(Feature.reminders))
          ChoiceCard(
            title: l.remindersCard,
            detail: l.remindersCardDetail,
            leading: const Icon(Icons.alarm, size: 34),
            onTap: () => openReminders(context),
          ),
        if (profile.can(Feature.healthCallback))
          ChoiceCard(
            title: l.talkToNurse,
            detail: l.talkToNurseDetail,
            leading: const Icon(Icons.support_agent, size: 34),
            onTap: () => openHealthWorker(context),
          ),
        NoteBox(text: l.everydayPrivacy, kind: NoteKind.privacy),
        const EmergencyBanner(),
      ],
    );
  }
}

/// Shown if an under-18 profile ever reaches an adults-only screen.
class AdultsOnlyScreen extends StatelessWidget {
  const AdultsOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    speakOnOpen(context, () => l.adultsOnly);
    return PageScaffold(
      body: [
        ScreenHeader(title: l.everydayPapers),
        NoteBox(text: l.adultsOnly, kind: NoteKind.warning),
      ],
    );
  }
}
