import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../messages.dart';
import '../policy.dart';
import '../theme.dart';
import '../voice_answers.dart' as voice_answers;
import '../voice_input.dart';
import '../questions.dart';
import '../widgets.dart';
import 'everyday.dart';

/// "I can't tell", offered on every quick-check question. It never counts as
/// "no": the backend treats it as unanswered and raises the priority (DRAFT,
/// pending Dr. Amos; see backend triage.CANT_TELL).
const cantTell = 'cant_tell';

/// Opens the phone dialler on a number; replaceable in tests.
Future<void> Function(String number) dial = (number) =>
    launchUrl(Uri(scheme: 'tel', path: number));

/// Opens "Talk to a health worker", optionally with the reason already chosen.
void openHealthWorker(BuildContext context, {String reason = 'medicine'}) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HealthWorkerScreen(reason: reason)),
    );

/// The dark "Emergency? Call 112" banner shown on every health screen. Tapping it dials 112.
class EmergencyBanner extends StatelessWidget {
  const EmergencyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Labelled(
      label: '${l.emergencyBold} ${l.emergencyText}',
      hint: l.call112,
      onTap: () => dial('112'),
      child: InkWell(
        onTap: () => dial('112'),
        borderRadius: BorderRadius.circular(16),
        child: NoteBox(
          bold: l.emergencyBold,
          text: l.emergencyText,
          kind: NoteKind.emergency,
        ),
      ),
    );
  }
}

class HealthWorkerScreen extends StatefulWidget {
  const HealthWorkerScreen({super.key, this.reason = 'medicine'});
  final String reason;

  @override
  State<HealthWorkerScreen> createState() => _HealthWorkerScreenState();
}

class _HealthWorkerScreenState extends State<HealthWorkerScreen> {
  late String _reason = widget.reason;
  String? _callLanguage;
  String? _priority; // from the Ibà quick check, if done
  String? _status;
  bool _busy = false;
  List<String> _questions = const []; // saved from medical reports (E2)

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    SavedQuestions.load().then((q) {
      if (mounted) setState(() => _questions = q);
    });
    speakOnOpen(
      context,
      () =>
          '${_l.healthWorkerTitle}. ${_l.healthWorkerSubtitle}. ${_l.emergencyBold} ${_l.emergencyText}',
    );
  }

  Future<void> _quickCheck() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QuickCheckScreen()));
    if (result != null) setState(() => _priority = result);
  }

  Future<void> _request() async {
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    String code;
    try {
      code = await scope.api.requestCallback(
        reason: _reason,
        language: _callLanguage ?? Localizations.localeOf(context).languageCode,
        priority: _priority,
      );
    } on ApiException catch (e) {
      code = e.code == 'unreachable' ? 'callback_unavailable' : e.code;
    }
    if (!mounted) return;
    final msg = messageFor(_l, code);
    setState(() {
      _busy = false;
      _status = msg;
    });
    scope.speaker.say(msg);
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (!AppScope.of(context).profile.can(Feature.healthCallback)) {
      return const AdultsOnlyScreen();
    }
    final lang = _callLanguage ?? Localizations.localeOf(context).languageCode;
    final reasons = {
      'medicine': l.reasonMedicine,
      'results': l.reasonResults,
      'other': l.reasonOther,
    };
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.healthWorkerTitle,
          subtitle: l.healthWorkerSubtitle,
        ),
        if (_status != null)
          Semantics(liveRegion: true, child: NoteBox(text: _status!)),
        Semantics(
          header: true,
          child: Text(
            l.helpWithTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final MapEntry(key: id, value: label) in reasons.entries)
          ChoiceCard(
            title: label,
            selected: _reason == id,
            inGroup: true,
            leading: Icon(
              _reason == id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 28,
            ),
            onTap: () => setState(() => _reason = id),
          ),
        Semantics(
          header: true,
          child: Text(
            l.callLanguage,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final language in appLanguages)
          ChoiceCard(
            title: language.name,
            selected: lang == language.code,
            inGroup: true,
            leading: Icon(
              lang == language.code
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 28,
            ),
            onTap: () => setState(() => _callLanguage = language.code),
          ),
        if (_priority == null)
          SecondaryButton(label: l.answerIbaFirst, onTap: _quickCheck),
        if (_questions.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Text(
              l.savedQuestionsTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          for (final q in _questions) ...[
            NoteBox(text: q),
            SecondaryButton(
              label: l.removeQuestion(q),
              semanticLabel: l.removeQuestion(q),
              onTap: () async {
                await SavedQuestions.remove(q);
                final left = await SavedQuestions.load();
                if (mounted) setState(() => _questions = left);
              },
            ),
          ],
        ],
      ],
      bottom: [
        PrimaryButton(label: l.requestCallback, onTap: _busy ? null : _request),
        const EmergencyBanner(),
      ],
    );
  }
}

/// Ibà quick check: one question at a time; returns the priority to the caller.
class QuickCheckScreen extends StatefulWidget {
  const QuickCheckScreen({super.key});

  @override
  State<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends State<QuickCheckScreen> {
  late final VoiceInput _voice = voiceInputFor(context);
  bool? _voiceWorks;
  bool _listening = false;
  List<TriageQuestion>? _questions;
  bool _fromIba = true;
  final Map<String, Object> _answers = {};
  int _index = 0;
  int _days = 1;
  ({String priority, String message})? _result;
  String? _error;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    try {
      final r = await scope.api.triageQuestions(
        Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _questions = r.questions;
        _fromIba = r.fromIba;
      });
      _askCurrent();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = messageFor(_l, e.code));
    }
  }

  /// Questions still to ask: follow-ups only when their parent was answered yes.
  List<TriageQuestion> get _asked => [
    for (final q in _questions ?? const <TriageQuestion>[])
      if (q.askIf == null || _answers[q.askIf] == true) q,
  ];

  String _text(TriageQuestion q) => q.text ?? messageFor(_l, q.message);

  void _askCurrent() {
    final q = _asked[_index];
    AppScope.of(context).speaker.say(_text(q));
  }

  Future<void> _answer(Object value) async {
    final q = _asked[_index];
    setState(() => _answers[q.id] = value);
    if (_index + 1 < _asked.length) {
      setState(() {
        _index++;
        _days = 1;
      });
      _askCurrent();
      return;
    }
    final scope = AppScope.of(context);
    scope.speaker.say(_l.checkingAnswers);
    try {
      final r = await scope.api.triageAssess(_answers);
      if (!mounted) return;
      setState(() => _result = r);
      scope.speaker.say(_resultText(_l, r));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = messageFor(_l, e.code));
    }
  }

  @override
  void dispose() {
    if (_listening) _voice.stop();
    super.dispose();
  }

  /// E6 "Or say yes or no": a spoken answer, by fixed word rules.
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
    final q = _asked[_index];
    final answer = heard.isEmpty
        ? null
        : q.type == 'number'
        ? voice_answers.days(heard.first)
        : voice_answers.yesNo(heard.first);
    if (answer == null) {
      speaker.say(
        heard.isEmpty
            ? _l.commandNothingHeard
            : _l.voiceAnswerUnclear(heard.first),
      );
      return;
    }
    _answer(answer);
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (!AppScope.of(context).profile.can(Feature.healthCallback)) {
      return const AdultsOnlyScreen();
    }
    final result = _result;
    if (result != null) return _resultPage(l, result);
    final asked = _questions == null ? const <TriageQuestion>[] : _asked;
    final q = asked.isEmpty ? null : asked[_index];
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.quickCheckTitle,
          subtitle: q == null
              ? null
              : _fromIba
              ? l.quickCheckProgress(_index + 1, asked.length)
              : l.quickCheckProgressFallback(_index + 1, asked.length),
        ),
        if (_error != null) NoteBox(text: _error!, kind: NoteKind.warning),
        if (q == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (q != null) ...[
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              _text(q),
              style: const TextStyle(
                fontSize: 25,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Labelled(
            label: _listening ? l.listeningCommand : l.sayYesOrNo,
            onTap: _listen,
            child: OutlinedButton.icon(
              onPressed: _listen,
              icon: Icon(_listening ? Icons.stop : Icons.mic_none, size: 28),
              label: Text(_listening ? l.listeningCommand : l.sayYesOrNo),
              style: outlinedTile(radius: 32, bg: MaganaColors.amber).copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
              ),
            ),
          ),
          if (q.type == 'number') ...[
            Semantics(
              liveRegion: true,
              child: Text(
                l.daysCount(_days),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: '−',
                    semanticLabel: l.fewerDays,
                    onTap: _days > 0 ? () => setState(() => _days--) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: '+',
                    semanticLabel: l.moreDays,
                    onTap: _days < 60 ? () => setState(() => _days++) : null,
                  ),
                ),
              ],
            ),
          ],
          // Signs normally checked by looking (DRAFT, pending Dr. Amos):
          // "I can't check" is never a yes, and never leaves the result at
          // routine (the backend raises it to the faster call-back).
          // Only the last two answers: with ten questions a full list was long.
          for (final done in asked.take(_index).toList().reversed.take(2))
            NoteBox(
              text: '${_text(done)} ${_answerText(l, _answers[done.id])}',
            ),
        ],
        NoteBox(text: l.quickCheckNote),
      ],
      // The answers stay pinned above the 112 banner: long questions used to
      // push Yes and No below the screen.
      bottom: [
        if (q != null && q.type == 'number')
          PrimaryButton(label: l.nextLabel, onTap: () => _answer(_days))
        else if (q != null) ...[
          Row(
            children: [
              Expanded(
                child: PrimaryButton(label: l.yes, onTap: () => _answer(true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: l.no,
                  onTap: () => _answer(false),
                ),
              ),
            ],
          ),
        ],
        if (q != null)
          SecondaryButton(label: l.cantTell, onTap: () => _answer(cantTell)),
        const EmergencyBanner(),
      ],
    );
  }

  String _answerText(AppLocalizations l, Object? v) => switch (v) {
    true => l.yes,
    false => l.no,
    cantTell => l.cantTell,
    int days => l.daysCount(days),
    _ => '',
  };

  /// Emergencies get Ibà's own message (go to a clinic now). Otherwise nothing is
  /// booked yet, so say how soon a nurse should call and ask for the call back,
  /// rather than "a nurse will call you".
  String _resultText(
    AppLocalizations l,
    ({String priority, String message}) r,
  ) => switch (r.priority) {
    'emergency' => messageFor(l, r.message),
    // A danger sign answered "I can't tell": ask someone to check first.
    'urgent' when r.message == 'ask_someone_to_check' =>
      '${messageFor(l, r.message)} ${l.resultUrgent}',
    'urgent' => l.resultUrgent,
    _ => l.resultRoutine,
  };

  Widget _resultPage(
    AppLocalizations l,
    ({String priority, String message}) r,
  ) {
    final emergency = r.priority == 'emergency';
    return PageScaffold(
      body: [
        ScreenHeader(title: l.resultTitle),
        Semantics(
          liveRegion: true,
          child: NoteBox(
            text: _resultText(l, r),
            kind: emergency || r.message == 'ask_someone_to_check'
                ? NoteKind.warning
                : NoteKind.info,
          ),
        ),
      ],
      bottom: [
        if (emergency)
          PrimaryButton(label: l.call112, onTap: () => dial('112'))
        else
          PrimaryButton(
            label: l.requestCallback,
            onTap: () => Navigator.of(context).pop(r.priority),
          ),
        SecondaryButton(
          label: l.backHome,
          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        const EmergencyBanner(),
      ],
    );
  }
}
