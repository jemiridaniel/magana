// Receipts said aloud (tester's dark-mode transfer receipt, 27 Oct 2026): naira amounts as
// "naira", account numbers digit by digit; the digits themselves never change.
import 'package:app/spoken_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('naira amounts, written ₦ or NGN', () {
    expect(spokenNumbers('Amount: ₦8,000.00'), 'Amount: 8,000 naira');
    expect(spokenNumbers('Fee ₦10.50'), 'Fee 10 naira 50 kobo');
    expect(spokenNumbers('Total: NGN 1,250,000'), 'Total: 1,250,000 naira');
    expect(spokenNumbers('Total: NGN1,250,000.00'), 'Total: 1,250,000 naira');
  });

  test('the currency is never guessed: # and N are said as printed', () {
    for (final t in ['Amount: #8,000.00', 'Fee N10.50', 'Total: N1,250,000']) {
      expect(spokenNumbers(t), t);
    }
  });

  test('account numbers and references digit by digit', () {
    expect(
      spokenNumbers('Account number: 0123456789'),
      'Account number: 0 1 2 3 4 5 6 7 8 9',
    );
    expect(
      spokenNumbers('Reference: TRF2026102711470001'),
      'Reference: TRF 2 0 2 6 1 0 2 7 1 1 4 7 0 0 0 1',
    );
  });

  test('everything else is said as printed', () {
    for (final t in [
      'Take 2 tablets every 6 hours',
      'Date: 27 Oct 2026, 11:47',
      'Room N5',
      'Call 112 now',
      'unclear number',
    ]) {
      expect(spokenNumbers(t), t);
    }
  });
}
