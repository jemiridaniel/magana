import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../policy.dart';
import '../speech.dart';
import '../theme.dart';
import '../widgets.dart';
import '../commands.dart';
import '../layout.dart';
import '../voice_input.dart';
import 'capture.dart';
import 'explain.dart';
import 'health_worker.dart';
import 'reminders.dart';
import 'settings.dart';
import 'everyday.dart';
import 'library.dart';
import 'pdf.dart';
import 'quiz_list.dart';
import 'report_problem.dart';
import 'score.dart';
import 'skills.dart';
import 'touch_intro.dart';
import '../touch.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Set up before Touch to hear existed, screen reader off: the practice once (board 10b).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !shouldIntroduceTouch(context)) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TouchIntroScreen(onDone: (c) => Navigator.of(c).pop()),
        ),
      );
    });
    // "Magana. 7 choices. Touch to explore, or say a name." (board 10)
    speakOnOpen(context, () => AppLocalizations.of(context).appTitle);
  }

  void _openCapture(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CaptureScreen()));
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final can = AppScope.of(context).profile.can;
    final tablet = isTablet(context);
    // Only what this age tier may use: a screen-reader user never
    // reaches a dead end (CLAUDE.md rule 4).
    final tiles = [
      if (can(Feature.openChat))
        _Tile(
          Icons.help_outline,
          l.askQuestion,
          () => _open(const ExplainScreen(lines: [], source: '')),
        ),
      if (can(Feature.quiz))
        _Tile(
          Icons.task_alt,
          l.practiceQuiz,
          () => _open(const QuizListScreen()),
        ),
      if (can(Feature.library))
        _Tile(
          Icons.menu_book_outlined,
          l.myLibrary,
          () => _open(const LibraryScreen()),
        ),
      // Board T1: a PDF is one tap away on a tablet's larger home.
      if (tablet && can(Feature.everydayLetters))
        _Tile(
          Icons.picture_as_pdf_outlined,
          l.readPdf,
          () => _open(const PdfScreen()),
        ),
      if (can(Feature.everydayHealth))
        _Tile(
          Icons.description_outlined,
          l.everydayPapers,
          () => _open(const EverydayScreen()),
        ),
    ];
    final chips = [
      if (can(Feature.skills))
        _Tile(
          Icons.school_outlined,
          l.skills,
          () => _open(const SkillsScreen()),
        ),
      if (can(Feature.score))
        _Tile(Icons.trending_up, l.myScore, () => _open(const ScoreScreen())),
    ];
    final pad = tablet
        ? const EdgeInsets.fromLTRB(40, 40, 40, 36)
        : const EdgeInsets.fromLTRB(20, 24, 20, 20);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: pad,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (box.maxHeight - pad.vertical).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onSettings: () => _open(const SettingsScreen())),
                    const SizedBox(height: 20),
                    // Waiting for the guardian (13–17), or removed by the teacher.
                    ListenableBuilder(
                      listenable: AppScope.of(context).profile,
                      builder: (context, _) {
                        final profile = AppScope.of(context).profile;
                        final note = profile.waitingForConsent
                            ? l.waitingBanner
                            : profile.removedFromClass
                            ? l.removedNotice
                            : null;
                        if (note == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: NoteBox(text: note),
                        );
                      },
                    ),
                    _ReadPageButton(onPressed: () => _openCapture(context)),
                    SizedBox(height: tablet ? 18 : 14),
                    if (tablet)
                      // Board T1: one 3-column grid, skills and score included.
                      _TileGrid(tiles: [...tiles, ...chips], columns: 3)
                    else ...[
                      _TileGrid(tiles: tiles),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (final (i, c) in chips.indexed) ...[
                            if (i > 0) const SizedBox(width: 14),
                            Expanded(
                              child: _Chip(c.icon, c.label, c.onPressed),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 20),
                    const _SpeakButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = languageFor(Localizations.localeOf(context));
    final tablet = isTablet(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/brand/magana_mark.svg',
                      width: tablet ? 44 : 36,
                      height: tablet ? 44 : 36,
                      // The name is read with the greeting, as one heading ("Magana,
                      // Hello"): TalkBack read the mark as a separate "Magana, image".
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.appTitle,
                        style: TextStyle(
                          fontSize: tablet ? 38 : 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l.greeting,
                  style: TextStyle(
                    fontSize: tablet ? 20 : 16,
                    color: MaganaColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        Labelled(
          label: l.languageButtonLabel(language.name),
          onTap: () => showLanguagePicker(context),
          radius: 32,
          child: OutlinedButton(
            onPressed: () => showLanguagePicker(context),
            style: outlinedTile(radius: 32).copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(language.name),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Labelled(
          label: l.settings,
          onTap: onSettings,
          radius: 32,
          child: OutlinedButton(
            onPressed: onSettings,
            style: outlinedTile(radius: 32).copyWith(
              padding: WidgetStatePropertyAll(
                tablet
                    ? const EdgeInsets.symmetric(horizontal: 22)
                    : EdgeInsets.zero,
              ),
            ),
            // Board T1: the word itself on a tablet, there is room for it.
            child: tablet
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 28),
                      const SizedBox(width: 8),
                      Text(l.settings),
                    ],
                  )
                : const Icon(Icons.tune, size: 28),
          ),
        ),
      ],
    );
  }
}

/// The app-language sheet (design 3b): each option says its own welcome word and
/// is heard in its own language; "Use [language]" applies the choice.
Future<void> showLanguagePicker(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: MaganaColors.ground,
  // TalkBack lands on the sheet's question, not a "Dismiss" handle above it.
  showDragHandle: !screenReaderOn(context),
  builder: (_) => const LanguageSheet(),
);

class LanguageSheet extends StatefulWidget {
  const LanguageSheet({super.key});

  @override
  State<LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<LanguageSheet> {
  late final String _current = Localizations.localeOf(context).languageCode;
  late String _chosen = _current;
  bool _applied = false;
  late Speaker _speaker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speaker = AppScope.of(context).speaker;
  }

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.appLanguageTitle}. ${l.languageSheetBody}';
    });
  }

  @override
  void dispose() {
    // Closed without "Use": the voice goes back to the app language.
    if (!_applied) _speaker.setLanguage(_current);
    super.dispose();
  }

  Future<void> _hear(AppLanguage lang) async {
    setState(() => _chosen = lang.code);
    await _speaker.setLanguage(lang.code);
    await _speaker.say(
      '${lang.name}. ${lookupAppLocalizations(Locale(lang.code)).welcome}',
    );
  }

  Future<void> _use() async {
    // Said after the sheet closes: the app's own voice, not the sheet's.
    final scope = AppScope.app(context);
    final lang = appLanguages.firstWhere((a) => a.code == _chosen);
    _applied = true;
    Navigator.of(context).pop();
    await scope.language.select(lang.code);
    await scope.speaker.setLanguage(lang.code);
    await scope.speaker.say(
      lookupAppLocalizations(Locale(lang.code)).languageChanged(lang.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chosen = appLanguages.firstWhere((a) => a.code == _chosen);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.appLanguageTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.languageSheetBody,
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                l.chooseLanguage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final lang in appLanguages) ...[
              ChoiceCard(
                title: lang.name,
                detail: lookupAppLocalizations(Locale(lang.code)).welcome,
                selected: lang.code == _chosen,
                inGroup: true,
                leading: Icon(
                  lang.code == _chosen
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 28,
                ),
                onTap: () => _hear(lang),
              ),
              const SizedBox(height: 10),
            ],
            NoteBox(text: l.languageVoiceTip),
            const SizedBox(height: 14),
            PrimaryButton(label: l.useLanguage(chosen.name), onTap: _use),
          ],
        ),
      ),
    );
  }
}

class _ReadPageButton extends StatelessWidget {
  const _ReadPageButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Health and money papers are for adults only; don't promise them to under-18s.
    final tablet = isTablet(context);
    // Board T1: on a tablet, how to hold it.
    final subtitle = tablet
        ? l.readPageTablet
        : AppScope.of(context).profile.can(Feature.everydayHealth)
        ? l.readPageSubtitle
        : l.readPageSubtitleSchool;
    return Labelled(
      label: '${l.readPage}. $subtitle',
      onTap: onPressed,
      radius: tablet ? 28 : 22,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: MaganaColors.green,
          foregroundColor: Colors.white,
          minimumSize: Size.fromHeight(tablet ? 200 : 140),
          padding: EdgeInsets.symmetric(
            horizontal: tablet ? 32 : 22,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tablet ? 28 : 22),
          ),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Icon(Icons.photo_camera_outlined, size: tablet ? 64 : 44),
            SizedBox(width: tablet ? 24 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.readPage,
                    style: TextStyle(
                      fontSize: tablet ? 34 : 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: tablet ? 20 : 17,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.icon, this.label, this.onPressed);
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles, this.columns = 2});
  final List<_Tile> tiles;

  /// 2 on a phone; 3 on a tablet, with larger tiles (board T1).
  final int columns;

  @override
  Widget build(BuildContext context) {
    final big = columns > 2;
    final gap = big ? 18.0 : 14.0;
    Widget tile(_Tile t) => Expanded(
      child: Labelled(
        label: t.label,
        onTap: t.onPressed,
        radius: big ? 24 : 20,
        child: OutlinedButton(
          onPressed: t.onPressed,
          style: outlinedTile(radius: big ? 24 : 20).copyWith(
            minimumSize: WidgetStatePropertyAll(
              Size.fromHeight(big ? 170 : 128),
            ),
            alignment: Alignment.topLeft,
            padding: WidgetStatePropertyAll(
              big
                  ? const EdgeInsets.all(24)
                  : const EdgeInsets.fromLTRB(18, 20, 18, 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(t.icon, size: big ? 40 : 34),
              const SizedBox(height: 12),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: big ? 24 : 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += columns) ...[
          if (i > 0) SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns; j++) ...[
                  if (j > i) SizedBox(width: gap),
                  if (j < tiles.length) tile(tiles[j]) else const Spacer(),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label, this.onPressed);
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Labelled(
      label: label,
      onTap: onPressed,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: MaganaColors.chip,
          foregroundColor: MaganaColors.ink,
          minimumSize: const Size.fromHeight(72),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Speak a command": one spoken command reaches every main action (fixed
/// keyword rules in commands.dart; English for now). Tap, not hold, so it works
/// with TalkBack's double tap.
class _SpeakButton extends StatefulWidget {
  const _SpeakButton();

  @override
  State<_SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<_SpeakButton> {
  late final VoiceInput _voice = voiceInputFor(context);
  bool? _works;
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) _voice.stop();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    final l = AppLocalizations.of(context);
    final speaker = AppScope.of(context).speaker;
    _works ??= await _voice.init();
    if (!mounted) return;
    if (_works != true) {
      speaker.say(l.voiceCommandsUnavailable);
      return;
    }
    await speaker.stop();
    setState(() => _listening = true);
    // Commands are English keywords for now.
    final List<String> heard;
    try {
      heard = await _voice.listen(language: 'en');
    } on VoiceStepFailed {
      // No recogniser this account may use: tap instead.
      if (!mounted) return;
      setState(() => _listening = false);
      speaker.say(l.voiceCommandsUnavailable);
      return;
    }
    if (!mounted) return;
    setState(() => _listening = false);
    if (heard.isEmpty) {
      speaker.say(l.commandSorry);
      return;
    }
    runCommand(context, heard.first);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = _listening ? l.listeningCommand : l.speakCommand;
    final tablet = isTablet(context);
    return Labelled(
      label: label,
      onTap: _tap,
      counted: false,
      radius: tablet ? 44 : 38,
      child: OutlinedButton.icon(
        onPressed: _tap,
        icon: Icon(
          _listening ? Icons.stop : Icons.mic_none,
          size: tablet ? 34 : 30,
        ),
        label: Text(label),
        style: outlinedTile(radius: tablet ? 44 : 38, bg: MaganaColors.amber)
            .copyWith(
              minimumSize: WidgetStatePropertyAll(
                Size.fromHeight(tablet ? 88 : 76),
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: MaganaColors.ink, width: 3),
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontFamily: fontFamily,
                  fontFamilyFallback: fontFallback,
                  fontSize: tablet ? 24 : 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      ),
    );
  }
}

/// Carries out a spoken command; unknown or not-allowed ones are said back.
void runCommand(BuildContext context, String transcript) {
  final l = AppLocalizations.of(context);
  final scope = AppScope.of(context);
  final can = scope.profile.can;
  void open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  switch (matchCommand(transcript, can)) {
    // Not a command: the name of something on Home ("my library"), else not understood.
    case null when scope.touch.openByName(ModalRoute.of(context), transcript):
      break;
    case null:
      scope.speaker.say(l.commandSorry);
    case VoiceCommand.readPage:
      open(const CaptureScreen());
    case VoiceCommand.everyday:
      open(const EverydayScreen());
    case VoiceCommand.reminders:
      openReminders(context);
    case VoiceCommand.nurse:
      openHealthWorker(context);
    case VoiceCommand.quiz:
      open(const QuizListScreen());
    case VoiceCommand.library:
      open(const LibraryScreen());
    case VoiceCommand.skills:
      open(const SkillsScreen());
    case VoiceCommand.score:
      open(const ScoreScreen());
    case VoiceCommand.ask:
      open(const ExplainScreen(lines: [], source: ''));
    case VoiceCommand.settings:
      open(const SettingsScreen());
    case VoiceCommand.report:
      openReportProblem(context, screen: 'home');
    case VoiceCommand.language:
      final lang = namedLanguage(transcript);
      if (lang == null) {
        showLanguagePicker(context);
      } else {
        scope.language.select(lang.code);
        scope.speaker
            .setLanguage(lang.code)
            .then(
              (_) => scope.speaker.say(
                lookupAppLocalizations(Locale(lang.code))
                    .languageChanged(lang.name),
              ),
            );
      }
    case VoiceCommand.help:
      final names = <VoiceCommand, String>{
        VoiceCommand.readPage: l.readPage,
        VoiceCommand.everyday: l.everydayPapers,
        VoiceCommand.reminders: l.remindersCard,
        VoiceCommand.nurse: l.talkToNurse,
        VoiceCommand.quiz: l.practiceQuiz,
        VoiceCommand.library: l.myLibrary,
        VoiceCommand.skills: l.skills,
        VoiceCommand.score: l.myScore,
        VoiceCommand.ask: l.askQuestion,
        VoiceCommand.language: l.changeLanguageCommand,
        VoiceCommand.settings: l.settings,
        VoiceCommand.report: l.reportProblem,
      };
      scope.speaker.say(
        l.commandHelp(
          [
            for (final MapEntry(key: c, value: name) in names.entries)
              if (c.feature == null || can(c.feature!)) name,
          ].join(', '),
        ),
      );
  }
}
