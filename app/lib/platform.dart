import 'package:camera/camera.dart' show ImageFormatGroup, XFile;
import 'package:flutter/foundation.dart';

import 'platform/discard_stub.dart'
    if (dart.library.io) 'platform/discard_io.dart';

// Everything that differs by platform lives here, so adding iOS means
// reviewing this one file. File access is behind a conditional import
// (platform/discard_*.dart), so it also compiles for the web.

/// Backend address when no --dart-define=MAGANA_API is given (development only;
/// real phones always get the deployed URL through MAGANA_API).
String get defaultApiBase {
  if (kIsWeb) return 'http://localhost:8000';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      'http://10.0.2.2:8000', // Android emulator -> host machine
    _ => 'http://localhost:8000', // iOS simulator shares the host's network
  };
}

/// flutter_tts rate that sounds "normal": 0.5 on Android and iOS, 1.0 in browsers.
double get normalSpeechRate => kIsWeb ? 1.0 : 0.5;

/// Camera frame format for live framing analysis: Android hands out YUV
/// (the first plane is brightness), iOS BGRA.
ImageFormatGroup get cameraFrameFormat => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => ImageFormatGroup.bgra8888,
  _ => ImageFormatGroup.yuv420,
};

/// Where brightness sits in a frame's first plane: (pixel stride, channel offset).
/// BGRA uses green, the channel closest to perceived brightness.
(int, int) lumaLayout(ImageFormatGroup group, int? bytesPerPixel) =>
    switch (group) {
      ImageFormatGroup.bgra8888 => (4, 1),
      _ => (bytesPerPixel ?? 1, 0),
    };

/// Live frames for auto-capture and a torch exist on phones, not in browsers.
bool get liveFramingSupported => !kIsWeb;
bool get torchSupported => !kIsWeb;

/// Deletes the camera's temporary photo file once its bytes are read, so the
/// photo only lives in memory (CLAUDE.md rule 5). No-op on the web.
Future<void> discardCapture(XFile photo) => discardFile(photo);
