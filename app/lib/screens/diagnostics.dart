import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../app_scope.dart';
import '../diagnostics.dart';
import '../widgets.dart';

/// Hidden diagnostics (Settings → tap the version 7 times), for testing on real phones: the
/// last reading attempt as numbers and words. Nothing here is saved or sent; no image is kept.
/// In English only: it is for the team, not for learners.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, this.version});
  final String? version;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String? _serverCheck;

  /// The key is an app identifier, not a secret; only its last 4 characters are shown.
  static String get keyLine => apiKey.isEmpty
      ? 'not built in (online reading will be refused)'
      : 'built in, ends …${apiKey.substring(apiKey.length - 4)}';

  Future<void> _checkServer() async {
    setState(() => _serverCheck = 'checking…');
    final r = await AppScope.of(context).api.checkConnection();
    if (mounted) setState(() => _serverCheck = r);
  }

  String _time(DateTime? t) => t == null
      ? '—'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
            '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final a = diagnostics.last;
    final f = a?.frame;
    String pct(double v) => '${(v * 100).round()}%';
    final rows = <(String, String)>[
      ('App', widget.version ?? '—'),
      ('Platform', kIsWeb ? 'web' : defaultTargetPlatform.name),
      ('Server', apiBase),
      ('App key', keyLine),
      // For the pilot allow-list (server RATE_EXEMPT_DEVICES): no daily cap for this phone.
      ('Install ID', deviceId.isEmpty ? '—' : deviceId),
      if (_serverCheck case final c?) ('Server check', c),
      ('Last attempt', a == null ? 'none since the app started' : _time(a.at)),
      if (a != null) ...[
        ('Capture fired', a.capture),
        if (f != null) ...[
          ('Framing said', f.advice?.name ?? '—'),
          (
            'Page detected',
            f.page == null
                ? 'no'
                : 'yes: left ${pct(f.page!.left)}, top ${pct(f.page!.top)}, '
                      'right ${pct(f.page!.right)}, bottom ${pct(f.page!.bottom)}',
          ),
          ('Small item (text, no page)', f.smallItem ? 'yes' : 'no'),
          ('Captured after 6 s of steady text', f.anyway ? 'yes' : 'no'),
          (
            'Text patches',
            '${f.printPatches} of 16, ${f.centrePrint} of 4 in the middle',
          ),
          (
            'Sharpness (blur below 20)',
            f.sharpness?.toStringAsFixed(1) ?? 'no print to judge',
          ),
          ('Tilt (top ÷ bottom width)', f.tilt?.toStringAsFixed(2) ?? '—'),
        ],
        (
          'Photo size',
          a.photoBytes == null ? '—' : '${(a.photoBytes! / 1024).round()} KB',
        ),
        ('Read by', a.path ?? 'not read'),
        if (a.screenshot) ('Picture', 'a screenshot, sent whole'),
        if (a.amountsChecked case final n?)
          (
            'Money amounts',
            '$n checked against a second reading, ${a.amountsHeld ?? 0} held back',
          ),
        ('Server status', a.status?.toString() ?? 'no answer'),
        if (a.code != null) ('Server code', a.code!),
        if (a.serverMs != null) ('Server time', '${a.serverMs} ms'),
        if (a.retried case final code?)
          ('Sent again', 'the first try failed ($code)'),
        ('Tips', a.tips.isEmpty ? 'none' : a.tips.join(', ')),
        (
          'Words read',
          a.words.isEmpty
              ? 'none'
              : '${a.words.length}: ${[for (final w in a.words) '${w.text} (${w.confidence == null ? 'no confidence' : (w.confidence! * 100).round()})'].join(', ')}',
        ),
        if (a.serverLate)
          (
            'Server answer',
            'arrived after the phone had read it: the Reader shows the phone\'s reading; '
                'the server\'s went to My library',
          ),
        (
          'Unclear, and why',
          a.reasons.isEmpty ? 'nothing' : a.reasons.join(' | '),
        ),
      ],
      ('Speech started', _time(diagnostics.speechStarted)),
      (
        'Speech finished',
        '${_time(diagnostics.speechFinished)}${diagnostics.speechOutcome == null ? '' : ' (${diagnostics.speechOutcome})'}',
      ),
      // The exact text sent to the voice, newest last, with how long it played.
      for (final (n, u)
          in diagnostics.utterances.reversed.take(15).toList().reversed.indexed)
        (
          'Spoken ${n + 1}',
          '${_time(u.asked)}, ${u.started == null
                  ? 'never started'
                  : u.finished == null
                  ? 'still speaking'
                  : '${u.finished!.difference(u.started!).inMilliseconds} ms'}'
              '${u.outcome == null ? '' : ' (${u.outcome})'}: "${u.text}"',
        ),
    ];
    return PageScaffold(
      body: [
        const ScreenHeader(
          title: 'Diagnostics',
          subtitle:
              'The last attempt, in this app only. Nothing is saved or sent.',
        ),
        SecondaryButton(label: 'Check the server', onTap: _checkServer),
        for (final (k, v) in rows)
          Semantics(
            container: true,
            label: '$k: $v',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$k: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: v),
                  ],
                ),
                style: const TextStyle(fontSize: 18, height: 1.35),
              ),
            ),
          ),
      ],
    );
  }
}
