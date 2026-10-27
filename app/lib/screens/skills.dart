import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../lessons.dart';
import '../papers.dart';
import '../policy.dart';
import '../speech.dart';
import '../theme.dart';
import '../widgets.dart';
import 'capture.dart';
import 'champions.dart';

/// Skills: short lessons spoken by the phone's voice, at the learner's pace.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<Lesson>? _lessons;
  LessonProgress? _progress;

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.skills}. ${l.skillsSubtitle}';
    });
    _load();
  }

  Future<void> _load() async {
    final lessons = await Lesson.load();
    final progress = await LessonProgress.load();
    if (mounted) {
      setState(() {
        _lessons = lessons;
        _progress = progress;
      });
    }
  }

  Future<void> _open(Lesson lesson, {bool play = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonScreen(lesson: lesson, autoplay: play),
      ),
    );
    _load(); // progress changed
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = AppScope.of(context).profile;
    final progress = _progress;
    final lessons = [
      for (final lesson in _lessons ?? const <Lesson>[])
        if (profile.can(lesson.feature)) lesson,
    ];
    if (progress == null) {
      return PageScaffold(
        body: [
          ScreenHeader(title: l.skills),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final next = lessons.where((x) => !progress.done(x)).firstOrNull;
    return PageScaffold(
      sayName: true,
      body: [
        ScreenHeader(title: l.skills, subtitle: l.skillsSubtitle),
        if (next != null)
          _NextLessonCard(
            lesson: next,
            onPlay: () => _open(next, play: true),
            onPractise: next.practice == null
                ? null
                : () => practise(context, next.practice!),
          )
        else
          NoteBox(text: l.allLessonsDone, kind: NoteKind.success),
        for (final lesson in lessons)
          ChoiceCard(
            title: lesson.title,
            detail: progress.done(lesson)
                ? l.lessonDone
                : progress.step(lesson) > 0
                ? l.lessonStepOf(progress.step(lesson) + 1, lesson.steps.length)
                : l.lessonNotStarted,
            leading: Icon(
              progress.done(lesson)
                  ? Icons.check_circle_outline
                  : Icons.headphones_outlined,
              size: 30,
            ),
            onTap: () => _open(lesson),
          ),
        if (profile.can(Feature.champions))
          SecondaryButton(
            label: l.practiseWithChampion,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ChampionsScreen())),
          ),
        NoteBox(text: l.skillsNote),
      ],
    );
  }
}

/// "Practise now": the screen where the lesson's skill is used.
void practise(BuildContext context, Practice practice) {
  final nav = Navigator.of(context);
  switch (practice) {
    case Practice.home:
      nav.popUntil((route) => route.isFirst);
    case Practice.capture:
      nav.push(MaterialPageRoute(builder: (_) => const CaptureScreen()));
    case Practice.statement:
      nav.push(
        MaterialPageRoute(
          builder: (_) => const CaptureScreen(paper: Paper.statement),
        ),
      );
  }
}

class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({
    required this.lesson,
    required this.onPlay,
    required this.onPractise,
  });

  final Lesson lesson;
  final VoidCallback onPlay;
  final VoidCallback? onPractise;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MaganaColors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: '${l.nextLesson(lesson.minutes)}. ${lesson.title}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.nextLesson(lesson.minutes).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(label: l.playLesson, onTap: onPlay),
              ),
              if (onPractise != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: l.practiseNow,
                    onTap: onPractise,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Plays a lesson step by step; pause, previous and next at any time.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson, this.autoplay = false});
  final Lesson lesson;
  final bool autoplay;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  LessonProgress? _progress;
  int _step = 0;
  bool _playing = false;
  int _run = 0; // bumps on every play, pause or jump, ending the old loop
  Speaker? _speaker; // kept for dispose, when the scope can't be looked up

  Lesson get _lesson => widget.lesson;
  bool get _last => _step == _lesson.steps.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final progress = await LessonProgress.load();
      if (!mounted) return;
      final saved = progress.done(_lesson) ? 0 : progress.step(_lesson);
      setState(() {
        _progress = progress;
        _step = saved.clamp(0, _lesson.steps.length - 1);
      });
      if (widget.autoplay) {
        _play();
      } else {
        AppScope.of(context).speaker.say(_lesson.title);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speaker = AppScope.of(context).speaker;
  }

  @override
  void dispose() {
    _run++;
    if (_playing) _speaker?.stop();
    super.dispose();
  }

  Future<void> _goTo(int step) async {
    setState(() => _step = step);
    await _progress?.setStep(_lesson, step);
    if (_last) await _progress?.finish(_lesson);
  }

  Future<void> _play() async {
    final run = ++_run;
    final speaker = AppScope.of(context).speaker;
    setState(() => _playing = true);
    for (var i = _step; i < _lesson.steps.length; i++) {
      await _goTo(i);
      final heard = await speaker.sayThrough(
        _lesson.steps[i],
        wanted: () => mounted && run == _run,
      );
      if (!mounted || run != _run) return;
      // TalkBack spoke over the step twice: pause here rather than skip it.
      if (!heard) return setState(() => _playing = false);
    }
    setState(() => _playing = false);
    speaker.say(AppLocalizations.of(context).lessonFinished);
  }

  void _pause() {
    _run++;
    setState(() => _playing = false);
    AppScope.of(context).speaker.stop();
  }

  Future<void> _jump(int step) async {
    final playing = _playing;
    _run++;
    await _goTo(step);
    if (!mounted) return;
    if (playing) {
      _play();
    } else {
      AppScope.of(context).speaker.say(_lesson.steps[step]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = _lesson.steps.length;
    return PageScaffold(
      body: [
        ScreenHeader(
          title: _lesson.title,
          subtitle: l.lessonStepOf(_step + 1, total),
        ),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (_step + 1) / total,
              minHeight: 10,
              color: MaganaColors.green,
              backgroundColor: const Color(0xFFE2DED4),
            ),
          ),
        ),
        Text(
          _lesson.steps[_step],
          style: const TextStyle(fontSize: 22, height: 1.45),
        ),
        if (_last && _lesson.practice != null)
          SecondaryButton(
            label: l.practiseNow,
            onTap: () => practise(context, _lesson.practice!),
          ),
      ],
      bottom: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: l.previousStep,
                onTap: _step > 0 ? () => _jump(_step - 1) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                label: l.nextStep,
                onTap: _last ? null : () => _jump(_step + 1),
              ),
            ),
          ],
        ),
        PrimaryButton(
          label: _playing ? l.pauseLesson : l.playLesson,
          onTap: _progress == null ? null : (_playing ? _pause : _play),
        ),
      ],
    );
  }
}
