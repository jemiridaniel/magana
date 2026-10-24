import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../quiz.dart';
import '../theme.dart';
import '../voice_input.dart';
import '../widgets.dart';

/// Voice quiz: each question and its options are read aloud; the learner says
/// A, B, C or D (or double taps an option) and fixed rules mark the answer.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.load = Quiz.load});
  final Future<Quiz> Function() load;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final VoiceInput _voice = voiceInput();
  bool? _voiceWorks; // null until first tried
  Quiz? _quiz;
  int _index = 0;
  int? _chosen;
  int _right = 0;
  int _answered = 0;
  bool _listening = false;
  bool _finished = false;
  ({String text, NoteKind kind})? _feedback;

  AppLocalizations get _l => AppLocalizations.of(context);
  QuizQuestion get _q => _quiz!.questions[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quiz = await widget.load();
      if (!mounted) return;
      setState(() => _quiz = quiz);
      _askCurrent();
    });
  }

  @override
  void dispose() {
    if (_listening) _voice.stop();
    super.dispose();
  }

  String get _progress => _l.quizProgress(_index + 1, _quiz!.questions.length);

  void _say(String text) => AppScope.of(context).speaker.say(text);

  void _askCurrent() => _say(
    [
      _progress,
      _q.question,
      for (var i = 0; i < _q.options.length; i++)
        '${letters[i]}, ${_q.options[i]}.',
      _l.quizSayAnswer,
    ].join(' '),
  );

  String _verdict(int i) {
    final q = _q;
    return i == q.answer
        ? '${_l.quizCorrect(letters[i])} ${q.explanation}'
        : '${_l.quizWrong(letters[i], '${letters[q.answer]}, ${q.options[q.answer]}')} '
              '${q.explanation}';
  }

  void _choose(int i) {
    // Once answered, options stay active (full contrast, never "disabled")
    // and touching one again repeats the verdict.
    if (_chosen case final chosen?) return _say(_verdict(chosen));
    final right = i == _q.answer;
    final text = _verdict(i);
    setState(() {
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
      _say(_l.quizResult(_right, _quiz!.questions.length));
      return;
    }
    setState(() {
      _index++;
      _chosen = null;
      _feedback = null;
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
    });
    _askCurrent();
  }

  void _warn(String text) {
    setState(() => _feedback = (text: text, kind: NoteKind.warning));
    _say(text);
  }

  Future<void> _listen() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    final speaker = AppScope.of(context).speaker;
    _voiceWorks ??= await _voice.init();
    if (!mounted) return;
    if (_voiceWorks != true) {
      _warn(_l.quizNoVoice);
      return;
    }
    await speaker.stop(); // the microphone must not hear the question
    setState(() {
      _listening = true;
      if (_chosen == null) _feedback = null; // an old "did not hear" note
    });
    final heard = await _voice.listen();
    if (!mounted) return;
    setState(() => _listening = false);
    switch (hear(heard, _q)) {
      case Answered(:final index):
        _choose(index);
      case Command(kind: CommandKind.repeat):
        _askCurrent();
      case Command(kind: CommandKind.next):
        _next();
      case Unclear():
        _warn(
          heard.isEmpty ? _l.quizNothingHeard : _l.quizUnclear(heard.first),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final quiz = _quiz;
    if (quiz == null) {
      return PageScaffold(
        body: [
          ScreenHeader(title: l.quizTitle),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_finished) return _result(l, quiz);
    final q = _q;
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.quizTitle,
          subtitle: _progress,
          trailing: Semantics(
            label: l.quizScoreLabel(_right, _answered),
            excludeSemantics: true,
            child: Text(
              '$_right / $_answered',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            q.question,
            style: const TextStyle(
              fontSize: 25,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var i = 0; i < q.options.length; i++)
          _OptionTile(
            letter: letters[i],
            text: q.options[i],
            chosen: _chosen == i,
            revealed: _chosen != null,
            right: i == q.answer,
            onTap: () => _choose(i),
          ),
        if (_feedback case final f?)
          Semantics(
            liveRegion: true,
            child: NoteBox(text: f.text, kind: f.kind),
          ),
        NoteBox(text: l.quizSource),
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
        _MicButton(listening: _listening, onTap: _listen),
      ],
    );
  }

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
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = listening ? l.quizListening : l.quizSayAnswer;
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
