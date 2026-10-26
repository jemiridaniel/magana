import 'language.dart';
import 'policy.dart';

/// What "Hold to speak" on Home can do: every main action is one spoken command
/// (CLAUDE.md: "every action reachable by one voice command").
enum VoiceCommand {
  // Specific before general: "read my test results" is Everyday papers, not the
  // quiz or Read a page; "report a problem" is not a medical report.
  report(null, ['report a problem', 'problem', 'something wrong']),
  reminders(Feature.reminders, ['reminder', 'remind']),
  nurse(Feature.healthCallback, ['nurse', 'pharmacist', 'health worker']),
  everyday(Feature.everydayHealth, [
    'everyday',
    'medicine',
    'label',
    'report',
    'result',
    'bank',
    'statement',
    'letter',
    'receipt',
  ]),
  quiz(Feature.quiz, ['quiz', 'practice', 'practise', 'test']),
  library(Feature.library, ['library', 'saved']),
  skills(Feature.skills, ['skill', 'lesson']),
  score(Feature.score, ['score', 'independence', 'progress']),
  // Like the Home tile: open questions are 18+ (Guided learners use Explain
  // this from the Reader, on a school page).
  ask(Feature.openChat, ['ask', 'question', 'explain']),
  language(null, ['language', ...languageWords]),
  settings(null, ['settings', 'setting', 'version']),
  help(null, ['help', 'what can i say', 'commands']),
  readPage(Feature.readSchoolwork, ['read', 'camera', 'photo', 'page']);

  const VoiceCommand(this.feature, this.words);

  /// The tier must allow this; null for commands everyone has.
  final Feature? feature;
  final List<String> words;
}

const languageWords = ['english', 'hausa', 'yoruba', 'yorùbá', 'igbo'];

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-zà-ỹ' ]"), ' ')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

/// The command a transcript asks for, by fixed keyword rules in this order, or
/// null. A command the tier can't use is never matched (it is not offered).
VoiceCommand? matchCommand(String transcript, bool Function(Feature) can) {
  final text = ' ${_norm(transcript)} ';
  for (final c in VoiceCommand.values) {
    if (c.feature != null && !can(c.feature!)) continue;
    // Whole words, so "test" doesn't match "latest"; "skill" matches "skills".
    if (c.words.any((w) => RegExp(' ${RegExp.escape(w)}s? ').hasMatch(text))) {
      return c;
    }
  }
  return null;
}

/// A language named in the transcript ("change language to Igbo"), or null.
AppLanguage? namedLanguage(String transcript) {
  final text = _norm(transcript);
  for (final lang in appLanguages) {
    final names = {lang.name.toLowerCase(), _norm(lang.name)};
    if (lang.code == 'yo') names.add('yoruba');
    if (names.any((n) => RegExp('\\b$n\\b').hasMatch(text))) return lang;
  }
  return null;
}

/// What "Speak a command" in the Reader can do (board 5c: "Next column" by voice too).
/// Specific before general: "next column" before "next".
enum ReaderCommand {
  report(['report a problem', 'problem']),
  nextColumn(['next column', 'column']),
  headings(['heading', 'headings']),
  spell(['spell']),
  next(['next', 'forward']),
  previous(['previous', 'back', 'before']),
  repeat(['repeat', 'again']),
  pause(['pause', 'stop', 'wait']),
  play(['read', 'play', 'continue', 'start']),
  help(['help', 'what can i say', 'commands']);

  const ReaderCommand(this.words);
  final List<String> words;
}

/// The Reader command a transcript asks for, or null.
ReaderCommand? matchReaderCommand(String transcript) {
  final text = ' ${_norm(transcript)} ';
  for (final c in ReaderCommand.values) {
    if (c.words.any((w) => RegExp(' ${RegExp.escape(w)} ').hasMatch(text))) {
      return c;
    }
  }
  return null;
}
