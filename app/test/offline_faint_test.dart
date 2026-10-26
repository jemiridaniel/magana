// Faint print read on the phone (as the server's flatten_contrast): a nearly empty or unsure
// reading is tried again on a flattened copy, kept only if it finds more words.
import 'dart:typed_data';

import 'package:app/offline/offline_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'white_paper_test.dart' show FakePhoto, FakeRecognizer, cropReads, seen;

void main() {
  tearDown(() {
    pageRecognizer = MlKitRecognizer();
    offlineFlatten = true;
  });

  test(
    'a faint slip: the flattened copy is read, numbers re-read from it',
    () async {
      final faint = seen('BOARDING', 0.40);
      final flatLine = seen('FLIGHT P4 7123 SEAT 14C GATE B2', 0.95);
      final flat = FakePhoto([flatLine], crop: cropReads(flatLine));
      final photo = FakePhoto([faint], flat: flat);
      pageRecognizer = FakeRecognizer(photo);
      final r = (await readOnPhone(Uint8List(1), mode: 'school'))!;
      expect(r.tips, contains('faint_print'));
      expect(r.items.single.text, 'FLIGHT P4 7123 SEAT 14C GATE B2');
      // The numbers' second readings came from the flattened copy, and agreed.
      expect(r.items.single.unclearWords, isEmpty);
      expect((photo.closed, flat.closed), (true, true)); // both copies deleted
    },
  );

  test('the flattened copy is dropped when it finds fewer words', () async {
    final some = seen('Sunday service 9:30 am', 0.6);
    final flat = FakePhoto([seen('Sun', 0.9)]);
    pageRecognizer = FakeRecognizer(
      FakePhoto([some], crop: cropReads(some), flat: flat),
    );
    final r = (await readOnPhone(Uint8List(1), mode: 'school'))!;
    expect(r.tips, isNot(contains('faint_print')));
    expect(r.items.single.text, 'Sunday service 9:30 am');
    expect(flat.closed, isTrue);
  });

  test('a clear page is never flattened (no extra work)', () async {
    final clear = seen('Plants make food in their leaves today', 0.97);
    final photo = FakePhoto([clear], flat: FakePhoto([]));
    pageRecognizer = FakeRecognizer(photo);
    await readOnPhone(Uint8List(1), mode: 'school');
    expect(photo.flattenedCalls, 0);
  });

  test(
    'faint means under 5 words, or unsure where the phone gives confidence',
    () {
      SeenLine noConf(String t) => SeenLine([
        for (final w in t.split(' ')) SeenWord(w, null, 0, 0, 10, 10),
      ]);
      expect(readsFaint([seen('two words', 0.99)]), isTrue);
      expect(readsFaint([seen('one two three four five', 0.70)]), isTrue);
      expect(readsFaint([seen('one two three four five', 0.90)]), isFalse);
      // iOS: no confidence at all; enough words is enough.
      expect(readsFaint([noConf('one two three four five')]), isFalse);
    },
  );

  test(
    'turned off (for measuring before and after): never flattened',
    () async {
      offlineFlatten = false;
      final photo = FakePhoto([
        seen('BOARDING', 0.4),
      ], flat: FakePhoto([seen('A B C D E F', 0.9)]));
      pageRecognizer = FakeRecognizer(photo);
      await readOnPhone(Uint8List(1), mode: 'school');
      expect(photo.flattenedCalls, 0);
    },
  );
}
