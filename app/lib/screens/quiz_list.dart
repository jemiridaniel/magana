import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../curriculum.dart';
import '../api.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../profile.dart';
import '../quiz.dart';
import '../widgets.dart';
import 'quiz.dart';

/// Practice quizzes. On their own, learners get the team-made sample packs for
/// their class's band (every band without a class). A teacher's quizzes appear
/// only inside a class session the teacher opens on this phone with the
/// session's code from the portal, for any age group: never by class level.
class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  List<Quiz> _fromTeacher = const [];
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      final level = AppScope.of(context).profile.level;
      return [
        l.practiceQuiz,
        level == null ? l.quizChooseClassHint : l.quizYourClass(level.name),
      ].join('. ');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessionQuizzes());
  }

  Future<void> _loadSessionQuizzes() async {
    final scope = AppScope.of(context);
    final code = scope.profile.sessionCode;
    if (code == null) return; // on their own: sample packs only
    try {
      final quizzes = await scope.api.sessionQuizzes(code);
      if (mounted) setState(() => _fromTeacher = quizzes);
      if (quizzes.isEmpty && mounted) {
        scope.speaker.say(AppLocalizations.of(context).quizSessionEmpty);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final text = messageFor(l, e.code);
      if (e.code == 'session_code_invalid') scope.profile.endTeacherSession();
      setState(() => _sessionError = text);
      scope.speaker.say(text);
    }
  }

  Future<void> _openSession() async {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final field = TextEditingController();
    scope.speaker.say(l.quizSessionPrompt);
    final code = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l.quizSessionPrompt,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: field,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 24, letterSpacing: 2),
          decoration: InputDecoration(labelText: l.quizSessionCodeLabel),
          onSubmitted: (v) => Navigator.of(dialog).pop(v),
        ),
        actions: [
          SecondaryButton(
            label: l.cancel,
            onTap: () => Navigator.of(dialog).pop(),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: l.quizSessionStart,
            onTap: () => Navigator.of(dialog).pop(field.text),
          ),
        ],
      ),
    );
    final typed = code?.replaceAll(RegExp(r'\s'), '').toUpperCase() ?? '';
    if (typed.isEmpty || !mounted) return;
    scope.profile.startTeacherSession(code: typed);
    setState(() => _sessionError = null);
    await _loadSessionQuizzes();
  }

  void _endSession() {
    AppScope.of(context).profile.endTeacherSession();
    setState(() => _fromTeacher = const []);
  }

  void _open(Future<Quiz> Function() load) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => QuizScreen(load: load)));

  Widget _heading(String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = AppScope.of(context).profile;
    final level = profile.level;
    final bands = level == null ? Band.values : [level.band];
    return PageScaffold(
      body: [
        ScreenHeader(
          title: l.practiceQuiz,
          subtitle: level == null ? null : l.quizYourClass(level.name),
        ),
        if (level == null &&
            profile.classLevel != ProfileController.notInSchool)
          NoteBox(text: l.quizChooseClassHint),
        if (profile.sessionCode case final code?) ...[
          _heading('${l.quizFromTeacher}: ${l.quizSessionActive(code)}'),
          if (_fromTeacher.isEmpty) NoteBox(text: l.quizSessionEmpty),
          for (final quiz in _fromTeacher)
            ChoiceCard(
              title: quiz.title,
              detail:
                  '${quiz.subjectName}. ${l.quizCount(quiz.questions.length)}',
              leading: const Icon(Icons.school_outlined, size: 30),
              onTap: () => _open(() async => quiz),
            ),
          SecondaryButton(label: l.quizSessionEnd, onTap: _endSession),
        ] else ...[
          if (_sessionError case final e?)
            NoteBox(text: e, kind: NoteKind.warning),
          SecondaryButton(label: l.quizSessionOpen, onTap: _openSession),
        ],
        _heading(l.quizSamples),
        for (final band in bands) ...[
          if (bands.length > 1) _heading(bandNames[band]!),
          for (final subject in samplePacks[band]!)
            ChoiceCard(
              title: l.quizSubjectTitle(subjectNames[subject]!),
              detail: '${bandNames[band]}. ${l.quizSamples}',
              leading: const Icon(Icons.quiz_outlined, size: 30),
              onTap: () =>
                  _open(() => Quiz.load(samplePackAsset(band, subject))),
            ),
        ],
      ],
    );
  }
}
