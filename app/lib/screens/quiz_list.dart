import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../curriculum.dart';
import '../l10n/app_localizations.dart';
import '../profile.dart';
import '../quiz.dart';
import '../widgets.dart';
import 'quiz.dart';

/// Practice quizzes for the learner's class: their teacher's quizzes first
/// (assigned in the portal), then the team-made sample packs for the class's
/// band. Without a class (an adult not in school), every band's packs.
class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  List<Quiz> _fromTeacher = const [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTeacherQuizzes());
  }

  Future<void> _loadTeacherQuizzes() async {
    final scope = AppScope.of(context);
    final level = scope.profile.level;
    if (level == null) return;
    try {
      final quizzes = await scope.api.learnerQuizzes(level.id);
      if (mounted) setState(() => _fromTeacher = quizzes);
    } catch (_) {
      // Offline or not set up: the bundled samples still work.
    }
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
        if (_fromTeacher.isNotEmpty) ...[
          _heading(l.quizFromTeacher),
          for (final quiz in _fromTeacher)
            ChoiceCard(
              title: quiz.title,
              detail:
                  '${quiz.subjectName}. ${l.quizCount(quiz.questions.length)}',
              leading: const Icon(Icons.school_outlined, size: 30),
              onTap: () => _open(() async => quiz),
            ),
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
