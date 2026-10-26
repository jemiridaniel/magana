// iOS: the on-device speech check reaches the iPhone's channel; under-18s never get Apple's
// online recogniser; ML Kit on iOS gives no confidence, so offline every number is "unclear
// number" and the page gets one warning instead of one per line.
import 'package:app/offline/offline_reader.dart';
import 'package:app/platform/speech_support.dart';
import 'package:app/policy.dart';
import 'package:app/voice_input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'white_paper_test.dart' show FakePhoto, FakeRecognizer, cropReads;

SeenLine noConfidence(String text, {int top = 100}) {
  var x = 40;
  return SeenLine([
    for (final w in text.split(' '))
      SeenWord(
        w,
        null,
        (x += w.length * 20 + 20) - w.length * 20,
        top,
        w.length * 20,
        30,
      ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    pageRecognizer = MlKitRecognizer();
  });

  test(
    'iPhone: the on-device check asks the phone (MaganaChannels.swift)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final asked = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('magana/speech'), (
            call,
          ) async {
            asked.add(call.method);
            return true;
          });
      expect(await onDeviceSpeechAvailable(), isTrue);
      expect(asked, ['onDeviceAvailable']);
    },
  );

  test("under 18: no Apple (or Google) online recogniser, on any platform", () {
    for (final tier in [Tier.guided, Tier.classroom]) {
      final steps = voiceSteps(tier);
      expect(
        steps.whereType<SpeechVoiceInput>().every((s) => s.onDevice),
        isTrue,
        reason: tier.name,
      );
    }
    expect(
      voiceSteps(Tier.standard)
          .whereType<SpeechVoiceInput>()
          .map((s) => s.onDevice),
      [true, false],
    );
  });

  test(
    'ML Kit without confidence (iOS): every number unclear, one page warning',
    () async {
      final a = noConfidence('Take 2 tablets daily');
      final b = noConfidence('Plants make food', top: 200);
      pageRecognizer = FakeRecognizer(
        FakePhoto([
          a,
          b,
        ], crop: (l, t, w, h) => cropReads(t > 150 ? b : a)(l, t, w, h)),
      );
      final r = (await readOnPhone(Uint8List(1), mode: 'school'))!;
      expect(r.tips.first, 'offline_no_confidence');
      expect(r.items[0].unclearWords, {1});
      expect(
        r.items[1].codes,
        isEmpty,
      ); // no "I'm not sure about line 2" on every line
    },
  );
}
