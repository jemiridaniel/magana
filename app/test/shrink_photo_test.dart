// Camera photos are sent upright, at most 1080 px wide, JPEG quality 85 (docs/FINDINGS.md,
// 27 Oct 2026); the photo as it was when the phone can't shrink it.

import 'package:app/platform/shrink_photo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('magana/offline');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks the phone for 1080 px at quality 85', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return Uint8List.fromList([9, 9]);
    });
    expect(await shrinkPhoto(Uint8List.fromList([1, 2, 3, 4])), [9, 9]);
    expect(calls.single.method, 'shrink');
    expect((calls.single.arguments as Map)['maxWidth'], 1080);
    expect((calls.single.arguments as Map)['quality'], 85);
  });

  test('the photo as it was when the phone can\'t shrink it', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'offline'),
    );
    expect(await shrinkPhoto(Uint8List.fromList([1, 2, 3])), [1, 2, 3]);
    messenger.setMockMethodCallHandler(channel, null);
    expect(await shrinkPhoto(Uint8List.fromList([1, 2, 3])), [
      1,
      2,
      3,
    ]); // no plugin: unchanged
  });

  test(
    'a screenshot is sent whole: PNGs; not an unreadable or huge file',
    () async {
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        1,
        2,
      ]);
      expect(await looksLikeScreenshot(png), isTrue);
      expect(
        await looksLikeScreenshot(Uint8List.fromList([1, 2, 3, 4, 5])),
        isFalse,
      );
      final huge = Uint8List(screenshotMaxBytes + 1)..setAll(0, png);
      expect(await looksLikeScreenshot(huge), isFalse);
    },
  );
}
