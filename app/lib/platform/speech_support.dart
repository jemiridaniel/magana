import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform.dart';

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

/// TalkBack is speaking right now (Android, MainActivity.kt). False elsewhere: VoiceOver
/// can't be asked. Replaceable in tests.
Future<bool> Function() screenReaderSpeaking = () async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _channel.invokeMethod<bool>('screenReaderSpeaking') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
};

/// Waits until the screen reader has stopped speaking, at most [max]: Magana's voice and the
/// microphone never start over TalkBack (Nurse Balogun, Android 0.1.0+7: voice commands
/// didn't work with TalkBack on; the recogniser was hearing TalkBack).
Future<void> screenReaderQuiet({
  Duration max = const Duration(seconds: 4),
}) async {
  final start = DateTime.now();
  final until = start.add(max);
  // TalkBack starts a moment after the change that makes it speak.
  await Future<void>.delayed(const Duration(milliseconds: 150));
  var waited = false;
  while (DateTime.now().isBefore(until) && await screenReaderSpeaking()) {
    waited = true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (waited) {
    devLog(
      'speech: waited ${DateTime.now().difference(start).inMilliseconds} ms '
      'for the screen reader',
    );
  }
}

/// Hold to speak through a Bluetooth headset (docs/BLUETOOTH.md). On Android, speech_to_text
/// uses the headset's microphone only with the Bluetooth permission, which it asks for only
/// together with the first microphone permission, and checks once, when it starts. So before
/// it starts: if a headset is connected and the permission isn't given, it is asked for here.
/// Without it, the phone's own microphone is used, as before. iPhones need nothing: both
/// recognisers allow Bluetooth microphones. Replaceable in tests.
Future<void> Function() prepareBluetoothMicrophone = () async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    if (await _channel.invokeMethod<bool>('bluetoothHeadset') != true) return;
    if (await _channel.invokeMethod<bool>('bluetoothAllowed') == true) return;
    final ok = await _channel.invokeMethod<bool>('askBluetooth') ?? false;
    devLog('speech: Bluetooth headset ${ok ? 'allowed' : 'not allowed'}');
  } on PlatformException {
    return;
  } on MissingPluginException {
    return;
  }
};
