// Handwriting (Dr. Amos, 28 Oct 2026): schoolwork only, offered as "This looks handwritten.
// Read it anyway?", every number held back; never on health or money papers. And offline on the
// iPhone, numbers on health papers are held: Apple Vision stays sure of handwriting.
import 'dart:convert';

import 'package:app/offline/offline_reader.dart';
import 'package:app/offline/photo_queue.dart';
import 'package:app/papers.dart';
import 'package:app/screens/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'app_test.dart' show FakeSpeaker;
import 'white_paper_test.dart'
    show FakePhoto, FakeRecognizer, FakeVault, cropReads, en, pumpOffline, seen;

final bytes = Uint8List.fromList([1, 2, 3]);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Map<String, dynamic> handwrittenPage() => {
  'tips': ['handwritten_page'],
  'lines': [
    {
      'text': 'Lesson 4 the water cycle',
      'confidence': 0.31,
      'top': 100,
      'words': [
        for (final w in 'Lesson 4 the water cycle'.split(' '))
          {'text': w, 'confidence': 0.31},
      ],
    },
  ],
  'warnings': [
    {'block_index': 0, 'code': 'low_confidence'},
  ],
};

void main() {
  final realSwitch = handwritingReading;
  tearDown(() {
    handwritingReading = realSwitch;
    pageRecognizer = MlKitRecognizer();
  });

  test('switched off until it is measured against typed transcripts', () {
    expect(realSwitch, isFalse);
  });

  group('read on the phone as handwriting', () {
    test(
      'every number is held back, and the page says it may contain mistakes',
      () async {
        final line = seen('Lesson 4 page 12 water cycle', 0.99);
        final page = await readOnPhone(
          bytes,
          mode: 'school',
          handwriting: true,
          recognizer: FakeRecognizer(FakePhoto([line], crop: cropReads(line))),
        );
        expect(page!.tips, contains('handwriting_read_anyway'));
        expect(page.items.single.unclearWords, {1, 3}); // "4" and "12"
      },
    );

    test('never for a health, money or letter paper', () async {
      for (final mode in ['health', 'money', 'letter']) {
        final line = seen('Take 2 tablets', 0.99);
        expect(
          await readOnPhone(
            bytes,
            mode: mode,
            handwriting: true,
            recognizer: FakeRecognizer(FakePhoto([line])),
          ).catchError((_) => null),
          isNull,
          reason: mode,
        );
      }
    });
  });

  group('Capture', () {
    setUp(
      () => photoQueue = PhotoQueue(
        vault: FakeVault(),
        store: MemoryQueueStore(),
      ),
    );

    Future<FakeSpeaker> capture(WidgetTester tester, {Paper? paper}) async {
      final speaker = FakeSpeaker();
      final line = seen('Lesson 4 the water cycle', 0.99);
      pageRecognizer = FakeRecognizer(FakePhoto([line], crop: cropReads(line)));
      await pumpOffline(
        tester,
        speaker,
        client: MockClient(
          (req) async => http.Response(
            jsonEncode(handwrittenPage()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute(
              builder: (_) => CaptureScreen(
                paper: paper,
                findCameras: () async => [],
                picker: (_) async =>
                    XFile.fromData(utf8.encode('png'), name: 'p.png'),
              ),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await settle(tester); // a spinner turns behind the question
      return speaker;
    }

    testWidgets(
      'schoolwork that looks handwritten: offered, and read anyway on a yes',
      (tester) async {
        handwritingReading = true;
        final speaker = await capture(tester);
        expect(find.text(en.handwritingOffer), findsOneWidget);
        expect(speaker.said, contains(en.handwritingOffer));
        await tester.tap(find.bySemanticsLabel(en.readItAnyway));
        await tester.pumpAndSettle();
        expect(
          speaker.said.join(' '),
          contains(en.msg_handwriting_read_anyway),
        );
        expect(speaker.said.where((s) => s.contains('Lesson 4')), isEmpty);
      },
    );

    testWidgets('a medicine label is never offered it', (tester) async {
      handwritingReading = true;
      await capture(tester, paper: Paper.medicine);
      expect(find.text(en.handwritingOffer), findsNothing);
    });

    testWidgets('switched off: never offered', (tester) async {
      handwritingReading = false;
      await capture(tester);
      expect(find.text(en.handwritingOffer), findsNothing);
    });
  });

  group('offline on the iPhone (Apple Vision)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const offline = MethodChannel('magana/offline');
    const mlkit = MethodChannel('google_mlkit_text_recognizer');
    setUp(() {
      // Vision is sure of every word, as it is of handwriting; a crop reads the same.
      final words = [
        for (final (i, w) in 'Take 2 tablets daily'.split(' ').indexed)
          {
            'text': w,
            'confidence': 1.0,
            'left': 40 + i * 120,
            'top': 100,
            'width': 100,
            'height': 40,
          },
      ];
      messenger.setMockMethodCallHandler(offline, (call) async {
        switch (call.method) {
          case 'upright':
            return {'path': 'p.jpg', 'width': 1000, 'height': 1400};
          case 'crop':
            return 'crop.jpg';
          case 'read':
            final crop = (call.arguments as Map)['path'] == 'crop.jpg';
            return [
              {
                'words': crop ? [words[0], words[1], words[2]] : words,
              },
            ];
          default:
            return null;
        }
      });
      messenger.setMockMethodCallHandler(mlkit, (call) async => null);
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(offline, null);
      messenger.setMockMethodCallHandler(mlkit, null);
    });

    test('a health paper: every number held, and the page says why', () async {
      final page = await readOnPhone(
        bytes,
        mode: 'health',
        recognizer: VisionRecognizer(),
      );
      expect(page!.tips, contains('offline_health_numbers'));
      expect(page.items.single.unclearWords, {1});
    });

    test(
      'schoolwork: a sure number that reads the same twice is still said',
      () async {
        final page = await readOnPhone(
          bytes,
          mode: 'school',
          recognizer: VisionRecognizer(),
        );
        expect(page!.tips, isNot(contains('offline_health_numbers')));
        expect(page.items.single.unclearWords, isEmpty);
      },
    );
  });
}
