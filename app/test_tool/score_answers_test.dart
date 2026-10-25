// Scores recognised quiz answers with the app's own rules (benchmark/asr/answers_bench.py
// runs it). Not part of `flutter test`: run with
//   ANSWERS_IN=transcripts.jsonl ANSWERS_OUT=scored.jsonl flutter test test_tool/score_answers_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:app/quiz.dart';
import 'package:app/voice_answers.dart' as voice_answers;
import 'package:flutter_test/flutter_test.dart';

// Option texts that no answer word can match, so only the letter rules count.
const _choice = QuizQuestion(
  id: 'x',
  question: 'x',
  options: ['qqq', 'vvv', 'xxx', 'zzz'],
  answer: 0,
  explanation: '',
);
const _trueFalse = QuizQuestion(
  id: 'tf',
  question: 'x',
  options: ['True', 'False'],
  answer: 0,
  explanation: '',
  type: 'true_false',
);

/// right, wrong or unclear (asked again) for what the learner meant.
String score(String intended, String transcript) {
  switch (intended) {
    case 'A' || 'B' || 'C' || 'D':
      return switch (hear([transcript], _choice)) {
        Answered(:final index) => letters[index] == intended ? 'right' : 'wrong',
        _ => 'unclear',
      };
    case 'true' || 'false':
      return switch (hear([transcript], _trueFalse)) {
        Answered(:final index) =>
          (index == 0) == (intended == 'true') ? 'right' : 'wrong',
        _ => 'unclear',
      };
    default: // yes, no: the "You said B. Is that right?" confirmation
      final v = voice_answers.yesNo(transcript);
      if (v is! bool) return 'unclear';
      return v == (intended == 'yes') ? 'right' : 'wrong';
  }
}

void main() {
  test('score recognised answers', () {
    final input = Platform.environment['ANSWERS_IN'];
    final output = Platform.environment['ANSWERS_OUT'];
    if (input == null || output == null) return; // nothing to score
    final out = StringBuffer();
    for (final line in File(input).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final row = jsonDecode(line) as Map<String, dynamic>;
      row['outcome'] = score(row['intended'] as String, row['transcript'] as String);
      out.writeln(jsonEncode(row));
    }
    File(output).writeAsStringSync(out.toString());
  });
}
