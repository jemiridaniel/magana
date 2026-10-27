import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/api.dart';
import 'package:app/capture/frame_analysis.dart';
import 'package:app/commands.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/language.dart';
import 'package:app/library.dart';
import 'package:app/main.dart';
import 'package:app/offline/offline_reader.dart';
import 'package:app/offline/photo_queue.dart';
import 'package:app/policy.dart';
import 'package:app/profile.dart';
import 'package:app/screens/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y.dart';
import 'app_test.dart' show FakeSpeaker, captureToReader, pumpApp;
import 'frame_analysis_test.dart' show page;

final en = lookupAppLocalizations(const Locale('en'));

/// A two-column page as the backend returns it: column 1, then column 2, though
/// their lines sit at the same heights (layout.arrange), with a title across both.
const columnsJson = {
  'tips': <String>[],
  'columns': 2,
  'lines': [
    {
      'text': 'Basic Science',
      'confidence': 0.97,
      'top': 10,
      'column': 0,
      'heading': true,
    },
    {
      'text': 'Plants',
      'confidence': 0.97,
      'top': 100,
      'column': 1,
      'heading': true,
    },
    {
      'text': 'Plants make food in their leaves.',
      'confidence': 0.96,
      'top': 160,
      'column': 1,
    },
    {
      'text': 'They need sunlight and water.',
      'confidence': 0.96,
      'top': 220,
      'column': 1,
    },
    {
      'text': 'Animals',
      'confidence': 0.97,
      'top': 100,
      'column': 2,
      'heading': true,
    },
    {
      'text': 'Animals cannot make their own food.',
      'confidence': 0.96,
      'top': 160,
      'column': 2,
    },
  ],
  'warnings': <Object>[],
};

/// A Hausa page: two words may have lost a special letter (letters.py). Never changed.
const hausaJson = {
  'tips': ['letters_ha'],
  'page_language': 'ha',
  'lines': [
    {
      'text': 'Kasar tana da dalibai',
      'confidence': 0.92,
      'top': 10,
      'words': [
        {'text': 'Kasar'},
        {'text': 'tana'},
        {'text': 'da'},
        {'text': 'dalibai'},
      ],
    },
  ],
  'warnings': <Object>[],
  'letter_marks': [
    {'block_index': 0, 'word_index': 0},
    {'block_index': 0, 'word_index': 3},
  ],
};

// ---------- offline fakes

class FakePhoto implements OfflinePhoto {
  FakePhoto(this.lines, {this.crop, this.flat});
  final List<SeenLine> lines;
  final FakePhoto? flat; // what the flattened copy reads (faint print)
  int flattenedCalls = 0;
  @override
  Future<OfflinePhoto?> flattened() async {
    flattenedCalls++;
    return flat;
  }

  final List<SeenLine>? Function(int left, int top, int width, int height)?
  crop;
  bool closed = false;
  @override
  int get width => 1000;
  @override
  int get height => 1400;
  @override
  Future<List<SeenLine>> read() async => lines;
  @override
  Future<List<SeenLine>?> readCrop(
    int l,
    int t,
    int w,
    int h,
    double s,
  ) async => crop == null ? null : crop!(l, t, w, h);
  @override
  Future<List<double>?> inkDepth(List<SeenWord> words) async => null;
  @override
  Future<void> close() async => closed = true;
}

class FakeRecognizer implements PageRecognizer {
  FakeRecognizer(this.photo);
  final FakePhoto? photo;
  int opened = 0;
  @override
  Future<OfflinePhoto?> open(Uint8List bytes) async {
    opened++;
    return photo;
  }
}

class FakeVault implements Vault {
  @override
  Future<Uint8List> encrypt(Uint8List plain) async =>
      Uint8List.fromList([...plain.reversed, 7]);
  @override
  Future<Uint8List> decrypt(Uint8List sealed) async => Uint8List.fromList(
    sealed.sublist(0, sealed.length - 1).reversed.toList(),
  );
}

SeenLine seen(String text, double confidence, {int top = 100}) {
  var x = 40;
  return SeenLine([
    for (final w in text.split(' '))
      SeenWord(
        w,
        confidence,
        (x += w.length * 20 + 20) - w.length * 20,
        top,
        w.length * 20,
        30,
      ),
  ]);
}

/// A crop read again: the words of [line] inside the crop, or [instead] for numbers.
List<SeenLine> Function(int, int, int, int) cropReads(
  SeenLine line, {
  String? instead,
}) =>
    (l, t, cw, ch) => [
      SeenLine([
        for (final w in line.words)
          if (w.left >= l &&
              w.left + w.width <= l + cw &&
              w.top >= t &&
              w.top + w.height <= t + ch)
            SeenWord(
              instead != null && RegExp(r'\d').hasMatch(w.text)
                  ? instead
                  : w.text,
              0.95,
              w.left,
              w.top,
              w.width,
              w.height,
            ),
      ]),
    ];

/// Capture with no camera (the system picker), then "Take photo"; no settling.
Future<void> openCaptureAndTakePhoto(WidgetTester tester) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(
        MaterialPageRoute(
          builder: (_) => CaptureScreen(
            findCameras: () async => [],
            picker: (_) async =>
                XFile.fromData(utf8.encode('png'), name: 'p.png'),
          ),
        ),
      );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.bySemanticsLabel('Take photo'));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpOffline(
  WidgetTester tester,
  FakeSpeaker speaker, {
  required MockClient client,
  Tier tier = Tier.standard,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaganaApp(
      api: MaganaApi(client: client),
      speaker: speaker,
      language: LanguageController(const Locale('en')),
      profile: ProfileController(tier: tier),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late MemoryQueueStore queueStore;
  setUp(() {
    queueStore = MemoryQueueStore();
    photoQueue = PhotoQueue(vault: FakeVault(), store: queueStore);
  });
  tearDown(() => pageRecognizer = MlKitRecognizer());

  // ---------- board 5c: two columns, headings

  test(
    'a page in columns keeps the backend order: column 1, then column 2',
    () {
      final r = ReadResult.fromJson(columnsJson);
      expect(r.columns, 2);
      expect(r.items.map((i) => i.text).toList(), [
        'Basic Science',
        'Plants',
        'Plants make food in their leaves.',
        'They need sunlight and water.',
        'Animals',
        'Animals cannot make their own food.',
      ]);
      expect(r.items.where((i) => i.heading).length, 3);
    },
  );

  testWidgets('5c: column position, Next column, headings, page map, 64 px', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final speaker = FakeSpeaker();
    await pumpApp(tester, speaker, body: columnsJson);
    await captureToReader(tester);
    expect(
      speaker.said.where(
        (s) => s.contains('2 columns. Left first, then right.'),
      ),
      hasLength(1),
    );
    expect(find.text('2 columns. Left first, then right.'), findsOneWidget);
    expect(speaker.said, contains('Heading: Basic Science'));
    expect(speaker.said, contains('Column 1 of 2. Heading: Plants'));
    expect(speaker.said, contains('Column 2 of 2. Heading: Animals'));
    expectAccessible(tester, 'Reader (two columns)');

    // Headings: each heading, to jump to; then "Next column" skips to column 2.
    await tester.tap(find.bySemanticsLabel('Headings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heading: Plants'));
    await tester.pumpAndSettle();
    expect(speaker.said.last, 'Column 1 of 2. Heading: Plants');
    expect(
      find.bySemanticsLabel(RegExp('^Column 1 of 2 · Line 1 of 3')),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Next column'));
    await tester.pumpAndSettle();
    expect(speaker.said.last, 'Column 2 of 2. Heading: Animals');
    expect(
      find.bySemanticsLabel(RegExp('^Column 2 of 2 · Line 1 of 2')),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Next column'));
    await tester.pumpAndSettle();
    expect(speaker.said.last, 'This is the last column.');

    handle.dispose();
  });

  test('Reader voice commands: "next column" before "next"', () {
    expect(matchReaderCommand('next column please'), ReaderCommand.nextColumn);
    expect(matchReaderCommand('next'), ReaderCommand.next);
    expect(matchReaderCommand('go back'), ReaderCommand.previous);
    expect(matchReaderCommand('spell it'), ReaderCommand.spell);
    expect(matchReaderCommand('show the headings'), ReaderCommand.headings);
    expect(matchReaderCommand('banana'), isNull);
  });

  // ---------- board 5d: letter check

  testWidgets(
    '5d: a Hausa page warns once, marks words, spells them, never changes them',
    (tester) async {
      final handle = tester.ensureSemantics();
      final speaker = FakeSpeaker();
      await pumpApp(tester, speaker, body: hausaJson);
      await captureToReader(tester);
      final warning = en.msg_letters_ha;
      final intro = speaker.said.firstWhere((s) => s.contains(warning));
      expect(intro, contains('2 words may be wrong.'));
      expect(speaker.said.join(' ').split(warning).length, 2); // once
      expect(find.textContaining('Hausa page · '), findsOneWidget);
      // The line is read as printed, then the marked words.
      expect(
        speaker.said,
        contains(
          'Kasar tana da dalibai. These words may be missing a special letter: Kasar, dalibai.',
        ),
      );
      expectAccessible(tester, 'Reader (letter check)');
      await tester.ensureVisible(find.bySemanticsLabel('Spell word'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Spell word'));
      await tester.pumpAndSettle();
      expect(
        speaker.said.last,
        'Kasar: K, a, s, a, r. dalibai: d, a, l, i, b, a, i',
      );
      await tester.ensureVisible(find.bySemanticsLabel('Ask someone'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Ask someone'));
      await tester.pumpAndSettle();
      expect(
        speaker.said.last,
        'Ask someone who reads Hausa to check the marked words.',
      );
      expect(
        find.textContaining('Kasar'),
        findsWidgets,
      ); // shown as read, not "ƙasar"
      expect(
        find.textContaining('ƙ'),
        findsOneWidget,
      ); // only in the warning note
      handle.dispose();
    },
  );

  // ---------- board 5e: offline basic reading

  testWidgets(
    '5e: no internet: read on the phone, numbers kept safe, queued encrypted',
    (tester) async {
      final handle = tester.ensureSemantics();
      final speaker = FakeSpeaker();
      final dose = seen('Take 2 tablets every 6 hours', 0.97);
      final store = seen('Store below 30 degrees', 0.97, top: 200);
      final shaky = seen('Not more than 8 in a day', 0.97, top: 300);
      final photo = FakePhoto(
        [dose, store, shaky],
        crop: (l, t, w, h) {
          // The second reading of "8" disagrees; the others agree.
          if (t > 250) return cropReads(shaky, instead: '6')(l, t, w, h);
          return cropReads(t > 150 ? store : dose)(l, t, w, h);
        },
      );
      pageRecognizer = FakeRecognizer(photo);
      var posts = 0;
      await pumpOffline(
        tester,
        speaker,
        client: MockClient((req) async {
          posts++;
          throw const SocketException('offline');
        }),
      );
      await captureToReader(tester);
      expect(
        find.text(
          "The photo didn't reach Magana's server (connection problem). Reading on this phone.",
        ),
        findsOneWidget,
      );
      expect(
        speaker.said.where(
          (s) => s.startsWith(
            "The photo didn't reach Magana's server (connection problem). Reading on this phone. Basic reading only.",
          ),
        ),
        hasLength(1),
      );
      expect(speaker.said, contains('Take 2 tablets every 6 hours'));
      expect(speaker.said, contains('Store below 30 degrees'));
      expect(
        speaker.said.any(
          (s) => s.startsWith('Not more than unclear number in a day'),
        ),
        isTrue,
      );
      expect(
        find.bySemanticsLabel('Explain this'),
        findsNothing,
      ); // needs internet
      expect(find.bySemanticsLabel('Headings'), findsNothing);
      expect(photo.closed, isTrue); // its files are deleted
      expectAccessible(tester, 'Reader (offline)');
      await tester.pumpAndSettle();
      expect(await photoQueue.length, 1);
      expect(
        queueStore.items.values.single,
        isNot(utf8.encode('png')),
      ); // encrypted
      expect(
        posts,
        2,
      ); // a failed send is tried once more before reading on the phone
      handle.dispose();
    },
  );

  testWidgets(
    '5e: a number below 0.90 or without a second reading is unclear offline',
    (tester) async {
      final low = seen('Take 2 tablets', 0.85);
      pageRecognizer = FakeRecognizer(FakePhoto([low], crop: cropReads(low)));
      var r = (await readOnPhone(Uint8List(1), mode: 'health'))!;
      expect(r.items.single.unclearWords, {1});
      final ok = seen('Take 2 tablets', 0.97);
      pageRecognizer = FakeRecognizer(FakePhoto([ok])); // no crop reading here
      r = (await readOnPhone(Uint8List(1), mode: 'health'))!;
      expect(r.items.single.unclearWords, {1});
      pageRecognizer = FakeRecognizer(FakePhoto([ok], crop: cropReads(ok)));
      r = (await readOnPhone(Uint8List(1), mode: 'health'))!;
      expect(r.items.single.unclearWords, isEmpty);
      expect(r.offline, isTrue);
    },
  );

  test(
    '5e: a money page offline with an unreliable amount keeps only what passed',
    () async {
      final good = seen('01/10/2026 Transfer 5,000.00', 0.97);
      final bad = seen('03/10/2026 Airtime 500.00', 0.70, top: 200);
      pageRecognizer = FakeRecognizer(
        FakePhoto([
          good,
          bad,
        ], crop: (l, t, w, h) => cropReads(t > 150 ? bad : good)(l, t, w, h)),
      );
      final r = (await readOnPhone(Uint8List(1), mode: 'money'))!;
      expect(r.tips.take(2), [
        'money_amounts_unreliable',
        'reading_incomplete',
      ]);
      expect(r.items.map((i) => i.text), ['01/10/2026 Transfer 5,000.00']);
    },
  );

  test('5e: text touching the photo edge is reported offline', () async {
    final line = SeenLine([const SeenWord('Plants', 0.97, 900, 500, 100, 30)]);
    pageRecognizer = FakeRecognizer(FakePhoto([line]));
    final r = (await readOnPhone(Uint8List(1), mode: 'school'))!;
    expect(r.tips, ['cut_off_right']);
  });

  testWidgets(
    '5e: a slow server: "Still reading…" at 5 s, read on the phone after 25 s, the full reading still saved',
    (tester) async {
      final speaker = FakeSpeaker();
      pageRecognizer = FakeRecognizer(
        FakePhoto([seen('Plants make food', 0.97)]),
      );
      await pumpOffline(
        tester,
        speaker,
        client: MockClient((req) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response(
            jsonEncode(columnsJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await openCaptureAndTakePhoto(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(speaker.said, contains('Still reading…'));
      await tester.pump(
        const Duration(seconds: 20),
      ); // past the 25 s wait: read on the phone
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Magana's server took longer than 25 seconds. Reading on this phone.",
        ),
        findsOneWidget,
      );
      await tester.pump(
        const Duration(seconds: 5),
      ); // the server answers after all
      await tester.pumpAndSettle();
      expect(speaker.said, contains('Plants make food'));
      final saved = await Library.load();
      expect(
        saved.single.result.columns,
        2,
      ); // the server's full reading, in My library
      expect(await photoQueue.length, 0); // nothing needed to wait
    },
  );

  for (final (code, banner) in [
    (
      'too_many_requests',
      "Magana's server is busy this minute. Reading on this phone.",
    ),
    (
      'daily_limit',
      "You've used today's server readings. Reading on this phone; the server reads again tomorrow.",
    ),
  ]) {
    testWidgets(
      '5e: a 429 ($code) is said as it is, and the page is read on the phone',
      (tester) async {
        final speaker = FakeSpeaker();
        pageRecognizer = FakeRecognizer(
          FakePhoto([seen('Plants make food', 0.97)]),
        );
        var posts = 0;
        await pumpOffline(
          tester,
          speaker,
          client: MockClient((req) async {
            posts++;
            return http.Response(
              jsonEncode({
                'detail': {'code': code},
              }),
              429,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        await captureToReader(tester);
        expect(find.text(banner), findsOneWidget);
        expect(speaker.said, contains('Plants make food'));
        expect(posts, 1); // never retried: the server said why
        expect(speaker.said.any((t) => t.contains("isn't answering")), isFalse);
      },
    );
  }

  testWidgets('5e: a Classroom phone reads offline but never keeps the photo', (
    tester,
  ) async {
    pageRecognizer = FakeRecognizer(
      FakePhoto([seen('Plants make food', 0.97)]),
    );
    final profile = ProfileController(
      tier: Tier.classroom,
      teacherSession: true,
    );
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaganaApp(
        api: MaganaApi(
          client: MockClient(
            (req) async => throw const SocketException('offline'),
          ),
        ),
        speaker: FakeSpeaker(),
        language: LanguageController(const Locale('en')),
        profile: profile,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await openCaptureAndTakePhoto(tester);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      find.text(
        "The photo didn't reach Magana's server (connection problem). Reading on this phone.",
      ),
      findsOneWidget,
    );
    expect(find.text('Full reading when online'), findsNothing);
    expect(await photoQueue.length, 0);
  });

  test(
    '5e: at most 20 wait, the oldest go first; online, they go to My library',
    () async {
      SharedPreferences.setMockInitialValues({});
      final folder = await Directory.systemTemp.createTemp('queue');
      addTearDown(() => folder.delete(recursive: true));
      photoQueue = PhotoQueue(
        vault: FakeVault(),
        store: FileQueueStore(folder: () async => folder),
      );
      var dropped = 0;
      for (var i = 0; i < 22; i++) {
        dropped += await photoQueue.add(
          Uint8List.fromList([i]),
          mode: 'school',
        );
      }
      expect(dropped, 2);
      expect(await photoQueue.length, 20);
      var sent = 0;
      final api = MaganaApi(
        client: MockClient((req) async {
          if (++sent == 3) throw const SocketException('offline again');
          return http.Response(
            jsonEncode(columnsJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(await photoQueue.drain(api), 2); // stops when offline again
      expect(await photoQueue.length, 18);
      expect((await Library.load()).length, 2);
      expect(await photoQueue.drain(api), 18);
      expect(await photoQueue.length, 0);
    },
  );

  // ---------- capture: tilt and blur

  test(
    'tilt is told from the page edges: top narrower means tilt the top away',
    () {
      LumaGrid trapezoid({required bool topNarrow}) {
        final g = page(6, 6, 42, 58);
        for (var y = 6; y < 58; y++) {
          final t = (y - 6) / 52; // 0 at the top, 1 at the bottom
          final inset = ((topNarrow ? 1 - t : t) * 8).round();
          for (var x = 6; x < 42; x++) {
            if (x < 6 + inset || x >= 42 - inset) g.data[y * 48 + x] = 40;
          }
        }
        return g;
      }

      // A tip only (27 Oct 2026): the photo is still taken, the server straightens it.
      final away = FrameAnalyzer()..analyze(trapezoid(topNarrow: true));
      expect(away.tiltTip, Advice.tiltAway);
      expect(away.report.advice, isNot(Advice.tiltAway));
      final toward = FrameAnalyzer()..analyze(trapezoid(topNarrow: false));
      expect(toward.tiltTip, Advice.tiltToward);
      expect(
        FrameAnalyzer().analyze(page(6, 6, 42, 58)),
        Advice.holdStill,
      ); // square: fine
    },
  );

  test(
    'a blurry frame is never auto-captured; no print in view is not "blurry"',
    () {
      final a = FrameAnalyzer(steadyFramesNeeded: 2);
      final blurry = page(6, 6, 42, 58).withSharpness(8);
      expect([
        for (var i = 0; i < 5; i++) a.analyze(blurry),
      ], everyElement(Advice.blurry));
      expect(a.readyToCapture, isFalse);
      final sharp = page(6, 6, 42, 58).withSharpness(150);
      expect([for (var i = 0; i < 2; i++) a.analyze(sharp)].last, Advice.ready);
      expect(
        FrameAnalyzer(steadyFramesNeeded: 1)
            .analyze(page(6, 6, 42, 58).withSharpness(null)),
        Advice.ready,
      );
    },
  );

  test('sharpness: printed strokes score high, the same blurred low, flat paper null', () {
    const w = 400, h = 400;
    Uint8List frame({required bool blur}) {
      final b = Uint8List(w * h)..fillRange(0, w * h, 230);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if ((x ~/ 6) % 3 == 0 && (y ~/ 20) % 2 == 0) {
            b[y * w + x] = 30; // strokes
          }
        }
      }
      if (!blur) return b;
      final out = Uint8List.fromList(b);
      for (var y = 6; y < h - 6; y++) {
        for (var x = 6; x < w - 6; x++) {
          var s = 0;
          for (var dy = -6; dy <= 6; dy++) {
            for (var dx = -6; dx <= 6; dx++) {
              s += b[(y + dy) * w + x + dx];
            }
          }
          out[y * w + x] = s ~/ 169;
        }
      }
      return out;
    }

    double? score(Uint8List b) =>
        sharpnessOf(bytes: b, frameWidth: w, frameHeight: h, rowStride: w);
    expect(score(frame(blur: false))!, greaterThan(FrameAnalyzer.blurLimit));
    expect(score(frame(blur: true))!, lessThan(FrameAnalyzer.blurLimit));
    expect(score(Uint8List(w * h)..fillRange(0, w * h, 230)), isNull);
  });
}
