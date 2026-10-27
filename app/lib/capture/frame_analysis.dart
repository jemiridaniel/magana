import 'dart:math' as math;
import 'dart:typed_data';

/// A small greyscale picture of one camera frame (0 = black, 255 = white),
/// row-major and already turned the way the user holds the phone.
class LumaGrid {
  LumaGrid(
    this.width,
    this.height,
    this.data, {
    this.sharpness,
    this.printPatches = 0,
    this.centrePrint = 0,
  }) : assert(data.length == width * height);

  final int width;
  final int height;
  final Uint8List data;

  /// How sharp the print is, from full-resolution patches ([sharpnessOf]);
  /// null when no patch held print (then blur isn't judged).
  final double? sharpness;

  /// How many of the 16 full-resolution patches ([frameTextOf]) hold print, and how many
  /// of the middle 4 do: text in view, whether or not a page's edges can be seen.
  final int printPatches;
  final int centrePrint;

  bool get textInView => printPatches > 0;

  LumaGrid withSharpness(double? s) => LumaGrid(
    width,
    height,
    data,
    sharpness: s,
    printPatches: printPatches,
    centrePrint: centrePrint,
  );

  LumaGrid withText(FrameText t) => LumaGrid(
    width,
    height,
    data,
    sharpness: t.sharpness,
    printPatches: t.patches,
    centrePrint: t.centre,
  );

  int at(int x, int y) => data[y * width + x];

  /// Samples a [frameWidth] x [frameHeight] luma plane (any row and pixel
  /// stride, e.g. Android's Y plane or one channel of iOS BGRA) down to a
  /// [cols] x [rows] grid, then turns it [quarterTurns] clockwise so the top of
  /// the grid is the top of what the user sees.
  factory LumaGrid.sample({
    required Uint8List bytes,
    required int frameWidth,
    required int frameHeight,
    required int rowStride,
    int pixelStride = 1,
    int channelOffset = 0,
    int quarterTurns = 0,
    int cols = 48,
    int rows = 64,
  }) {
    // Sample in sensor orientation, sized so the result is cols x rows after turning.
    final turned = quarterTurns.isOdd;
    final sw = turned ? rows : cols, sh = turned ? cols : rows;
    final sensor = Uint8List(sw * sh);
    for (var gy = 0; gy < sh; gy++) {
      final y = ((gy + 0.5) * frameHeight / sh).floor();
      for (var gx = 0; gx < sw; gx++) {
        final x = ((gx + 0.5) * frameWidth / sw).floor();
        sensor[gy * sw + gx] =
            bytes[y * rowStride + x * pixelStride + channelOffset];
      }
    }
    return LumaGrid(sw, sh, sensor).turned(quarterTurns);
  }

  /// This grid turned [quarterTurns] x 90 degrees clockwise.
  LumaGrid turned(int quarterTurns) {
    final q = quarterTurns % 4;
    if (q == 0) return this;
    final w = q.isOdd ? height : width, h = q.isOdd ? width : height;
    final out = Uint8List(w * h);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final (nx, ny) = switch (q) {
          1 => (height - 1 - y, x),
          2 => (width - 1 - x, height - 1 - y),
          _ => (y, width - 1 - x),
        };
        out[ny * w + nx] = at(x, y);
      }
    }
    return LumaGrid(w, h, out);
  }
}

/// Print in a frame, from 48 x 48 pixel patches on a 4 x 4 grid over the middle 80% of the
/// frame, at full resolution: how sharp the print is (the strongest edges, the 95th
/// percentile of the absolute Laplacian), how many patches hold print, and how many of the
/// middle 4. Patches without print (flat paper, a plain wall) are skipped, so a blank middle
/// never reads as blur. Rendered pages at the camera's size (docs/FINDINGS.md): sharp about
/// 200, a light blur (sigma 0.8) 28 to 64, sigma 1.5 11 to 18, sigma 2.5 5 to 7.
typedef FrameText = ({double? sharpness, int patches, int centre});

FrameText frameTextOf({
  required Uint8List bytes,
  required int frameWidth,
  required int frameHeight,
  required int rowStride,
  int pixelStride = 1,
  int channelOffset = 0,
}) {
  const size = 48, grid = 4;
  double? best;
  var patches = 0, centre = 0;
  final values = Float64List((size - 2) * (size - 2));
  int at(int x, int y) =>
      bytes[y * rowStride + x * pixelStride + channelOffset];
  for (var gy = 0; gy < grid; gy++) {
    for (var gx = 0; gx < grid; gx++) {
      final x0 = (frameWidth * (0.1 + 0.8 * gx / grid)).floor();
      final y0 = (frameHeight * (0.1 + 0.8 * gy / grid)).floor();
      if (x0 + size > frameWidth || y0 + size > frameHeight) continue;
      var sum = 0.0, sq = 0.0;
      for (var y = y0; y < y0 + size; y++) {
        for (var x = x0; x < x0 + size; x++) {
          final v = at(x, y);
          sum += v;
          sq += v * v;
        }
      }
      final n = size * size;
      final std = math.sqrt(math.max(0, sq / n - (sum / n) * (sum / n)));
      if (std < 12) continue; // flat: no print to judge
      var i = 0;
      for (var y = y0 + 1; y < y0 + size - 1; y++) {
        for (var x = x0 + 1; x < x0 + size - 1; x++) {
          values[i++] =
              (4 * at(x, y) -
                      at(x - 1, y) -
                      at(x + 1, y) -
                      at(x, y - 1) -
                      at(x, y + 1))
                  .abs()
                  .toDouble();
        }
      }
      final sorted = Float64List.fromList(values)..sort();
      final p95 = sorted[(sorted.length * 0.95).floor()];
      best = best == null ? p95 : math.max(best, p95);
      patches++;
      if ((gx == 1 || gx == 2) && (gy == 1 || gy == 2)) centre++;
    }
  }
  return (sharpness: best, patches: patches, centre: centre);
}

/// The sharpness part of [frameTextOf]: null when every patch is flat.
double? sharpnessOf({
  required Uint8List bytes,
  required int frameWidth,
  required int frameHeight,
  required int rowStride,
  int pixelStride = 1,
  int channelOffset = 0,
}) => frameTextOf(
  bytes: bytes,
  frameWidth: frameWidth,
  frameHeight: frameHeight,
  rowStride: rowStride,
  pixelStride: pixelStride,
  channelOffset: channelOffset,
).sharpness;

/// What the user should do next. Spoken about every second while framing.
enum Advice {
  tooDark,
  noPage,
  moveCloser,
  liftPhone,
  moveUp,
  moveDown,
  moveLeft,
  moveRight,
  tiltToward,
  tiltAway,
  blurry,
  holdStill,
  ready,
}

/// Decides, frame by frame, whether a page is in view, whole, lit and steady.
///
/// It looks for the page as the bright region against a darker background,
/// which is how printed pages are photographed on tables and laps. Thresholds
/// are deliberately simple and named so they can be tuned with testers.
/// What the analyser saw in the last frame, for the hidden diagnostics screen. No image.
typedef FrameReport = ({
  Advice? advice,
  ({double left, double top, double right, double bottom})? page,
  double? sharpness,
  double? tilt,
  int printPatches,
  int centrePrint,
  bool smallItem,
  bool anyway,
});

class FrameAnalyzer {
  FrameAnalyzer({this.steadyFramesNeeded = 4, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Steady text in view this long: capture anyway, whatever else the guidance says, so a
  /// card, receipt or torn slip is never refused forever (docs/FINDINGS.md, 27 Oct 2026).
  static const captureAnywayAfter = Duration(seconds: 4);

  /// Hand shake while holding a card doesn't restart that clock; only text out of view, or
  /// moving for longer than this, does.
  static const moveGrace = Duration(milliseconds: 1500);

  /// No page edges, but print in at least this many patches with one in the middle: a small
  /// item (card, receipt, label, boarding pass) to read as it is. Print in fewer: too small.
  static const smallItemPatches = 2;

  /// A page too close for the view has print in more than half the 16 patches.
  static const pageFillPatches = 8;

  /// Consecutive good, steady frames before auto-capture (about a second at
  /// the 4-5 frames a second the Capture screen analyses).
  final int steadyFramesNeeded;

  static const darkMean = 45; // average brightness below this is too dark
  static const minContrast = 35; // page vs background, in grey levels
  // Paper under auto-exposure is near white; light wood or a wall is not.
  // Measured on the emulator's wood room: about 100.
  static const minPaper = 140;
  // A row/column is page when it is at least this share of the page's widest one.
  static const pageRow = 0.5;
  static const minPageArea = 0.30; // smaller than this: bring the phone closer
  static const shakeLimit =
      7.0; // mean frame-to-frame change that counts as moving
  // The page's top edge this much narrower than its bottom (or the other way):
  // the phone is tilted, so one end of the page is further from the camera.
  static const tiltLimit = 0.85;
  // Sharpness ([sharpnessOf]) below this is too blurry to read: no auto-capture.
  static const blurLimit = 20.0;

  LumaGrid? _previous;
  int _steady = 0;
  Advice? _last;
  DateTime? _textSince;
  DateTime? _lostSince; // text out of view or the phone moving, since
  bool _tiltSeen =
      false; // the page is tilted: said once as a tip, never blocks
  ({double left, double top, double right, double bottom})? _page;
  double? _tilt;
  bool _smallItem = false;
  bool _anyway = false;
  LumaGrid? _lastGrid;

  /// The last frame, as numbers (diagnostics).
  FrameReport get report => (
    advice: _last,
    page: _page,
    sharpness: _lastGrid?.sharpness,
    tilt: _tilt,
    printPatches: _lastGrid?.printPatches ?? 0,
    centrePrint: _lastGrid?.centrePrint ?? 0,
    smallItem: _smallItem,
    anyway: _anyway,
  );

  bool get readyToCapture => _steady >= steadyFramesNeeded;

  /// The page looked tilted at some point: Capture says the tilt tip once (never blocks).
  Advice? get tiltTip => _tiltSeen
      ? ((_tilt ?? 1) < 1 ? Advice.tiltAway : Advice.tiltToward)
      : null;

  /// How well the page fits, 0 (no page) to 1 (ready to capture). Drives the
  /// framing tone and vibration, which speed up as this rises.
  double get fit => switch (_last) {
    null || Advice.noPage || Advice.tooDark => 0,
    Advice.moveUp ||
    Advice.moveDown ||
    Advice.moveLeft ||
    Advice.moveRight => 0.3,
    Advice.moveCloser || Advice.liftPhone => 0.5,
    Advice.tiltToward || Advice.tiltAway => 0.6,
    Advice.blurry => 0.65,
    Advice.holdStill => 0.7 + 0.3 * (_steady / steadyFramesNeeded).clamp(0, 1),
    Advice.ready => 1,
  };

  void reset() {
    _previous = null;
    _steady = 0;
    _last = null;
    _textSince = null;
    _lostSince = null;
    _tiltSeen = false;
    _anyway = false;
  }

  Advice analyze(LumaGrid g) {
    final moving =
        _previous != null &&
        _previous!.width == g.width &&
        _meanChange(_previous!, g) > shakeLimit;
    _previous = g;
    _lastGrid = g;
    final now = _clock();
    // Never block reading forever: text in view for captureAnywayAfter (page found or not,
    // whatever the guidance says) and it is captured. A moment of hand shake doesn't reset it.
    if (g.textInView && !moving) {
      // Back after longer than a shake: the clock starts again.
      if (_lostSince != null && now.difference(_lostSince!) > moveGrace) {
        _textSince = null;
      }
      _lostSince = null;
      _textSince ??= now;
      if (now.difference(_textSince!) >= captureAnywayAfter) {
        _anyway = true;
        _steady = steadyFramesNeeded;
        return _last = Advice.ready;
      }
    } else {
      _lostSince ??= now;
      if (now.difference(_lostSince!) > moveGrace) _textSince = null;
    }
    _anyway = false;
    final advice = _frame(g, moving);
    if (advice == Advice.ready) {
      _steady++;
      return _last = readyToCapture ? Advice.ready : Advice.holdStill;
    }
    _steady = 0;
    return _last = advice;
  }

  Advice _frame(LumaGrid g, bool moving) {
    _page = null;
    _tilt = null;
    _smallItem = false;
    final a = _pageAdvice(g, moving);
    // No page stands out, or the page looks small, or the "page" is a pale wall filling the
    // view around a small card (measured: a card on a cream wall gave "move further away"
    // for ever). If print fills a few patches, one in the middle, read it as it is. "Move
    // closer" only when the print is in a single patch: too small to read. A real page held
    // too close has print in most patches, so it still hears "move further away".
    final wallAround =
        a == Advice.liftPhone && g.printPatches <= pageFillPatches;
    if ((a == Advice.noPage || a == Advice.moveCloser || wallAround) &&
        g.textInView) {
      if (g.printPatches < smallItemPatches) return Advice.moveCloser;
      if (g.centrePrint == 0) return a;
      _smallItem = true;
      if (moving) return Advice.holdStill;
      final sharp = g.sharpness;
      if (sharp != null && sharp < blurLimit) return Advice.blurry;
      return Advice.ready;
    }
    return a;
  }

  Advice _pageAdvice(LumaGrid g, bool moving) {
    final n = g.data.length;
    final mean = g.data.fold<int>(0, (a, v) => a + v) / n;
    if (mean < darkMean) return Advice.tooDark;

    final t = _otsu(g.data);
    var brightSum = 0, brightN = 0, darkSum = 0;
    for (final v in g.data) {
      if (v > t) {
        brightSum += v;
        brightN++;
      } else {
        darkSum += v;
      }
    }
    if (brightN == 0 || brightN == n) return Advice.noPage;
    final paper = brightSum / brightN;
    if (paper - darkSum / (n - brightN) < minContrast || paper < minPaper) {
      return Advice.noPage;
    }

    // A row or column belongs to the page when it is at least half as bright-filled
    // as the page's widest row or column, so small pages are still found.
    final rowCounts = [
      for (var y = 0; y < g.height; y++) _count(g.width, (x) => g.at(x, y) > t),
    ];
    final colCounts = [
      for (var x = 0; x < g.width; x++) _count(g.height, (y) => g.at(x, y) > t),
    ];
    final rowMax = rowCounts.reduce(math.max),
        colMax = colCounts.reduce(math.max);
    final rows = [for (final c in rowCounts) c >= 2 && c >= rowMax * pageRow];
    final cols = [for (final c in colCounts) c >= 2 && c >= colMax * pageRow];
    final top = rows.indexOf(true), bottom = rows.lastIndexOf(true);
    final left = cols.indexOf(true), right = cols.lastIndexOf(true);
    if (top < 0 || left < 0) return Advice.noPage;
    _page = (
      left: left / g.width,
      top: top / g.height,
      right: (right + 1) / g.width,
      bottom: (bottom + 1) / g.height,
    );

    final cutTop = top == 0, cutBottom = bottom == g.height - 1;
    final cutLeft = left == 0, cutRight = right == g.width - 1;
    // Cut on opposite sides: the page is bigger than the view.
    if ((cutTop && cutBottom) || (cutLeft && cutRight)) return Advice.liftPhone;
    if (cutTop) return Advice.moveUp;
    if (cutBottom) return Advice.moveDown;
    if (cutLeft) return Advice.moveLeft;
    if (cutRight) return Advice.moveRight;

    final area = (bottom - top + 1) * (right - left + 1) / n;
    if (area < minPageArea) return Advice.moveCloser;
    // Tilt, from the page's own edges (no motion sensor: cheap phones may lack
    // one). The end of the page further from the camera looks narrower. Its top
    // narrower: the camera looks up the page, the top of the phone is tilted up
    // toward the user, so tilt it away; and the other way round.
    final span = bottom - top;
    if (span >= 8) {
      // The widest row in a band near each end: a row of print can read as all
      // dark at this size, so one row alone may measure nothing.
      final upper = [
        for (var y = top + span ~/ 10; y <= top + span ~/ 4; y++)
          _width(g, y, t),
      ].reduce(math.max);
      final lower = [
        for (var y = bottom - span ~/ 4; y <= bottom - span ~/ 10; y++)
          _width(g, y, t),
      ].reduce(math.max);
      if (upper > 0 && lower > 0) {
        _tilt = upper / lower;
        // A tip only (Capture says it once): a tilted page is still captured, and the
        // server straightens it. On the tester's card a 0.78 tilt blocked capture for good.
        _tiltSeen =
            _tiltSeen || upper < lower * tiltLimit || lower < upper * tiltLimit;
      }
    }
    if (moving) return Advice.holdStill;
    final sharp = g.sharpness;
    if (sharp != null && sharp < blurLimit) return Advice.blurry;
    return Advice.ready;
  }

  /// The page's width on row [y]: from its first to its last bright cell. The
  /// whole row: a tilted page's wide end reaches past the columns that are page
  /// from top to bottom.
  static int _width(LumaGrid g, int y, int t) {
    var first = -1, last = -1;
    for (var x = 0; x < g.width; x++) {
      if (g.at(x, y) > t) {
        if (first < 0) first = x;
        last = x;
      }
    }
    return first < 0 ? 0 : last - first + 1;
  }

  static int _count(int count, bool Function(int) test) {
    var hits = 0;
    for (var i = 0; i < count; i++) {
      if (test(i)) hits++;
    }
    return hits;
  }

  static double _meanChange(LumaGrid a, LumaGrid b) {
    var sum = 0;
    for (var i = 0; i < a.data.length; i++) {
      sum += (a.data[i] - b.data[i]).abs();
    }
    return sum / a.data.length;
  }

  /// Otsu's threshold: the grey level that best splits page from background.
  static int _otsu(Uint8List data) {
    final hist = List<int>.filled(256, 0);
    for (final v in data) {
      hist[v]++;
    }
    final total = data.length;
    var sumAll = 0.0;
    for (var i = 0; i < 256; i++) {
      sumAll += i * hist[i];
    }
    var sumB = 0.0, wB = 0, best = 0.0, threshold = 0;
    for (var i = 0; i < 256; i++) {
      wB += hist[i];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += i * hist[i];
      final between = wB * wF * math.pow(sumB / wB - (sumAll - sumB) / wF, 2);
      if (between > best) {
        best = between.toDouble();
        threshold = i;
      }
    }
    return threshold;
  }
}
