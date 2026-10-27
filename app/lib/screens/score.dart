import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../tasks.dart';
import '../theme.dart';
import '../widgets.dart';

String areaName(AppLocalizations l, Area area) => switch (area) {
  Area.learning => l.areaLearning,
  Area.health => l.areaHealth,
  Area.money => l.areaMoney,
  Area.skills => l.areaSkills,
};

String weekLine(AppLocalizations l, TaskKind kind, int n) => switch (kind) {
  TaskKind.readSchool => l.weekReadSchool(n),
  TaskKind.readMedicine => l.weekReadMedicine(n),
  TaskKind.readReport => l.weekReadReport(n),
  TaskKind.readStatement => l.weekReadStatement(n),
  TaskKind.readLetter => l.weekReadLetter(n),
  TaskKind.quiz => l.weekQuiz(n),
  TaskKind.lesson => l.weekLesson(n),
};

Future<IndependenceScore> loadScore(BuildContext context) async {
  final tier = AppScope.of(context).profile.tier!;
  return IndependenceScore.from(await TaskLog.load(), tier);
}

/// My Independence Score, worked out from real tasks finished in Magana.
class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  IndependenceScore? _score;
  ({int start, int weeks})? _since;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final score = await loadScore(context);
      final since = await ScoreHistory.since(score.overall);
      final sharing = await ScoreHistory.sharing();
      if (!mounted) return;
      setState(() {
        _score = score;
        _since = since;
        _sharing = sharing;
      });
      final l = AppLocalizations.of(context);
      AppScope.of(context).speaker.say(
        [
          '${l.scoreTitle}: ${l.scoreOutOf(score.overall)}.',
          if (since != null) '${_sinceText(l, score.overall, since)}.',
          for (final MapEntry(key: area, value: v) in score.byArea.entries)
            '${l.areaScoreLabel(areaName(l, area), v)}.',
        ].join(' '),
      );
    });
  }

  Future<void> _share(bool on) async {
    await ScoreHistory.setSharing(on);
    if (mounted) setState(() => _sharing = on);
  }

  String _sinceText(
    AppLocalizations l,
    int now,
    ({int start, int weeks}) since,
  ) => now > since.start
      ? l.scoreUpSince(since.start, since.weeks)
      : l.scoreSince(since.start, since.weeks);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final score = _score;
    if (score == null) {
      return PageScaffold(
        body: [
          ScreenHeader(title: l.scoreTitle),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.scoreTitle,
          subtitle: l.scoreSubtitle,
          introduce: true,
        ),
        Semantics(
          container: true,
          label: '${l.scoreTitle}: ${l.scoreOutOf(score.overall)}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MaganaColors.green, width: 3),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: score.overall / 100,
                        strokeWidth: 14,
                        color: MaganaColors.green,
                        backgroundColor: const Color(0xFFE2DED4),
                      ),
                      Center(
                        child: Text(
                          '${score.overall}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    l.scoreOutOf(score.overall),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_since case final since?)
          Text(
            _sinceText(l, score.overall, since),
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
        Semantics(
          header: true,
          child: Text(
            l.scoreByArea,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final MapEntry(key: area, value: v) in score.byArea.entries)
          Semantics(
            label: l.areaScoreLabel(areaName(l, area), v),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        areaName(l, area),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    Text(
                      '$v',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: v / 100,
                    minHeight: 12,
                    color: MaganaColors.green,
                    backgroundColor: const Color(0xFFE2DED4),
                  ),
                ),
              ],
            ),
          ),
        Semantics(
          header: true,
          child: Text(
            l.scoreThisWeek,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        if (score.thisWeek.isEmpty)
          NoteBox(text: l.scoreNothingThisWeek)
        else
          for (final MapEntry(key: kind, value: n) in score.thisWeek.entries)
            NoteBox(text: weekLine(l, kind, n), kind: NoteKind.success),
        Semantics(
          toggled: _sharing,
          label: l.shareScore,
          excludeSemantics: true,
          onTap: () => _share(!_sharing),
          // The whole row toggles it, not just the small switch.
          child: InkWell(
            onTap: () => _share(!_sharing),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MaganaColors.ink, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.shareScore,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch(
                    value: _sharing,
                    activeThumbColor: MaganaColors.green,
                    onChanged: _share,
                  ),
                ],
              ),
            ),
          ),
        ),
        NoteBox(text: l.shareScoreNote),
        NoteBox(text: l.scoreHow, kind: NoteKind.privacy),
      ],
    );
  }
}
