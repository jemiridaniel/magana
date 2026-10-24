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
import '../voice_input.dart';
import 'capture.dart';
import 'explain.dart';
import 'health_worker.dart';
import 'reminders.dart';
import 'settings.dart';
import 'everyday.dart';
import 'library.dart';
import 'quiz.dart';
import 'score.dart';
import 'skills.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCapture(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CaptureScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final can = AppScope.of(context).profile.can;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 44),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      onSettings: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ReadPageButton(onPressed: () => _openCapture(context)),
                    const SizedBox(height: 14),
                    // Only what this age tier may use: a screen-reader user never
                    // reaches a dead end (CLAUDE.md rule 4).
                    _TileGrid(
                      tiles: [
                        if (can(Feature.openChat))
                          _Tile(
                            Icons.help_outline,
                            l.askQuestion,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ExplainScreen(lines: [], source: ''),
                              ),
                            ),
                          ),
                        if (can(Feature.quiz))
                          _Tile(
                            Icons.task_alt,
                            l.practiceQuiz,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QuizScreen(),
                              ),
                            ),
                          ),
                        if (can(Feature.library))
                          _Tile(
                            Icons.menu_book_outlined,
                            l.myLibrary,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LibraryScreen(),
                              ),
                            ),
                          ),
                        if (can(Feature.everydayHealth))
                          _Tile(
                            Icons.description_outlined,
                            l.everydayPapers,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EverydayScreen(),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (can(Feature.skills))
                          Expanded(
                            child: _Chip(
                              Icons.school_outlined,
                              l.skills,
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SkillsScreen(),
                                ),
                              ),
                            ),
                          ),
                        if (can(Feature.skills) && can(Feature.score))
                          const SizedBox(width: 14),
                        if (can(Feature.score))
                          Expanded(
                            child: _Chip(
                              Icons.trending_up,
                              l.myScore,
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScoreScreen(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                      width: 36,
                      height: 36,
                      semanticsLabel: 'Magana',
                    ),
                    const SizedBox(width: 8),
                    // The mark already announces "Magana"; don't read the name twice.
                    Flexible(
                      child: ExcludeSemantics(
                        child: Text(
                          l.appTitle,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l.greeting,
                  style: const TextStyle(
                    fontSize: 16,
                    color: MaganaColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          label: l.languageButtonLabel(language.name),
          excludeSemantics: true,
          onTap: () => showLanguagePicker(context),
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
        Semantics(
          button: true,
          label: l.settings,
          excludeSemantics: true,
          onTap: onSettings,
          child: OutlinedButton(
            onPressed: onSettings,
            style: outlinedTile(
              radius: 32,
            ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
            child: const Icon(Icons.tune, size: 28),
          ),
        ),
      ],
    );
  }
}

/// The app-language sheet (design 3b): each option says its own welcome word and
/// is heard in its own language; "Use [language]" applies the choice.
Future<void> showLanguagePicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MaganaColors.ground,
      showDragHandle: true,
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
    final scope = AppScope.of(context);
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
    final subtitle = AppScope.of(context).profile.can(Feature.everydayHealth)
        ? l.readPageSubtitle
        : l.readPageSubtitleSchool;
    return Semantics(
      button: true,
      label: '${l.readPage}. $subtitle',
      excludeSemantics: true,
      onTap: onPressed,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: MaganaColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(140),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_camera_outlined, size: 44),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.readPage,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 17,
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
  const _TileGrid({required this.tiles});
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    Widget tile(_Tile t) => Expanded(
      child: Semantics(
        button: true,
        label: t.label,
        excludeSemantics: true,
        onTap: t.onPressed,
        child: OutlinedButton(
          onPressed: t.onPressed,
          style: outlinedTile(radius: 20).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(128)),
            alignment: Alignment.topLeft,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.fromLTRB(18, 20, 18, 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(t.icon, size: 34),
              const SizedBox(height: 12),
              Text(
                t.label,
                style: const TextStyle(
                  fontSize: 21,
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
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile(tiles[i]),
                const SizedBox(width: 14),
                if (i + 1 < tiles.length)
                  tile(tiles[i + 1])
                else
                  const Spacer(),
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
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
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
      speaker.say(l.commandNothingHeard);
      return;
    }
    runCommand(context, heard.first);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = _listening ? l.listeningCommand : l.speakCommand;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: _tap,
      child: OutlinedButton.icon(
        onPressed: _tap,
        icon: Icon(_listening ? Icons.stop : Icons.mic_none, size: 30),
        label: Text(label),
        style: outlinedTile(radius: 38, bg: MaganaColors.amber).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(76)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: MaganaColors.ink, width: 3),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
              fontSize: 21,
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
    case null:
      scope.speaker.say(l.commandNotUnderstood(transcript));
    case VoiceCommand.readPage:
      open(const CaptureScreen());
    case VoiceCommand.everyday:
      open(const EverydayScreen());
    case VoiceCommand.reminders:
      openReminders(context);
    case VoiceCommand.nurse:
      openHealthWorker(context);
    case VoiceCommand.quiz:
      open(const QuizScreen());
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
