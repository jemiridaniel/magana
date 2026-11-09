import 'package:flutter/material.dart';

import '../api.dart';
import '../app_scope.dart';
import '../commands.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../messages.dart';
import '../speech.dart';
import '../theme.dart';
import '../voice_input.dart';
import '../widgets.dart';
import 'capture.dart';
import 'report_problem.dart';

/// Explain in my language (design 6). One task only: explain the page Magana
/// read (backend/llm/natlas_guard.py, docs/LLM_SAFETY.md). No questions, no
/// chat: what the learner says here is a command (repeat, slower, next, stop,
/// read again, English, help), never sent to the model. Every answer comes
/// through the backend's checks; when one fails, the page text is read instead
/// (CLAUDE.md rule 1). Pages about health, money or harm are never explained:
/// "Ask your teacher".
class ExplainScreen extends StatefulWidget {
  const ExplainScreen({
    super.key,
    required this.lines,
    required this.source,
    this.mode = 'school',
  });

  /// school, or health / money / letter: those papers are never explained by a
  /// model; each line is read as printed or from an approved translation.
  final String mode;

  /// The page as Magana read it, one line or row each, with unclear numbers
  /// already said as "unclear number". Empty when opened from Home.
  final List<String> lines;
  final String source; // where the text came from, e.g. "Medicine label"

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  late final VoiceInput _voice = voiceInputFor(context);
  bool? _voiceWorks;
  bool _listening = false;
  late String _language = Localizations.localeOf(context).languageCode;
  Explanation? _answer;
  String _spoken = ''; // the whole answer as last said
  List<String> _sentences = const [];
  int _at = -1; // the sentence "next" last said; -1: the whole answer
  (Speaker, double)? _rateBefore; // "slower": put back on leaving
  String? _error;
  bool _busy = false;

  AppLocalizations get _l => AppLocalizations.of(context);
  bool get _hasPage => widget.lines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasPage) {
        _ask();
      } else {
        AppScope.of(context).speaker
            .say('${_l.explainTitle}. ${_l.explainNoPage}');
      }
    });
  }

  @override
  void dispose() {
    if (_listening) _voice.stop();
    if (_rateBefore case (final speaker, final rate)) speaker.setRate(rate);
    super.dispose();
  }

  Future<void> _ask() async {
    final scope = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final a = await scope.api.explain(
        sourceText: widget.lines.join('\n'),
        language: _language,
        mode: widget.mode,
      );
      if (!mounted) return;
      final body = a.spoken((code) => messageFor(_l, code));
      setState(() {
        _answer = a;
        _at = -1;
        _sentences = [
          for (final s in body.split(RegExp(r'(?<=[.!?])\s+')))
            if (s.trim().isNotEmpty) s.trim(),
        ];
        _spoken = [
          messageFor(_l, a.code, language: _languageName),
          body,
          if (a.followup case final f?) messageFor(_l, f),
        ].join(' ');
      });
      scope.speaker.say(_spoken);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = messageFor(_l, e.code);
      setState(() => _error = msg);
      scope.speaker.say(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listen() async {
    final lang = Localizations.localeOf(context).languageCode;
    if (_listening) {
      await _voice.stop();
      return;
    }
    final speaker = AppScope.of(context).speaker;
    _voiceWorks ??= await _voice.init();
    if (!mounted) return;
    if (_voiceWorks != true) {
      setState(() => _error = _l.voiceCommandsUnavailable);
      speaker.say(_l.voiceCommandsUnavailable);
      return;
    }
    await speaker.stop();
    setState(() => _listening = true);
    final List<String> heard;
    try {
      heard = await _voice.listen(language: lang);
    } on VoiceStepFailed {
      // No recogniser this account may use: tap instead.
      if (!mounted) return;
      setState(() => _listening = false);
      speaker.say(_l.voiceCommandsUnavailable);
      return;
    }
    if (!mounted) return;
    setState(() => _listening = false);
    if (heard.isEmpty) {
      speaker.say(_l.commandNothingHeard);
      return;
    }
    _command(heard.first);
  }

  /// A spoken command. Anything else is not understood: never a question.
  void _command(String heard) {
    final speaker = AppScope.of(context).speaker;
    switch (matchExplainCommand(heard)) {
      case ExplainCommand.readAgain:
        // The page exactly as printed, numbers and all.
        _readPage();
      case ExplainCommand.repeat:
        _repeat();
      case ExplainCommand.slower:
        _slower();
      case ExplainCommand.next:
        _next();
      case ExplainCommand.stop:
        speaker.stop();
      case ExplainCommand.english when _languageComing:
        // The offer when this language isn't on yet.
        _inEnglish();
      case ExplainCommand.help:
        speaker.say(_l.explainCommandsHint);
      case ExplainCommand.english || null:
        speaker.say(
          '${_l.commandNotUnderstood(heard)} ${_l.explainCommandsHint}',
        );
    }
  }

  void _repeat() {
    if (!_hasPage) return;
    AppScope.of(context).speaker
        .say(_at >= 0 && _at < _sentences.length ? _sentences[_at] : _spoken);
  }

  Future<void> _slower() async {
    final speaker = AppScope.of(context).speaker;
    _rateBefore ??= (speaker, speaker.rate);
    await speaker.setRate((speaker.rate * 0.75).clamp(0.5, 2.0));
    if (mounted) _repeat();
  }

  void _next() {
    final speaker = AppScope.of(context).speaker;
    if (_at + 1 >= _sentences.length) {
      speaker.say(_l.explainEnd);
      return;
    }
    setState(() => _at++);
    speaker.say(_sentences[_at]);
  }

  void _readPage() => AppScope.of(context).speaker.say(widget.lines.join('\n'));

  String get _languageName =>
      appLanguages.firstWhere((a) => a.code == _language).name;

  /// Explain in Hausa, Yorùbá or Igbo is not on yet: the same page in English.
  bool get _languageComing => _answer?.code == 'explain_language_coming';

  void _inEnglish() {
    setState(() => _language = 'en');
    _ask();
  }

  void _nextLanguage() {
    final i = appLanguages.indexWhere((a) => a.code == _language);
    final next = appLanguages[(i + 1) % appLanguages.length];
    setState(() => _language = next.code);
    if (_hasPage) {
      _ask(); // the same page, explained again in the new language
    } else {
      AppScope.of(context).speaker.say(_l.answerLanguage(next.name));
    }
  }

  void _report() => openReportProblem(
    context,
    screen: 'explain',
    pageText: _hasPage ? widget.lines.join('\n') : null,
  );

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final language = appLanguages.firstWhere((a) => a.code == _language);
    final answer = _answer;
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.explainTitle,
          subtitle: _hasPage ? l.explainFrom(widget.source) : null,
          trailing: Labelled(
            label: l.answerLanguage(language.name),
            onTap: _nextLanguage,
            child: OutlinedButton(
              onPressed: _nextLanguage,
              style: outlinedTile(radius: 32).copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(64, 64)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
              child: Text(language.name),
            ),
          ),
        ),
        NoteBox(text: l.explainPreviewBanner, kind: NoteKind.warning),
        if (!_hasPage) ...[
          NoteBox(text: l.explainNoPage),
          PrimaryButton(
            label: l.readPage,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CaptureScreen()),
            ),
          ),
        ],
        if (_error case final e?) NoteBox(text: e, kind: NoteKind.warning),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (answer != null && !_busy)
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MaganaColors.ink, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    messageFor(l, answer.code, language: language.name),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: MaganaColors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    answer.spoken((code) => messageFor(l, code)),
                    style: const TextStyle(fontSize: 19, height: 1.45),
                  ),
                  if (answer.followup case final f?) ...[
                    const SizedBox(height: 10),
                    Text(
                      messageFor(l, f),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Text(
                    l.basedOnPage(widget.lines.length),
                    style: const TextStyle(
                      fontSize: 15,
                      color: MaganaColors.muted,
                    ),
                  ),
                  Text(
                    l.readExactlyNote,
                    style: const TextStyle(
                      fontSize: 15,
                      color: MaganaColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_hasPage && _languageComing && !_busy)
          PrimaryButton(label: l.explainInEnglish, onTap: _inEnglish),
        if (_hasPage) ...[
          SecondaryButton(
            label: l.repeat,
            onTap: _busy || answer == null ? null : _repeat,
          ),
          SecondaryButton(
            label: l.explainSlower,
            onTap: _busy || answer == null ? null : _slower,
          ),
          SecondaryButton(
            label: l.next,
            onTap: _busy || answer == null ? null : _next,
          ),
          SecondaryButton(label: l.explainReadAgain, onTap: _readPage),
          SecondaryButton(label: l.reportProblem, onTap: _report),
        ],
        if (_hasPage) Text(l.explainCommandsHint, textAlign: TextAlign.center),
        Text(
          l.explainDisclaimer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: MaganaColors.muted),
        ),
      ],
      bottom: [
        Labelled(
          label: _listening ? l.listeningCommand : l.speakCommand,
          onTap: _listen,
          child: FilledButton.icon(
            onPressed: _listen,
            icon: Icon(_listening ? Icons.stop : Icons.mic_none, size: 30),
            label: Text(_listening ? l.listeningCommand : l.speakCommand),
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
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
