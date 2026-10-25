import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../platform.dart';
import '../quiz.dart';
import '../speech.dart';
import '../tasks.dart';
import '../theme.dart';
import '../voice_answers.dart' as voice_answers;
import '../voice_input.dart';
import '../widgets.dart';

/// Voice quiz: each question and its options are read aloud; the learner says
/// A, B, C or D, taps an option, or presses A to D on a keyboard, and fixed rules
/// mark the answer. Whether voice can work is checked before the Say button shows.
/// Primary 1–6 hear questions a little slower than the learner's own speed.
const primaryQuizRate = 0.8;

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.load = Quiz.load});
  final Future<Quiz> Function() load;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final VoiceInput _voice = voiceInputFor(context);
  bool? _voiceWorks; // checked when the quiz opens
  bool _toldNoVoice = false;
  voice_answers.VoiceOff? _off; // why "Say" isn't offered, if it isn't
  double? _rateBefore; // primary mode slows the voice; restored on leaving
  Quiz? _quiz;
  int _index = 0;
  int? _chosen;
  int _right = 0;
  int _answered = 0;
  bool _listening = false;
  bool _finished = false;
  int? _pending; // heard, waiting for "yes" before it counts
  int _failures = 0; // spoken tries on this question that gave no answer
  ({String text, NoteKind kind})? _feedback;

  AppLocalizations get _l => AppLocalizations.of(context);
  QuizQuestion get _q => _quiz!.questions[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = AppScope.of(context).profile;
      final quiz = await widget.load();
      // Not offered where spoken answers aren't recognised well enough yet.
      _off = voice_answers.voiceAnswersOff(
        language: _language,
        tier: profile.tier,
        level: profile.level,
        primaryQuiz: quiz.primary,
      );
      final works =
          _off == null && await _voice.init().catchError((_) => false);
      if (!mounted) return;
      setState(() {
        _quiz = quiz;
        _voiceWorks = works;
      });
      if (quiz.primary) {
        _rateBefore = _speaker.rate;
        await _speaker.setRate(_speaker.rate * primaryQuizRate);
      }
      _askCurrent();
    });
  }

  late final Speaker _speaker = AppScope.of(context).speaker;

  @override
  void dispose() {
    if (_listening) _voice.stop();
    if (_rateBefore case final rate?) _speaker.setRate(rate);
    super.dispose();
  }

  String get _language => Localizations.localeOf(context).languageCode;

  String get _title {
    final quiz = _quiz;
    if (quiz == null) return _l.practiceQuiz;
    return quiz.teacherMade
        ? quiz.title
        : _l.quizSubjectTitle(quiz.subjectName);
  }

  String get _progress => [
    if (_quiz!.sample) _l.quizSamples,
    _l.quizProgress(_index + 1, _quiz!.questions.length),
  ].join(' · ');

  void _say(String text) => AppScope.of(context).speaker.say(text);

  void _askCurrent() => _say(
    [
      _progress,
      _q.questionIn(_language),
      if (_q.picture case final picture?) _l.quizPicture(picture),
      if (!_q.trueFalse)
        for (var i = 0; i < _q.options.length; i++)
          '${letters[i]}, ${_q.options[i]}.',
      _howToAnswer(),
    ].join(' '),
  );

  String get _noVoice {
    if (_off == voice_answers.VoiceOff.primary) {
      return runningOnWeb
          ? _l.quizVoicePrimaryOffWeb(_letters)
          : _l.quizVoicePrimaryOff;
    }
    if (_off == voice_answers.VoiceOff.language) {
      final name = languageFor(Localizations.localeOf(context)).name;
      return runningOnWeb
          ? _l.quizVoiceNotReadyWeb(name, _letters)
          : _l.quizVoiceNotReady(name);
    }
    return runningOnWeb
        ? _l.quizVoiceUnavailableWeb(_letters)
        : _l.quizVoiceUnavailable;
  }

  /// This question's letters: "A or B", "A, B or C", "A, B, C or D".
  String get _letters {
    final mine = letters.take(_q.options.length).toList();
    return mine.length < 2
        ? mine.join()
        : '${mine.take(mine.length - 1).join(', ')} ${_l.quizOr} ${mine.last}';
  }

  /// Say it, tap it, or (on the web) press its key. When voice can't work the
  /// first question says so; later ones just say how to answer.
  String _howToAnswer() {
    final tf = _q.trueFalse;
    final keys = tf ? _l.quizKeysHintTrueFalse : _l.quizKeysHint(_letters);
    if (_voiceWorks == true) {
      final say = tf ? _l.quizSayTrueFalse : _l.quizSayAnswer(_letters);
      return runningOnWeb ? '$say. $keys' : say;
    }
    if (!_toldNoVoice) {
      _toldNoVoice = true;
      return _noVoice;
    }
    return runningOnWeb ? keys : _l.quizTapAnswer;
  }

  /// Primary classes hear encouraging words: "Well done!", "Good try!".
  String _verdict(int i) {
    final q = _q;
    final answer = q.trueFalse
        ? q.options[q.answer]
        : '${letters[q.answer]}, ${q.options[q.answer]}';
    final primary = _quiz!.primary;
    final verdict = i == q.answer
        ? (primary
              ? _l.quizCorrectPrimary(q.spokenAnswer(i))
              : _l.quizCorrect(q.spokenAnswer(i)))
        : (primary
              ? _l.quizWrongPrimary(answer)
              : _l.quizWrong(q.spokenAnswer(i), answer));
    return [verdict, q.explanation].where((t) => t.isNotEmpty).join(' ');
  }

  void _choose(int i) {
    // Once answered, options stay active (full contrast, never "disabled")
    // and touching one again repeats the verdict.
    if (_chosen case final chosen?) return _say(_verdict(chosen));
    final right = i == _q.answer;
    final text = _verdict(i);
    setState(() {
      _pending = null;
      _chosen = i;
      _answered++;
      if (right) _right++;
      _feedback = (
        text: text,
        kind: right ? NoteKind.success : NoteKind.warning,
      );
    });
    _say(text);
  }

  void _next() {
    if (_index + 1 >= _quiz!.questions.length) {
      setState(() => _finished = true);
      if (_answered > 0) TaskLog.record(TaskKind.quiz);
      _say(_l.quizResult(_right, _quiz!.questions.length));
      return;
    }
    setState(() {
      _index++;
      _chosen = null;
      _feedback = null;
      _pending = null;
      _failures = 0;
    });
    _askCurrent();
  }

  void _restart() {
    setState(() {
      _index = 0;
      _chosen = null;
      _right = 0;
      _answered = 0;
      _feedback = null;
      _finished = false;
      _pending = null;
      _failures = 0;
    });
    _askCurrent();
  }

  void _warn(String text) {
    setState(() => _feedback = (text: text, kind: NoteKind.warning));
    _say(text);
  }

  /// Spoken answers are confirmed before they count: "You said B. Is that right?".
  /// Recognition trouble never marks an answer wrong; after two failed tries the
  /// learner is asked to tap instead. Tapping an option always works directly.
  Future<void> _listen() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    final speaker = AppScope.of(context).speaker;
    if (_voiceWorks != true) {
      _warn(_noVoice);
      return;
    }
    await speaker.stop(); // the microphone must not hear the question
    setState(() {
      _listening = true;
      if (_chosen == null && _pending == null) _feedback = null; // an old note
    });
    final List<String> heard;
    try {
      // The learner's own language: Magana's server scores the answer against
      // the letter names in that language and in English (a closed set).
      heard = await _voice.listen(
        language: _language,
        choices: _pending != null
            ? const AnswerChoices.yesNo()
            : _q.trueFalse
            ? const AnswerChoices.trueFalse()
            : AnswerChoices.letters(_q.options.length),
      );
    } on VoiceStepFailed {
      // Every recogniser this account may use failed: tapping still works, and
      // the Say button goes. Never "I did not hear an answer": nothing listened.
      if (!mounted) return;
      setState(() {
        _listening = false;
        _voiceWorks = false;
      });
      _warn(_noVoice);
      return;
    }
    if (!mounted) return;
    setState(() => _listening = false);
    final q = _q;

    if (heard.length == 1 && heard.single == notSure) {
      // Something was said, but not clearly an answer: ask again (never "did not hear").
      _failed(_l.quizNotSure);
      return;
    }
    if (_pending case final pending?) {
      // Confirming: only a clear yes counts the answer.
      switch (voice_answers.yesNo(heard.isEmpty ? '' : heard.first)) {
        case true:
          _choose(pending);
        case false:
          _rejectPending();
        default:
          _say(_l.quizConfirm(q.spokenAnswer(pending)));
      }
      return;
    }
    switch (hear(heard, q)) {
      case Answered(:final index) when _chosen != null:
        _choose(index); // already answered: says the verdict again
      case Answered(:final index):
        setState(() => _pending = index);
        _say(_l.quizConfirm(q.spokenAnswer(index)));
      case Command(kind: CommandKind.repeat):
        _askCurrent();
      case Command(kind: CommandKind.next):
        _next();
      case Unclear():
        _failed(
          heard.isEmpty
              ? _l.quizNothingHeard(_letters)
              : _l.quizUnclear(heard.first, _letters),
        );
    }
  }

  /// "No, ask me again" (spoken or tapped).
  void _rejectPending() {
    setState(() => _pending = null);
    _failed(_l.quizSayAgain);
  }

  /// A try that didn't give an answer. After two, offer tapping instead.
  void _failed(String message) {
    _failures++;
    _warn(_failures >= 2 ? _l.quizTapInstead : message);
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final quiz = _quiz;
    if (quiz == null) {
      return PageScaffold(
        body: [
          ScreenHeader(title: _title),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_finished) return _result(l, quiz);
    final q = _q;
    return _answerKeys(
      q,
      PageScaffold(
        body: [
          ScreenHeader(
            title: _title,
            subtitle: _progress,
            trailing: Semantics(
              label: l.quizScoreLabel(_right, _answered),
              excludeSemantics: true,
              child: Text(
                '$_right / $_answered',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (_index + 1) / quiz.questions.length,
                minHeight: 10,
                color: MaganaColors.green,
                backgroundColor: const Color(0xFFE2DED4),
              ),
            ),
          ),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              q.questionIn(_language),
              style: const TextStyle(
                fontSize: 25,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (q.picture case final picture?)
            NoteBox(text: l.quizPicture(picture)),
          for (var i = 0; i < q.options.length; i++)
            _OptionTile(
              letter: letters[i],
              text: q.options[i],
              chosen: _chosen == i,
              revealed: _chosen != null,
              right: i == q.answer,
              onTap: () => _choose(i),
            ),
          if (_pending case final p?) ...[
            Semantics(
              liveRegion: true,
              child: NoteBox(text: l.quizConfirm(q.spokenAnswer(p))),
            ),
            PrimaryButton(
              label: l.quizConfirmYes(q.spokenAnswer(p)),
              onTap: () => _choose(p),
            ),
            SecondaryButton(label: l.quizConfirmNo, onTap: _rejectPending),
          ] else if (_feedback case final f?)
            Semantics(
              liveRegion: true,
              child: NoteBox(text: f.text, kind: f.kind),
            ),
          NoteBox(
            text: quiz.teacherMade ? l.quizTeacherNote : l.quizSampleNote,
          ),
        ],
        bottom: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(label: l.quizRepeat, onTap: _askCurrent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: _index + 1 < quiz.questions.length
                      ? l.quizNext
                      : l.quizFinish,
                  onTap: _next,
                ),
              ),
            ],
          ),
          if (_voiceWorks == true)
            _MicButton(
              listening: _listening,
              onTap: _listen,
              label: _pending != null
                  ? l.quizSayYesOrNo
                  : q.trueFalse
                  ? l.quizSayTrueFalse
                  : l.quizSayAnswer(_letters),
            )
          else
            NoteBox(text: _noVoice),
        ],
      ),
    );
  }

  static const _keys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyD,
  ];

  /// A to D on a keyboard answer like tapping the option.
  Widget _answerKeys(QuizQuestion q, Widget child) => CallbackShortcuts(
    bindings: {
      for (var i = 0; i < q.options.length && i < _keys.length; i++)
        SingleActivator(_keys[i]): () => _choose(i),
    },
    child: Focus(autofocus: true, child: child),
  );

  Widget _result(AppLocalizations l, Quiz quiz) => PageScaffold(
    body: [
      ScreenHeader(title: l.quizResultTitle),
      Semantics(
        liveRegion: true,
        child: NoteBox(
          text: l.quizResult(_right, quiz.questions.length),
          kind: NoteKind.success,
        ),
      ),
    ],
    bottom: [
      PrimaryButton(label: l.quizAgain, onTap: _restart),
      SecondaryButton(
        label: l.backHome,
        onTap: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.chosen,
    required this.revealed,
    required this.right,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool chosen;
  final bool revealed; // an answer was given, so show which one is right
  final bool right;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = switch ((chosen, right, revealed)) {
      (true, true, _) => l.quizYourAnswerRight,
      (true, false, _) => l.quizYourAnswerWrong,
      (false, true, true) => l.quizRightAnswer,
      _ => null,
    };
    final (bg, border) = switch ((chosen, right, revealed)) {
      (_, true, true) => (const Color(0xFFE3F1EA), MaganaColors.green),
      (true, false, _) => (MaganaColors.warnFill, MaganaColors.warnBorder),
      _ => (Colors.white, MaganaColors.ink),
    };
    return Labelled(
      label: status == null ? '$letter. $text' : '$letter. $text, $status',
      onTap: onTap,
      child: OutlinedButton(
        onPressed: onTap,
        style: outlinedTile(radius: 16, bg: bg, border: border).copyWith(
          alignment: Alignment.centerLeft,
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: border, width: status == null ? 2 : 3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (status != null)
              Icon(
                right ? Icons.check : Icons.close,
                size: 28,
                color: right ? MaganaColors.green : MaganaColors.warnInk,
              ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.onTap,
    required this.label,
  });
  final bool listening;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = listening ? l.quizListening : this.label;
    return Labelled(
      label: label,
      onTap: onTap,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(listening ? Icons.stop : Icons.mic_none, size: 30),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: MaganaColors.amber,
          foregroundColor: MaganaColors.ink,
          minimumSize: const Size.fromHeight(76),
          side: const BorderSide(color: MaganaColors.ink, width: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(38),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
