// A bank receipt read on the phone (Apple Vision gives labels and values as separate lines,
// out of order): each label is read with its value, top to bottom.
import 'package:app/offline/offline_reader.dart';
import 'package:flutter_test/flutter_test.dart';

SeenLine line(String text, int left, int top, {double conf = 1.0}) {
  var x = left;
  return SeenLine([
    for (final w in text.split(' '))
      SeenWord(
        w,
        conf,
        (x += w.length * 20 + 12) - w.length * 20 - 12,
        top,
        w.length * 20,
        40,
      ),
  ]);
}

String text(SeenLine l) => l.words.map((w) => w.text).join(' ');

void main() {
  test('values beside their labels, given out of order: paired row by row', () {
    final seen = [
      line('Transfer successful', 80, 260),
      line('Amount', 80, 420),
      line('Recipient', 80, 540),
      line('N8,000.00', 760, 421),
      line('Ada Okonkwo', 700, 541),
      line('Account number', 80, 660),
      line('0123456789', 740, 660),
    ];
    expect(pairLabels(seen).map(text), [
      'Transfer successful',
      'Amount: N8,000.00',
      'Recipient: Ada Okonkwo',
      'Account number: 0123456789',
    ]);
  });

  test('values under their labels', () {
    final seen = [
      line('Amount', 80, 420),
      line('N8,000.00', 80, 472),
      line('Date', 80, 590),
      line('27 Oct 2026, 11:47', 80, 642),
    ];
    expect(pairLabels(seen).map(text), [
      'Amount: N8,000.00',
      'Date: 27 Oct 2026, 11:47',
    ]);
  });

  test('ordinary text is left as it is', () {
    final seen = [
      line('Take 2 tablets', 80, 100),
      line('every 6 hours', 80, 160),
    ];
    expect(pairLabels(seen).map(text), ['Take 2 tablets', 'every 6 hours']);
  });
}
