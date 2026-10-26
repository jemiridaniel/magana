import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('magana/device');

/// The phone's maker and model ("TECNO KI5q") for problem reports (board 9), nothing else
/// about the phone. "Web" in a browser. Replaceable in tests.
Future<String> Function() phoneModel = () async {
  if (kIsWeb) return 'Web';
  try {
    return await _channel.invokeMethod<String>('model') ?? 'Unknown phone';
  } on PlatformException {
    return 'Unknown phone';
  } on MissingPluginException {
    return defaultTargetPlatform.name;
  }
};
