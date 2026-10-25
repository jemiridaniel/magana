import 'package:flutter/material.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../messages.dart';
import '../theme.dart';
import '../voice_input.dart';
import '../widgets.dart';
import 'capture.dart';

/// Explain in my language (design 6). N-ATLAS is not hosted yet, so this is a
/// preview: the backend's preview engine gives back the page text itself. Every
/// answer comes through the backend's number guard; when the guard fails, the
/// page text is read instead (CLAUDE.md rule 1).
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
  String? _question;
  Explanation? _answer;
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
    super.dispose();
  }

  Future<void> _ask({String style = 'explain'}) async {
    final scope = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final a = await scope.api.explain(
        sourceText: widget.lines.join('\n'),
        language: _language,
        question: _question,
        style: style,
        mode: widget.mode,
      );
      if (!mounted) return;
      setState(() => _answer = a);
      scope.speaker.say(
        [
          if (_question != null && a.preview) _l.explainQuestionPreview,
          messageFor(_l, a.code),
          a.spoken((code) => messageFor(_l, code)),
          if (a.followup case final f?) messageFor(_l, f),
        ].join(' '),
      );
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
    // "read again": the page exactly as printed, numbers and all.
    if (RegExp(r'\bread\b.*\bagain\b|\bread the page\b')
        .hasMatch(heard.first.toLowerCase())) {
      _readPage();
      return;
    }
    setState(() => _question = heard.first);
    if (_hasPage) {
      _ask();
    } else {
      speaker.say(_l.explainNoPage);
    }
  }

  void _readPage() => AppScope.of(context).speaker.say(widget.lines.join('\n'));

  void _nextLanguage() {
    final i = appLanguages.indexWhere((a) => a.code == _language);
    final next = appLanguages[(i + 1) % appLanguages.length];
    setState(() => _language = next.code);
    AppScope.of(context).speaker.say(_l.answerLanguage(next.name));
  }

  void _report() {
    final l = _l;
    AppScope.of(context).speaker.say(l.reportHow);
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l.reportProblem,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        content: Text(l.reportHow, style: const TextStyle(fontSize: 19)),
        actions: [
          PrimaryButton(
            label: MaterialLocalizations.of(dialog).okButtonLabel,
            onTap: () => Navigator.of(dialog).pop(),
          ),
        ],
      ),
    );
  }

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
        if (_question case final q?)
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              container: true,
              label: '${l.youSaid}: $q',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: MaganaColors.ink,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.youSaid,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFC9CED4),
                      ),
                    ),
                    Text(
                      q,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                    messageFor(l, answer.code),
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
        if (_hasPage) ...[
          SecondaryButton(
            label: l.saySimpler,
            onTap: _busy ? null : () => _ask(style: 'simpler'),
          ),
          SecondaryButton(
            label: l.giveExample,
            onTap: _busy ? null : () => _ask(style: 'example'),
          ),
          if (answer?.followup != null)
            SecondaryButton(label: l.explainReadAgain, onTap: _readPage),
          SecondaryButton(label: l.reportProblem, onTap: _report),
        ],
        Text(
          l.explainDisclaimer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: MaganaColors.muted),
        ),
      ],
      bottom: [
        Labelled(
          label: _listening ? l.listeningCommand : l.askAQuestion,
          onTap: _listen,
          child: FilledButton.icon(
            onPressed: _listen,
            icon: Icon(_listening ? Icons.stop : Icons.mic_none, size: 30),
            label: Text(_listening ? l.listeningCommand : l.askAQuestion),
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
