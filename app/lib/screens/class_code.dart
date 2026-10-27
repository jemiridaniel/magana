import 'package:flutter/material.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../policy.dart';
import '../theme.dart';
import '../widgets.dart';

/// Class and teacher codes (design canvas A2 and A4): 6 digits on a big keypad,
/// "Read back", and the progress said after every digit ("You typed 4, 8, 2. 3
/// more."). Digits only, so they are easy to say and type with TalkBack.
class CodeKeypad extends StatefulWidget {
  const CodeKeypad({super.key, required this.label, required this.onChanged});

  /// "Class code" or "Teacher code".
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<CodeKeypad> createState() => CodeKeypadState();
}

class CodeKeypadState extends State<CodeKeypad> {
  static const length = 6;
  String _digits = '';

  String get digits => _digits;

  void clear() {
    setState(() => _digits = '');
    widget.onChanged('');
  }

  String _spelled(String d) => d.split('').join(', ');

  String progress(AppLocalizations l) => _digits.isEmpty
      ? l.codeEmpty
      : _digits.length == length
      ? l.codeComplete(_spelled(_digits))
      : l.codeProgress(_spelled(_digits), length - _digits.length);

  void _press(String key) {
    final l = AppLocalizations.of(context);
    final speaker = AppScope.of(context).speaker;
    if (key == 'delete') {
      if (_digits.isEmpty) return;
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    } else if (key == 'read') {
      speaker.say(progress(l));
      return;
    } else {
      if (_digits.length == length) return;
      setState(() => _digits += key);
    }
    widget.onChanged(_digits);
    speaker.say(progress(l));
  }

  Widget _key(String label, String key, {double size = 28, String? semantic}) =>
      Labelled(
        label: semantic ?? label,
        onTap: () => _press(key),
        child: OutlinedButton(
          onPressed: () => _press(key),
          style: outlinedTile(radius: 16).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: l.codeGroup(
            widget.label,
            _digits.isEmpty ? l.codeEmpty : _spelled(_digits),
            _digits.length,
          ),
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < length; i++)
                Container(
                  width: 46,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == _digits.length
                          ? MaganaColors.green
                          : MaganaColors.ink,
                      width: i == _digits.length ? 3 : 2,
                    ),
                  ),
                  child: Text(
                    i < _digits.length ? _digits[i] : '',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: Text(
            progress(l),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: MaganaColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
              _key(d, d),
            _key(l.keypadDelete, 'delete', size: 17),
            _key('0', '0'),
            _key(l.keypadReadBack, 'read', size: 17),
          ],
        ),
      ],
    );
  }
}

/// A2 · Join your class. In onboarding [tier] is the age group just chosen
/// (not saved yet); [onNoCode] is "I don't have a code yet". After joining,
/// [onJoined] gets the class link (A3 shows it).
class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({
    super.key,
    required this.tier,
    required this.onJoined,
    this.onNoCode,
  });

  final Tier tier;
  final void Function(BuildContext context, ClassLink link) onJoined;
  final VoidCallback? onNoCode;

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  String _code = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.joinTitle}. ${l.joinBody}';
    });
  }

  Future<void> _join() async {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    if (_code.length != 6) {
      setState(() => _error = l.codeNeedsSix);
      scope.speaker.say(l.codeNeedsSix);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await scope.api.joinClass(_code, tier: widget.tier.name);
      if (!mounted) return;
      widget.onJoined(context, link);
    } on ApiException catch (e) {
      final msg = messageFor(l, e.code);
      scope.speaker.say(msg);
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PageScaffold(
      body: [
        ScreenHeader(title: l.joinTitle, subtitle: l.joinBody),
        CodeKeypad(
          label: l.classCodeLabel,
          onChanged: (c) => setState(() {
            _code = c;
            _error = null;
          }),
        ),
        if (_error != null) NoteBox(text: _error!, kind: NoteKind.warning),
        if (widget.tier == Tier.guided) NoteBox(text: l.joinUnder18Note),
      ],
      bottom: [
        PrimaryButton(label: l.joinButton, onTap: _busy ? null : _join),
        if (widget.onNoCode != null)
          SecondaryButton(label: l.joinNoCode, onTap: widget.onNoCode),
      ],
    );
  }
}

/// A3 · Class joined.
class JoinedScreen extends StatefulWidget {
  const JoinedScreen({super.key, required this.link, required this.onStart});

  final ClassLink link;
  final VoidCallback onStart;

  @override
  State<JoinedScreen> createState() => _JoinedScreenState();
}

class _JoinedScreenState extends State<JoinedScreen> {
  String _script(AppLocalizations l) => [
    l.joinedTitle,
    widget.link.className,
    if (widget.link.teacher != null) l.joinedTeacher(widget.link.teacher!),
    ?widget.link.school,
    l.joinedRightClass,
    if (widget.link.status == 'waiting_consent') l.joinedWaiting,
  ].join('. ');

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () => _script(AppLocalizations.of(context)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final link = widget.link;
    return PageScaffold(
      body: [
        Semantics(
          header: true,
          child: Text(
            l.joinedTitle,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F1EA),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MaganaColors.green, width: 3),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                size: 72,
                color: MaganaColors.green,
              ),
              const SizedBox(height: 12),
              Text(
                link.className,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (link.teacher != null || link.school != null)
                Text(
                  [
                    if (link.teacher != null) l.joinedTeacher(link.teacher!),
                    ?link.school,
                  ].join('\n'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.4),
                ),
            ],
          ),
        ),
        NoteBox(text: l.joinedRightClass),
        if (link.status == 'waiting_consent')
          NoteBox(text: l.joinedWaiting, kind: NoteKind.warning),
      ],
      bottom: [PrimaryButton(label: l.startReading, onTap: widget.onStart)],
    );
  }
}

/// A4 · Change class for an under-18: the teacher types their own code, then the
/// new class's code. The backend checks both; 3 wrong codes wait 5 minutes.
class TeacherCodeScreen extends StatefulWidget {
  const TeacherCodeScreen({super.key});

  @override
  State<TeacherCodeScreen> createState() => _TeacherCodeScreenState();
}

class _TeacherCodeScreenState extends State<TeacherCodeScreen> {
  final _pad = GlobalKey<CodeKeypadState>();
  String _code = '';
  String? _teacherCode;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return '${l.changeClassTitle}. ${l.teacherCodeNeededTitle}. ${l.teacherCodeBody}';
    });
  }

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    if (_code.length != 6) {
      setState(() => _error = l.codeNeedsSix);
      scope.speaker.say(l.codeNeedsSix);
      return;
    }
    if (_teacherCode == null) {
      // The teacher's part is done: now the new class's code.
      setState(() {
        _teacherCode = _code;
        _code = '';
        _error = null;
      });
      _pad.currentState?.clear();
      scope.speaker.say(l.newClassCodeTitle);
      return;
    }
    setState(() => _busy = true);
    try {
      final link = await scope.api.changeClass(_teacherCode!, _code);
      await scope.profile.setLink(
        ClassLink(
          token: scope.profile.link!.token,
          status: link.status,
          className: link.className,
          level: link.level,
          teacher: link.teacher,
          school: link.school,
        ),
      );
      if (!mounted) return;
      // Said once this screen has closed (a change of screen stops its own voice).
      final voice = AppScope.app(context).speaker;
      Navigator.of(context).pop();
      voice.say(messageFor(l, 'class_changed'));
    } on ApiException catch (e) {
      final msg = messageFor(l, e.code);
      scope.speaker.say(msg);
      if (!mounted) return;
      setState(() {
        _error = msg;
        // A wrong teacher code starts again from the teacher's part.
        if (e.code == 'teacher_code_wrong' || e.code == 'code_locked') {
          _teacherCode = null;
        }
        _code = '';
      });
      _pad.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final link = AppScope.of(context).profile.link;
    final teacherStep = _teacherCode == null;
    return PageScaffold(
      body: [
        ScreenHeader(title: l.changeClassTitle, subtitle: l.settingsClass),
        if (link != null)
          NoteBox(text: '${l.changeClassNow}: ${link.className}'),
        Semantics(
          header: true,
          child: Text(
            teacherStep ? l.teacherCodeNeededTitle : l.newClassCodeTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        if (teacherStep)
          Text(
            l.teacherCodeBody,
            style: const TextStyle(fontSize: 18, height: 1.45),
          ),
        CodeKeypad(
          key: _pad,
          label: teacherStep ? l.teacherCodeLabel : l.classCodeLabel,
          onChanged: (c) => setState(() {
            _code = c;
            _error = null;
          }),
        ),
        if (_error != null) NoteBox(text: _error!, kind: NoteKind.warning),
        NoteBox(text: l.teacherCodeLockNote),
      ],
      bottom: [
        PrimaryButton(label: l.confirmLabel, onTap: _busy ? null : _confirm),
      ],
    );
  }
}
