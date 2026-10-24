import 'dart:typed_data';

import 'package:app/capture/frame_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

const w = 48, h = 64;

/// A dark table (40) with a white page (230) covering [l, t, r, b) in grid cells.
LumaGrid page(
  int l,
  int t,
  int r,
  int b, {
  int table = 40,
  int paper = 230,
  int shift = 0,
}) {
  final data = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inPage = x >= l + shift && x < r + shift && y >= t && y < b;
      // A few dark "text" cells on the page, like printed lines.
      final text =
          inPage &&
          (y - t) % 6 == 3 &&
          y > t + 1 &&
          y < b - 2 &&
          x > l + shift + 2 &&
          x < r + shift - 2;
      data[y * w + x] = inPage ? (text ? 60 : paper) : table;
    }
  }
  return LumaGrid(w, h, data);
}

Advice settle(FrameAnalyzer a, LumaGrid g, [int frames = 1]) {
  late Advice last;
  for (var i = 0; i < frames; i++) {
    last = a.analyze(g);
  }
  return last;
}

void main() {
  test(
    'a whole, steady page is ready only after a second of steady frames',
    () {
      final a = FrameAnalyzer(steadyFramesNeeded: 4);
      final g = page(6, 6, 42, 58);
      expect(
        [for (var i = 0; i < 4; i++) a.analyze(g)],
        [Advice.holdStill, Advice.holdStill, Advice.holdStill, Advice.ready],
      );
      expect(a.readyToCapture, isTrue);
    },
  );

  test('each cut edge gives its own direction', () {
    expect(settle(FrameAnalyzer(), page(6, 0, 42, 50)), Advice.moveUp);
    expect(settle(FrameAnalyzer(), page(6, 14, 42, 64)), Advice.moveDown);
    expect(settle(FrameAnalyzer(), page(0, 6, 36, 58)), Advice.moveLeft);
    expect(settle(FrameAnalyzer(), page(12, 6, 48, 58)), Advice.moveRight);
  });

  test('a page bigger than the view asks to lift the phone', () {
    expect(
      settle(FrameAnalyzer(), page(0, 0, 48, 64, table: 230)),
      isNot(Advice.ready),
    );
    expect(settle(FrameAnalyzer(), page(4, 0, 44, 64)), Advice.liftPhone);
    expect(settle(FrameAnalyzer(), page(0, 4, 48, 60)), Advice.liftPhone);
  });

  test('a small page asks to come closer', () {
    expect(settle(FrameAnalyzer(), page(16, 20, 32, 40)), Advice.moveCloser);
  });

  test('darkness and an empty view are named', () {
    expect(
      settle(FrameAnalyzer(), page(6, 6, 42, 58, table: 10, paper: 40)),
      Advice.tooDark,
    );
    expect(
      settle(
        FrameAnalyzer(),
        LumaGrid(w, h, Uint8List(w * h)..fillRange(0, w * h, 120)),
      ),
      Advice.noPage,
    );
  });

  test('movement resets the steady count', () {
    final a = FrameAnalyzer(steadyFramesNeeded: 3);
    settle(a, page(6, 6, 42, 58), 2);
    expect(a.analyze(page(6, 6, 42, 58, shift: 3)), Advice.holdStill);
    expect(a.readyToCapture, isFalse);
  });

  test('frames are turned upright before deciding which edge is cut', () {
    // Android back cameras deliver landscape frames turned 90 degrees: the
    // page's top edge (as the user holds the phone) is the sensor frame's left edge.
    const fw = 128, fh = 96, stride = 130;
    final bytes = Uint8List(stride * fh);
    for (var y = 0; y < fh; y++) {
      for (var x = 0; x < fw; x++) {
        final inPage = x < 100 && y > 10 && y < 86; // touches sensor-left only
        bytes[y * stride + x] = inPage ? 230 : 40;
      }
    }
    final g = LumaGrid.sample(
      bytes: bytes,
      frameWidth: fw,
      frameHeight: fh,
      rowStride: stride,
      quarterTurns: 1,
    );
    expect((g.width, g.height), (48, 64));
    expect(settle(FrameAnalyzer(), g), Advice.moveUp);
  });

  test('BGRA frames read the green channel', () {
    final bytes = Uint8List(4 * 4 * 4);
    for (var i = 0; i < 16; i++) {
      bytes[i * 4 + 1] = 200; // green
    }
    final g = LumaGrid.sample(
      bytes: bytes,
      frameWidth: 4,
      frameHeight: 4,
      rowStride: 16,
      pixelStride: 4,
      channelOffset: 1,
      cols: 2,
      rows: 2,
    );
    expect(g.data, everyElement(200));
  });

  test('light wood or a wall is not mistaken for a page', () {
    // Brightness of the emulator's wood room: background about 55, wood about 100.
    expect(
      settle(FrameAnalyzer(), page(6, 0, 42, 50, table: 55, paper: 100)),
      Advice.noPage,
    );
  });
}
