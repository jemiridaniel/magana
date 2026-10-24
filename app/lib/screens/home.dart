import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../policy.dart';
import '../theme.dart';
import 'capture.dart';
import 'everyday.dart';
import 'quiz.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCapture(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CaptureScreen()));
  }

  void _comingSoon(BuildContext context, String feature) {
    final msg = AppLocalizations.of(context).comingSoon(feature);
    AppScope.of(context).speaker.say(msg);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontSize: 18))),
      );
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
                    _Header(onSettings: () => _comingSoon(context, l.settings)),
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
                            () => _comingSoon(context, l.askQuestion),
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
                            soon: false,
                          ),
                        if (can(Feature.library))
                          _Tile(
                            Icons.menu_book_outlined,
                            l.myLibrary,
                            () => _comingSoon(context, l.myLibrary),
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
                            soon: false,
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
                              () => _comingSoon(context, l.skills),
                            ),
                          ),
                        if (can(Feature.skills) && can(Feature.score))
                          const SizedBox(width: 14),
                        if (can(Feature.score))
                          Expanded(
                            child: _Chip(
                              Icons.trending_up,
                              l.myScore,
                              () => _comingSoon(context, l.myScore),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 20),
                    _SpeakButton(
                      onPressed: () => _comingSoon(context, l.voiceCommands),
                    ),
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
          hint: l.comingSoonHint,
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

/// Bottom sheet with one large option per language; the choice is saved and spoken in the new language.
Future<void> showLanguagePicker(BuildContext context) {
  final scope = AppScope.of(context);
  final current = Localizations.localeOf(context).languageCode;
  Future<void> choose(AppLanguage lang) async {
    Navigator.of(context).pop();
    await scope.language.select(lang.code);
    await scope.speaker.setLanguage(lang.code);
    await scope.speaker.say(
      lookupAppLocalizations(Locale(lang.code)).languageChanged(lang.name),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MaganaColors.ground,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                AppLocalizations.of(sheet).chooseLanguage,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final lang in appLanguages) ...[
              Semantics(
                button: true,
                selected: lang.code == current,
                inMutuallyExclusiveGroup: true,
                label: lang.name,
                excludeSemantics: true,
                onTap: () => choose(lang),
                child: OutlinedButton(
                  onPressed: () => choose(lang),
                  style: outlinedTile(
                    bg: lang.code == current ? MaganaColors.ink : Colors.white,
                    fg: lang.code == current ? Colors.white : MaganaColors.ink,
                  ).copyWith(alignment: Alignment.centerLeft),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang.name,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      if (lang.code == current)
                        const Icon(Icons.check, size: 28),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
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
  const _Tile(this.icon, this.label, this.onPressed, {this.soon = true});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool soon; // not built yet: TalkBack says "Coming soon"
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final hint = AppLocalizations.of(context).comingSoonHint;
    Widget tile(_Tile t) => Expanded(
      child: Semantics(
        button: true,
        label: t.label,
        hint: t.soon ? hint : null,
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
      hint: AppLocalizations.of(context).comingSoonHint,
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

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.holdToSpeakLabel,
      hint: l.comingSoonHint,
      excludeSemantics: true,
      onTap: onPressed,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.mic_none, size: 30),
        label: Text(l.holdToSpeak),
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
