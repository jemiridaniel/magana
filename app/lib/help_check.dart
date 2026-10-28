import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'app_scope.dart';
import 'l10n/app_localizations.dart';
import 'policy.dart';
import 'tasks.dart';
import 'theme.dart';
import 'voice_input.dart';
import 'widgets.dart';
import 'touch.dart';

/// "Did you read this page on your own?" (board 8): asked after a page, a PDF or a quiz is
/// finished, at most once a day. Kept on this phone: the date, the kind of task and the
/// answer, never the page. A learner in a class who shares their progress sends the daily
/// totals to their teacher (ProgressShare); adults keep them on the phone only.
enum HelpTask { page, pdf, quiz }

enum HelpAnswer { own, someHelp, skip }

/// Off in widget tests unless a test turns it on (test/flutter_test_config.dart), so the
/// sheet doesn't cover every finished page there.
bool helpCheckEnabled = true;

typedef HelpRecord = ({String day, HelpTask task, HelpAnswer answer});

String dayOf(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class HelpLog {
  static const _key = 'help_answers';
  static const keep = Duration(days: 90);

  static Future<List<HelpRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final s in prefs.getStringList(_key) ?? const <String>[])
        if (s.split('|') case [final day, final task, final answer])
          if (HelpTask.values.asNameMap()[task] case final t?)
            if (HelpAnswer.values.asNameMap()[answer] case final a?)
              (day: day, task: t, answer: a),
    ];
  }

  /// Asked already today (any answer, Skip too).
  static Future<bool> askedToday({DateTime? now}) async {
    final today = dayOf(now ?? DateTime.now());
    return (await load()).any((r) => r.day == today);
  }

  static Future<void> record(
    HelpTask task,
    HelpAnswer answer, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final oldest = dayOf(at.subtract(keep));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      for (final r in await load())
        if (r.day.compareTo(oldest) >= 0)
          '${r.day}|${r.task.name}|${r.answer.name}',
      '${dayOf(at)}|${task.name}|${answer.name}',
    ]);
  }

  /// Per day: tasks done on one's own, and with some help (Skip counts for neither).
  static Future<Map<String, ({int own, int helped})>> totals() async {
    final out = <String, ({int own, int helped})>{};
    for (final r in await load()) {
      final t = out[r.day] ?? (own: 0, helped: 0);
      out[r.day] = switch (r.answer) {
        HelpAnswer.own => (own: t.own + 1, helped: t.helped),
        HelpAnswer.someHelp => (own: t.own, helped: t.helped + 1),
        HelpAnswer.skip => t,
      };
    }
    return out;
  }
}

/// A spoken answer, by fixed words in the app language (English always works too), or null:
/// asked again, never guessed. "Some help" before "yes": "yes, I needed some help". The
/// Hausa, Yorùbá and Igbo words are drafts for native-speaker review.
HelpAnswer? matchHelpAnswer(String transcript) {
  final t = ' ${transcript.toLowerCase().replaceAll(RegExp(r'[.,!?]'), ' ')} '
      .replaceAll(RegExp(r' +'), ' ');
  bool any(List<String> words) => words.any((w) => t.contains(' $w '));
  if (any([
    'some help', 'help', 'helped', 'needed help', //
    'taimako', 'ìrànlọ́wọ́', 'iranlowo', 'enyemaka',
  ])) {
    return HelpAnswer.someHelp;
  }
  if (any([
    'skip', 'not today', //
    'tsallake', 'ba yau ba', 'fò ó', 'fo o', 'wụfee', 'wufee',
  ])) {
    return HelpAnswer.skip;
  }
  if (any([
    'yes', 'yeah', 'on my own', 'myself', //
    'eh', 'ee', 'da kaina', 'bẹ́ẹ̀ni', 'beeni', 'bee ni', 'eye',
  ])) {
    return HelpAnswer.own;
  }
  return null;
}

/// Shows the sheet if it is due: not asked today, help check on, and never in a teacher-run
/// Classroom session (nothing from it is kept). Returns the answer, or null.
Future<HelpAnswer?> maybeAskForHelp(BuildContext context, HelpTask task) async {
  final scope = AppScope.of(context);
  final tier = scope.profile.tier;
  if (!helpCheckEnabled || tier == null || tier == Tier.classroom) return null;
  if (await HelpLog.askedToday()) return null;
  if (!context.mounted) return null;
  final sharing = scope.profile.link != null && await ScoreHistory.sharing();
  if (!context.mounted) return null;
  final answer = await showModalBottomSheet<HelpAnswer>(
    context: context,
    isScrollControlled: true,
    // TalkBack lands on the sheet's question, not a "Dismiss" handle above it.
    showDragHandle: !screenReaderOn(context),
    backgroundColor: MaganaColors.ground,
    builder: (_) => HelpCheckSheet(task: task, sharing: sharing),
  );
  // Closing the sheet without an answer counts as Skip: it isn't asked again today.
  final chosen = answer ?? HelpAnswer.skip;
  await HelpLog.record(task, chosen);
  if (context.mounted && sharing) {
    ProgressShare.send(scope.api, scope.profile.link!);
  }
  return chosen;
}

class HelpCheckSheet extends StatefulWidget {
  const HelpCheckSheet({super.key, required this.task, required this.sharing});
  final HelpTask task;
  final bool sharing;

  @override
  State<HelpCheckSheet> createState() => _HelpCheckSheetState();
}

class _HelpCheckSheetState extends State<HelpCheckSheet> {
  VoiceInput? _voice;
  bool _done = false;

  AppLocalizations get _l => AppLocalizations.of(context);

  String get _question => switch (widget.task) {
    HelpTask.page => _l.helpCheckPage,
    HelpTask.pdf => _l.helpCheckPdf,
    HelpTask.quiz => _l.helpCheckQuiz,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askAloud());
  }

  @override
  void dispose() {
    _done = true;
    _voice?.stop();
    super.dispose();
  }

  /// Says the question, then listens once for "yes", "some help" or "skip". Tapping works
  /// all the time; a word it doesn't know is never taken as an answer.
  Future<void> _askAloud() async {
    final speaker = AppScope.of(context).speaker;
    final lang = Localizations.localeOf(context).languageCode;
    final voice = _voice = voiceInputFor(context);
    await speaker.say('$_question ${_l.helpCheckHow}');
    if (_done || !mounted || !await voice.init() || _done) return;
    List<String> heard;
    try {
      heard = await voice.listen(language: lang);
    } on VoiceStepFailed {
      return;
    }
    if (_done || !mounted) return;
    final answer = heard.map(matchHelpAnswer).nonNulls.firstOrNull;
    if (answer == null) {
      if (heard.isNotEmpty) speaker.say(_l.helpCheckNotHeard);
      return;
    }
    _answer(answer);
  }

  void _answer(HelpAnswer a) {
    if (_done) return;
    _done = true;
    _voice?.stop();
    AppScope.of(context).speaker.say(_l.helpCheckThanks);
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    Widget option(
      HelpAnswer a,
      String title,
      String detail,
      bool primary,
    ) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Labelled(
        label: '$title. $detail',
        onTap: () => _answer(a),
        child: (primary ? FilledButton.new : OutlinedButton.new)(
          onPressed: () => _answer(a),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(76)),
            alignment: Alignment.centerLeft,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            backgroundColor: WidgetStatePropertyAll(
              primary ? MaganaColors.green : Colors.white,
            ),
            foregroundColor: WidgetStatePropertyAll(
              primary ? Colors.white : MaganaColors.ink,
            ),
            side: primary
                ? null
                : const WidgetStatePropertyAll(
                    BorderSide(color: MaganaColors.ink, width: 2),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: primary ? const Color(0xFFE3F1EA) : MaganaColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                _question,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.helpCheckHow,
              style: const TextStyle(fontSize: 18, color: MaganaColors.muted),
            ),
            option(HelpAnswer.own, l.helpOwn, l.helpOwnDetail, true),
            option(HelpAnswer.someHelp, l.helpSome, l.helpSomeDetail, false),
            option(HelpAnswer.skip, l.helpSkip, l.helpSkipDetail, false),
            const SizedBox(height: 14),
            Text(
              widget.sharing ? l.helpCheckNoteClass : l.helpCheckNotePhone,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                color: MaganaColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The daily totals a learner in a class shares with their teacher ("Share my score with my
/// teacher" on): per day, pages read, tasks done on their own and with some help. Nothing
/// else: no page, no answer to any question, no time of day.
class ProgressShare {
  static const days = 28;

  static Future<Map<String, Map<String, int>>> payload({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final from = dayOf(today.subtract(const Duration(days: days - 1)));
    final out = <String, Map<String, int>>{};
    for (final r in await TaskLog.load()) {
      final d = dayOf(r.at);
      if (d.compareTo(from) < 0 || r.kind == TaskKind.quiz) continue;
      (out[d] ??= {'pages': 0, 'own': 0, 'helped': 0})['pages'] =
          out[d]!['pages']! + 1;
    }
    for (final MapEntry(key: d, value: t) in (await HelpLog.totals()).entries) {
      if (d.compareTo(from) < 0) continue;
      final row = out[d] ??= {'pages': 0, 'own': 0, 'helped': 0};
      row['own'] = t.own;
      row['helped'] = t.helped;
    }
    return out;
  }

  /// Sends the totals if this phone is in a class, its link is active and the learner shares.
  /// Never throws: offline or refused, it is simply tried again next time.
  static Future<bool> send(MaganaApi api, ClassLink link) async {
    if (link.status != 'active' || !await ScoreHistory.sharing()) return false;
    try {
      final body = await payload();
      if (body.isEmpty) return false;
      await api.shareProgress(body);
      return true;
    } catch (_) {
      return false;
    }
  }
}
