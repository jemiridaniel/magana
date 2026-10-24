import 'dart:convert';

import 'package:flutter/services.dart';

const letters = ['A', 'B', 'C', 'D'];

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.type = 'choice',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] as String,
    question: j['question'] as String,
    options: List<String>.from(j['options'] as List),
    answer: j['answer'] as int,
    explanation: j['explanation'] as String,
    type: j['type'] as String? ?? 'choice',
  );

  final String id;
  final String question;
  final List<String> options;
  final int answer; // index into options
  final String explanation;

  /// choice (A to D) or true_false (options True, False).
  final String type;
  bool get trueFalse => type == 'true_false';

  /// What the learner says for option [i]: "B", or "true"/"false".
  String spokenAnswer(int i) => trueFalse ? options[i] : letters[i];
}

class Quiz {
  const Quiz({required this.subject, required this.questions});
  final String subject;
  final List<QuizQuestion> questions;

  /// Team-written practice questions bundled with the app (works offline).
  static Future<Quiz> load([String asset = 'assets/quiz/biology.json']) async {
    final j = jsonDecode(await rootBundle.loadString(asset)) as Map;
    return Quiz(
      subject: j['subject'] as String,
      questions: [
        for (final q in j['questions'] as List)
          QuizQuestion.fromJson(q as Map<String, dynamic>),
      ],
    );
  }
}

/// What a spoken reply meant: an option, a command, or nothing we can be sure of.
sealed class Heard {
  const Heard();
}

class Answered extends Heard {
  const Answered(this.index);
  final int index;
}

class Command extends Heard {
  const Command(this.kind);
  final CommandKind kind;
}

class Unclear extends Heard {
  const Unclear();
}

enum CommandKind { repeat, next }

// How recognisers often write a spoken letter.
const _letterWords = {
  'a': 0, 'ay': 0, 'eh': 0, 'hey': 0, 'ei': 0, //
  'b': 1, 'bee': 1, 'be': 1, 'bi': 1,
  'c': 2, 'see': 2, 'sea': 2, 'si': 2, 'cee': 2,
  'd': 3, 'dee': 3, 'di': 3,
};

// Words around a letter that change nothing: "option B", "I think it's C".
const _filler = {
  'option', 'letter', 'answer', 'is', 'its', 'it', 'the', 'i', 'think', //
  'say', 'choose', 'pick', 'my', 'number', 'okay', 'ok', 'um', 'uh', 'er',
  'please',
};

// "Benedict" still names "Benedict's solution".
String _stem(String w) =>
    w.length > 4 && w.endsWith('s') ? w.substring(0, w.length - 1) : w;

// Tone marks, under-dots and hooked letters, so "bí" (Yorùbá) is "bi" and "ɓ" is "b".
const _plain = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ǎ': 'a',
  'ā': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ẹ': 'e',
  'ě': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ị': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ọ': 'o',
  'ǒ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ụ': 'u',
  'ṣ': 's',
  'ń': 'n',
  'ǹ': 'n',
  'ṅ': 'n',
  'ɓ': 'b',
  'ɗ': 'd',
  'ƙ': 'k',
  'ƴ': 'y',
};

String _plainLetters(String s) => String.fromCharCodes([
  for (final r in s.runes)
    if (r < 0x300 || r > 0x36F) // combining accents
      ...(_plain[String.fromCharCode(r)] ?? String.fromCharCode(r)).runes,
]);

// True/false answers, in English, Hausa, Yorùbá and Igbo (drafts for review).
const _trueWords = {
  'true',
  'correct',
  'right',
  'yes',
  'i',
  'ee',
  'eh',
  'beeni',
  'bee ni',
  'gaskiya',
};
const _falseWords = {
  'false',
  'wrong',
  'no',
  'not',
  'aa',
  'a a',
  'rara',
  'mba',
  'karya',
  'iro',
};

String _norm(String s) =>
    _plainLetters(s.toLowerCase())
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();

/// Marks one transcript by fixed rules, never by guessing:
/// 1. "repeat"/"again" or "next"/"skip" are commands;
/// 2. a letter on its own, with optional filler ("option B") is that option;
/// 3. otherwise the whole option text, or a word only that option has
///    ("iodine"), names it, but only if exactly one option matches.
Heard hearOne(String transcript, QuizQuestion q) {
  final text = _norm(transcript);
  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const Unclear();
  if (words.any((w) => w == 'repeat' || w == 'again')) {
    return const Command(CommandKind.repeat);
  }
  if (words.any((w) => w == 'next' || w == 'skip')) {
    return const Command(CommandKind.next);
  }

  final rest = words.where((w) => !_filler.contains(w)).toList();
  if (q.trueFalse) {
    // "i" is Hausa for yes, but also English "I": it counts only on its own.
    final t =
        words.any(_trueWords.contains) ||
        _trueWords.contains(text) ||
        text == 'i';
    final f = words.any(_falseWords.contains) || _falseWords.contains(text);
    if (t != f) return Answered(t ? 0 : 1);
  }
  if (rest.length == 1 && _letterWords.containsKey(rest.single)) {
    return Answered(_letterWords[rest.single]!);
  }

  final padded = ' $text ';
  final whole = [
    for (var i = 0; i < q.options.length; i++)
      if (padded.contains(' ${_norm(q.options[i])} ')) i,
  ];
  if (whole.length == 1) return Answered(whole.single);
  if (whole.length > 1) return const Unclear();

  final optionWords = [
    for (final o in q.options) _norm(o).split(' ').map(_stem).toSet(),
  ];
  final spoken = words.map(_stem).toSet();
  final named = <int>{};
  for (var i = 0; i < optionWords.length; i++) {
    final others = {
      for (var j = 0; j < optionWords.length; j++)
        if (j != i) ...optionWords[j],
    };
    final own = optionWords[i].where(
      (w) => w.length >= 4 && !others.contains(w),
    );
    if (own.any(spoken.contains)) named.add(i);
  }
  return named.length == 1 ? Answered(named.single) : const Unclear();
}

/// The recogniser's best transcript decides. If it is unclear, its other
/// guesses are used only when every one of them that means something agrees.
Heard hear(List<String> transcripts, QuizQuestion q) {
  if (transcripts.isEmpty) return const Unclear();
  final first = hearOne(transcripts.first, q);
  if (first is! Unclear) return first;
  final meant = {
    for (final t in transcripts.skip(1))
      if (hearOne(t, q) case Answered(:final index)) index,
  };
  return meant.length == 1 ? Answered(meant.single) : const Unclear();
}
