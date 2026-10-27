// The iPhone test of 27 Oct 2026 (docs/FINDINGS.md): a small church card held against a wall,
// and a torn, faint boarding pass. Capture must not wait for page edges that never come.
// Synthetic frames only: no real photo is in the repository.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app/capture/frame_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frame_analysis_test.dart' show page;

const fw = 640, fh = 480;

/// A full-resolution grey frame: a pale, slightly mottled wall (214), with an optional small
/// card (250) holding lines of print in [card] = (left, top, right, bottom) pixels.
Uint8List frame({(int, int, int, int)? card, int seed = 1}) {
  final rnd = math.Random(seed);
  final data = Uint8List(fw * fh);
  for (var y = 0; y < fh; y++) {
    for (var x = 0; x < fw; x++) {
      var v = 214 + rnd.nextInt(5) - 2;
      if (card case (final l, final t, final r, final b)
          when x >= l && x < r && y >= t && y < b) {
        // Print: 3-pixel strokes in rows of letters.
        final inLine = (y - t) % 18 < 9 && x > l + 8 && x < r - 8;
        v = inLine && (x ~/ 3).isEven ? 30 : 250;
      }
      data[y * fw + x] = v;
    }
  }
  return data;
}

LumaGrid grid(Uint8List bytes) =>
    LumaGrid.sample(
      bytes: bytes,
      frameWidth: fw,
      frameHeight: fh,
      rowStride: fw,
    ).withText(
      frameTextOf(bytes: bytes, frameWidth: fw, frameHeight: fh, rowStride: fw),
    );

/// A grid with print in [patches] patches ([centre] of them in the middle).
LumaGrid withPrint(LumaGrid g, int patches, int centre) =>
    g.withText((sharpness: 120.0, patches: patches, centre: centre));

void main() {
  test('print is found patch by patch; a plain wall has none', () {
    final card = frameTextOf(
      bytes: frame(card: (180, 130, 460, 300)),
      frameWidth: fw,
      frameHeight: fh,
      rowStride: fw,
    );
    expect(card.patches, greaterThanOrEqualTo(4));
    expect(card.centre, 4);
    expect(card.sharpness, greaterThan(FrameAnalyzer.blurLimit));
    final wall = frameTextOf(
      bytes: frame(),
      frameWidth: fw,
      frameHeight: fh,
      rowStride: fw,
    );
    expect((wall.patches, wall.sharpness), (0, null));
  });

  test('a small card on a pale wall: no page edges, yet captured after a steady second', () {
    final a = FrameAnalyzer(steadyFramesNeeded: 4);
    final g = grid(frame(card: (180, 130, 460, 300)));
    expect(
      [for (var i = 0; i < 4; i++) a.analyze(g)],
      [Advice.holdStill, Advice.holdStill, Advice.holdStill, Advice.ready],
    );
    expect(a.report.smallItem, isTrue);
    expect(a.report.anyway, isFalse);
  });

  test('"Move closer" only when the print is too small: one patch of it', () {
    final a = FrameAnalyzer();
    expect(a.analyze(withPrint(grid(frame()), 1, 1)), Advice.moveCloser);
    // Print in several patches: read it, never "move closer".
    expect(a.analyze(withPrint(grid(frame()), 3, 1)), Advice.holdStill);
  });

  test('a plain wall (no print) is never captured, however long', () {
    var now = DateTime(2026, 10, 27, 9);
    final a = FrameAnalyzer(clock: () => now);
    final wall = grid(frame());
    for (var s = 0; s < 20; s++) {
      expect(a.analyze(wall), Advice.noPage);
      now = now.add(const Duration(seconds: 1));
    }
  });

  test('never blocked forever: 4 s of text in view and it captures anyway', () {
    var now = DateTime(2026, 10, 27, 9);
    final a = FrameAnalyzer(clock: () => now);
    // A slip running off the left side of the view: guidance says "move left"...
    final slip = withPrint(page(0, 10, 30, 50), 6, 2);
    final seen = <Advice>[];
    for (var s = 0; s <= 4; s++) {
      seen.add(a.analyze(slip));
      now = now.add(const Duration(seconds: 1));
    }
    expect(seen.take(4), everyElement(Advice.moveLeft));
    // ...until 4 s of text in view: then it is taken, and the server says what is cut off.
    expect(seen.last, Advice.ready);
    expect(a.readyToCapture, isTrue);
    expect(a.report.anyway, isTrue);
  });

  test(
    'a moment of hand shake keeps the 4 s; moving away for longer restarts it',
    () {
      var now = DateTime(2026, 10, 27, 9);
      final a = FrameAnalyzer(clock: () => now);
      final still = withPrint(page(0, 10, 30, 50), 6, 2);
      final moved = withPrint(page(0, 10, 30, 50, shift: 8), 6, 2);
      final blank = page(0, 10, 30, 50); // no print in view
      Advice step(LumaGrid g, int ms) {
        final advice = a.analyze(g);
        now = now.add(Duration(milliseconds: ms));
        return advice;
      }

      step(still, 1000);
      step(still, 1000);
      step(moved, 500); // a shake...
      step(still, 1000);
      step(still, 1000); // 3.5 s
      // 4.5 s after the text came into view: the shake didn't restart the clock.
      expect(step(still, 1000), Advice.ready);
      a.reset();
      step(still, 1000);
      step(still, 1000);
      step(blank, 2000); // text out of view for 2 s
      step(still, 1000);
      expect(step(still, 1000), isNot(Advice.ready));
    },
  );

  test('tilt never blocks: a tip only', () {
    final a = FrameAnalyzer(steadyFramesNeeded: 1);
    // A page whose top is much narrower than its bottom (tilted), fully in view.
    final data = page(6, 6, 42, 58).data;
    for (var y = 6; y < 20; y++) {
      for (var x = 6; x < 42; x++) {
        if (x < 14 || x >= 34) data[y * 48 + x] = 40; // the top end narrower
      }
    }
    final tilted = LumaGrid(48, 64, data);
    expect(a.analyze(tilted), Advice.ready);
    expect(a.tiltTip, Advice.tiltAway);
  });

  test(
    'a real page held too close (print everywhere) still hears "further away"',
    () {
      final a = FrameAnalyzer();
      final close = withPrint(page(0, 0, 48, 64), 14, 4);
      expect(a.analyze(close), Advice.liftPhone);
    },
  );
}
