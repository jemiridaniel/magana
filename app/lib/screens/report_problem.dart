import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../platform/device_model.dart';
import '../policy.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings.dart' show appVersion;

/// Report a problem (board 9): what went wrong, from a list; adults (18+) may add a voice
/// note of up to 60 s, under-18s get no recording option at all; "Include this page's text"
/// is off by default and never offered in a Classroom session. A photo is never sent. It goes
/// to the Magana team with the app version, phone model, app language and screen.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, required this.screen, this.pageText});

  /// Where the report came from: reader, explain, settings, home.
  final String screen;

  /// The page being read, if there is one (sent only if switched on).
  final String? pageText;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

enum ProblemKind { readWrong, hardToUse, tooSlow, other }

const _kindCodes = {
  ProblemKind.readWrong: 'read_wrong',
  ProblemKind.hardToUse: 'hard_to_use',
  ProblemKind.tooSlow: 'too_slow',
  ProblemKind.other: 'other',
};

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  ProblemKind? _kind;
  bool _includeText = false;
  NoteRecorder? _recorder;
  bool _recording = false;
  int _seconds = 0;
  Timer? _tick;
  VoiceNote? _note;
  bool _sending = false;
  String? _done;
  String? _error;

  AppLocalizations get _l => AppLocalizations.of(context);
  Tier? get _tier => AppScope.of(context).profile.tier;
  bool get _adult => _tier == Tier.standard;
  bool get _textOffered =>
      (widget.pageText ?? '').trim().isNotEmpty && _tier != Tier.classroom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          AppScope.of(context).speaker
              .say('${_l.reportProblem}. ${_l.reportWhat}'),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_recording) _recorder?.cancel();
    super.dispose();
  }

  String _kindLabel(ProblemKind k) => switch (k) {
    ProblemKind.readWrong => _l.reportReadWrong,
    ProblemKind.hardToUse => _l.reportHardToUse,
    ProblemKind.tooSlow => _l.reportTooSlow,
    ProblemKind.other => _l.reportSomethingElse,
  };

  Future<void> _toggleRecording() async {
    final speaker = AppScope.of(context).speaker;
    if (_recording) return _stopRecording();
    await speaker.stop();
    final r = _recorder ??= noteRecorder();
    if (!await r.start()) {
      if (!mounted) return;
      setState(() => _error = _l.reportNoMic);
      speaker.say(_l.reportNoMic);
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _seconds = 0;
      _note = null;
      _error = null;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _seconds++);
      if (_seconds >= maxVoiceSeconds) _stopRecording(); // 60 s at most
    });
  }

  Future<void> _stopRecording() async {
    _tick?.cancel();
    final note = await _recorder?.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _note = note;
    });
    if (note != null) {
      AppScope.of(context).speaker.say(_l.reportVoiceNote(note.seconds));
    }
  }

  Future<void> _send() async {
    final scope = AppScope.of(context);
    final kind = _kind;
    if (kind == null) {
      setState(() => _error = _l.reportChooseFirst);
      scope.speaker.say(_l.reportChooseFirst);
      return;
    }
    if (_recording) await _stopRecording();
    if (!mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final language = Localizations.localeOf(context).languageCode;
    final pageText = _includeText && _textOffered ? widget.pageText : null;
    final note = _adult ? _note : null; // under 18: never a voice note
    try {
      final v = await appVersion();
      final code = await scope.api.reportProblem(
        kind: _kindCodes[kind]!,
        screen: widget.screen,
        appVersion: '${v.version}+${v.build}',
        phoneModel: await phoneModel(),
        language: language,
        pageText: pageText,
        voiceNote: switch (note) {
          final n? => (bytes: n.bytes, type: n.type, seconds: n.seconds),
          _ => null,
        },
      );
      if (!mounted) return;
      final msg = messageFor(_l, code);
      setState(() => _done = msg);
      scope.speaker.say(msg);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = messageFor(_l, e.code);
      setState(() => _error = msg);
      scope.speaker.say(msg);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (_done case final done?) {
      return PageScaffold(
        body: [
          ScreenHeader(title: l.reportProblem, subtitle: l.reportGoesTo),
          NoteBox(text: done, kind: NoteKind.success),
          PrimaryButton(
            label: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
    return PageScaffold(
      body: [
        ScreenHeader(title: l.reportProblem, subtitle: l.reportGoesTo),
        Semantics(
          header: true,
          child: Text(
            l.reportWhat,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final k in ProblemKind.values)
          ChoiceCard(
            title: _kindLabel(k),
            inGroup: true,
            selected: _kind == k,
            onTap: () => setState(() {
              _kind = k;
              _error = null;
            }),
          ),
        if (_adult) ...[
          if (_note case final note? when !_recording) ...[
            NoteBox(text: l.reportVoiceNote(note.seconds)),
            SecondaryButton(
              label: l.reportDeleteVoice,
              onTap: () => setState(() => _note = null),
            ),
          ] else
            Labelled(
              label: _recording ? l.reportRecording(_seconds) : l.reportRecord,
              onTap: _toggleRecording,
              child: FilledButton.icon(
                onPressed: _toggleRecording,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                  backgroundColor: MaganaColors.amber,
                  foregroundColor: MaganaColors.ink,
                  side: const BorderSide(color: MaganaColors.ink, width: 3),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: Icon(_recording ? Icons.stop : Icons.mic_none, size: 28),
                label: Text(
                  _recording ? l.reportRecording(_seconds) : l.reportRecord,
                ),
              ),
            ),
        ],
        if (_textOffered)
          Labelled(
            label: l.reportIncludeText,
            onTap: () => setState(() => _includeText = !_includeText),
            child: SwitchListTile(
              value: _includeText,
              onChanged: (on) => setState(() => _includeText = on),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l.reportIncludeText,
                style: const TextStyle(fontSize: 19),
              ),
              subtitle: Text(
                l.reportIncludeTextNote,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        if (_error case final e?) NoteBox(text: e, kind: NoteKind.warning),
      ],
      bottom: [
        PrimaryButton(label: l.reportSend, onTap: _sending ? null : _send),
      ],
    );
  }
}

/// Opens Report a problem from [screen], with the page's text if there is one.
void openReportProblem(
  BuildContext context, {
  required String screen,
  String? pageText,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ReportProblemScreen(screen: screen, pageText: pageText),
  ),
);

/// The longest voice note a report takes (the server refuses longer ones).
const maxVoiceSeconds = 60;

class VoiceNote {
  const VoiceNote(this.bytes, this.type, this.seconds);
  final Uint8List bytes;
  final String type; // audio/mp4 on phones, audio/webm in a browser
  final int seconds;
}

/// Records a report's voice note, kept in memory until it is sent (the temporary file is
/// deleted as soon as it is read). Replaceable in tests.
abstract class NoteRecorder {
  /// False when the microphone can't be used (permission refused).
  Future<bool> start();
  Future<VoiceNote?> stop();
  Future<void> cancel();
}

NoteRecorder Function() noteRecorder = RecordNoteRecorder.new;

class RecordNoteRecorder implements NoteRecorder {
  final _rec = AudioRecorder();
  DateTime? _started;

  @override
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}/report-${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _rec.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _started = DateTime.now();
    return true;
  }

  @override
  Future<VoiceNote?> stop() async {
    final at = _started;
    final where = await _rec.stop();
    if (where == null || at == null) return null;
    final seconds = DateTime.now()
        .difference(at)
        .inSeconds
        .clamp(1, maxVoiceSeconds);
    if (kIsWeb) {
      return VoiceNote(
        await http.readBytes(Uri.parse(where)),
        'audio/webm',
        seconds,
      );
    }
    final file = File(where);
    try {
      return VoiceNote(await file.readAsBytes(), 'audio/mp4', seconds);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> cancel() => _rec.cancel();
}
