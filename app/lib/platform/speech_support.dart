import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('magana/speech');

/// Whether this phone can recognise speech entirely on the device (Android 12+ with an
/// on-device recogniser), so audio never leaves it. False on the web, on iOS (not wired
/// up yet) and on older Android. Replaceable in tests.
Future<bool> Function() onDeviceSpeechAvailable = () async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel.invokeMethod<bool>('onDeviceAvailable') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
};
