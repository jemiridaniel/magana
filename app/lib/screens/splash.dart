import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Shortest time the lockup shows on a cold start. Set to zero to show it
/// only while start-up work runs.
const Duration splashMinimum = Duration(milliseconds: 800);

/// Same size and place as the native launch image (237 dp wide), so the
/// hand-over from the Android launch screen is seamless.
const double splashLockupWidth = 237;

const _lockup = 'assets/brand/magana_lockup_stacked.svg';

/// Loads the lockup before the first frame (the native splash still covers the
/// screen), so the Flutter splash never shows blank paper first.
Future<void> precacheSplash() async {
  const loader = SvgAssetLoader(_lockup);
  await svg.cache.putIfAbsent(
    loader.cacheKey(null),
    () => loader.loadBytes(null),
  );
}

/// Shows the stacked Magana lockup while start-up work runs (saved language,
/// voice) and for at least [splashMinimum] after it first appears, then [child].
///
/// Android 12+ system splashes can only show the round icon, so the lockup
/// needs this brief moment of its own. Kept short: blind users shouldn't wait.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.ready,
    required this.child,
    this.firstFrameShown = _firstFrameRasterized,
  });

  /// Completes when the app can show [child]; null means it already can.
  final Future<void>? ready;
  final Widget child;

  /// Completes when the first frame is on screen; tests have no rasterizer.
  final Future<void> Function() firstFrameShown;

  static Future<void> _firstFrameRasterized() =>
      WidgetsBinding.instance.waitUntilFirstFrameRasterized;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Future<void>? _done;

  @override
  void initState() {
    super.initState();
    final ready = widget.ready;
    if (ready != null) {
      // Count from the first frame actually on screen: Flutter can hold its
      // first frame back while the system splash still covers the app.
      final shown = widget.firstFrameShown();
      _done = Future.wait([
        ready,
        shown.then((_) => Future<void>.delayed(splashMinimum)),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done == null) return widget.child;
    return FutureBuilder<void>(
      future: _done,
      builder: (context, snap) => snap.connectionState == ConnectionState.done
          ? widget.child
          : const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaganaColors.ground,
      body: Center(
        child: SvgPicture.asset(
          _lockup,
          width: splashLockupWidth,
          semanticsLabel: 'Magana',
        ),
      ),
    );
  }
}
