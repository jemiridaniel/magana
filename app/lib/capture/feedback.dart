import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Framing feedback that needs no language: a tick with a light vibration that
/// repeats faster as the page fits, and a distinct sound when the photo is taken.
class CaptureFeedback {
  CaptureFeedback();

  AudioPlayer? _tickPlayer;
  AudioPlayer? _capturePlayer;

  Future<AudioPlayer> _player(String asset) async {
    final p = AudioPlayer();
    // Low latency (Android SoundPool) so ticks stay in time.
    await p.setPlayerMode(PlayerMode.lowLatency);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource(asset));
    return p;
  }

  Future<void> tick() async {
    HapticFeedback.lightImpact();
    try {
      final p = _tickPlayer ??= await _player('sounds/tick.wav');
      await p.stop();
      await p.resume();
    } catch (_) {
      // No audio output: the vibration still guides.
    }
  }

  Future<void> captured() async {
    HapticFeedback.heavyImpact();
    try {
      final p = _capturePlayer ??= await _player('sounds/capture.wav');
      await p.stop();
      await p.resume();
    } catch (_) {}
  }

  void dispose() {
    _tickPlayer?.dispose();
    _capturePlayer?.dispose();
  }
}

/// Time to the next tick for a page fit between 0 and 1: none without a page,
/// about once a second when only partly in view, five a second when ready.
Duration? tickInterval(double fit) {
  if (fit <= 0) return null;
  final ms = 1000 - (1000 - 200) * fit.clamp(0.0, 1.0);
  return Duration(milliseconds: ms.round());
}
