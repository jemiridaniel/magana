import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('magana/speech');

/// Whether this phone can recognise speech entirely on the device, so audio never leaves it:
/// Android 12+ with an on-device recogniser (MainActivity.kt), or an iPhone whose English
/// recogniser works on the device (MaganaChannels.swift; speech_to_text then sets
/// requiresOnDeviceRecognition, so iOS never sends the audio to Apple). False on the web and
/// on older Android. Replaceable in tests.
Future<bool> Function() onDeviceSpeechAvailable = () async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return false;
  }
  try {
    return await _channel.invokeMethod<bool>('onDeviceAvailable') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
};
