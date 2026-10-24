import 'package:flutter/foundation.dart';

// Everything that differs by platform lives here, so adding iOS means
// reviewing this one file. No dart:io, so it also compiles for the web.

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
