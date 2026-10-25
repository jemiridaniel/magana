/// Languages whose spoken quiz answers are recognised well enough to offer "Say":
/// at least 80% right in the closed-set test, clean and noisy clips together
/// (docs/FINDINGS.md, "closed set"). None yet: English 79%, Hausa 51%, Yorùbá
/// 58%, Igbo 28%, so tapping is the default and the Say button is hidden.
/// The confirm step ("You said B. Is that right?") stays everywhere.
/// A variable so tests can turn voice answers on.
Set<String> voiceAnswersReady = {};

/// Spoken quick-check answers, by fixed word rules: yes, no, "I can't tell", or a
/// number of days. Anything else is null and the question is asked again; never
/// a guess. The Hausa, Yorùbá and Igbo words are drafts for native-speaker review.
// Hausa "i" (yes) only counts as the whole answer: in "No, I haven't" it is English "I".
const _yes = {'yes', 'yeah', 'yep', 'eh', 'ee', 'beeni', 'bẹ́ẹ̀ni', 'bee ni'};
const _no = {'no', 'nope', "a'a", 'aa', 'rara', 'rárá', 'mba'};
const _cantTell = [
  "can't tell",
  'cannot tell',
  'cant tell',
  "don't know",
  'dont know',
  'not sure',
  'ban sani ba',
  'mi o mo',
  'mi ò mọ̀',
  'amaghi m',
  'amaghị m',
];
const _numbers = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[.,!?]'), ' ')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

/// true, false, 'cant_tell', or null when unclear (for a yes/no question).
Object? yesNo(String transcript) {
  final t = _norm(transcript);
  if (_cantTell.any(t.contains)) return 'cant_tell';
  final words = t.split(' ').toSet();
  final y = words.any(_yes.contains) || _yes.contains(t) || t == 'i';
  final n = words.any(_no.contains) || _no.contains(t);
  if (y == n) return null; // neither, or both ("yes no")
  return y;
}

/// A number of days (0-60), 'cant_tell', or null when unclear.
Object? days(String transcript) {
  final t = _norm(transcript);
  if (_cantTell.any(t.contains)) return 'cant_tell';
  final found = <int>{
    for (final m in RegExp(r'\b\d{1,2}\b').allMatches(t)) int.parse(m[0]!),
    for (final w in t.split(' ')) ?_numbers[w],
  };
  return found.length == 1 && found.single <= 60 ? found.single : null;
}
