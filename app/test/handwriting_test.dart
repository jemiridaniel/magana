// A handwritten number on a health paper is never spoken as a number (backend
// safety.handwritten_health): the reader says "unclear number" in its place.
import 'package:app/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handwritten_number hides the number like any number warning', () {
    final result = ReadResult.fromJson({
      'tips': ['mixed_page', 'handwritten_prescription'],
      'lines': [
        {
          'text': 'take 2 tabs',
          'top': 10,
          'words': [
            {'text': 'take'},
            {'text': '2'},
            {'text': 'tabs'},
          ],
        },
      ],
      'warnings': [
        {'block_index': 0, 'code': 'handwritten_number', 'word_index': 1},
      ],
    });
    final line = result.items.single;
    expect(line.unclearWords, {1});
    expect(line.code, 'handwritten_number');
    expect(result.tips, ['mixed_page', 'handwritten_prescription']);
  });
}
