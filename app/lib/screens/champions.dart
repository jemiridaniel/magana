import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../lessons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'score.dart';

/// Magana Champions: a sample Champion profile (no programme yet) and the
/// steps to become one, ticked from the learner's real progress.
class ChampionsScreen extends StatefulWidget {
  const ChampionsScreen({super.key});

  @override
  State<ChampionsScreen> createState() => _ChampionsScreenState();
}

class _ChampionsScreenState extends State<ChampionsScreen> {
  List<(String, bool)>? _steps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final progress = await LessonProgress.load();
      if (!mounted) return;
      final score = await loadScore(context);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(
        () => _steps = [
          (l.champStepBasics, progress.doneId('talkback-basics')),
          (l.champStepPhotos, progress.doneId('clear-photos')),
          (l.champStepScore, score.overall >= 60),
          (l.champStepTraining, false), // training is not running yet
          (l.champStepHelp, false),
        ],
      );
      AppScope.of(context).speaker.say(
        '${l.championsTitle}. ${l.championsSubtitle}. ${l.championNotYet}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.championsTitle,
          subtitle: l.championsSubtitle,
          introduce: true,
        ),
        Semantics(
          container: true,
          label: '${l.championSample}. Musa Abdullahi. ${l.championDetail}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MaganaColors.green, width: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.championSample.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MaganaColors.green,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFE3F1EA),
                      child: Text(
                        'MA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF063D2A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Musa Abdullahi',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l.championDetail,
                            style: const TextStyle(
                              fontSize: 16,
                              color: MaganaColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        NoteBox(text: l.championNotYet),
        Semantics(
          header: true,
          child: Text(
            l.becomeChampion,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
        ),
        Text(l.becomeChampionBody, style: const TextStyle(fontSize: 17)),
        for (final (step, done) in _steps ?? const <(String, bool)>[])
          Semantics(
            label: '$step, ${done ? l.stepDone : l.stepNotDone}',
            excludeSemantics: true,
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 26,
                  color: done ? MaganaColors.green : MaganaColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(step, style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        NoteBox(text: l.championsPartnerNote),
      ],
    );
  }
}
