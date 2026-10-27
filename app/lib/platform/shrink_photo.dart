import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('magana/offline');

/// The widest a camera photo is sent for reading, and its JPEG quality (docs/FINDINGS.md,
/// 27 Oct 2026: 1080 px reads every number on the 40-page set that 720 px missed, about
/// 37 KB a page; 1600 px added nothing).
const photoMaxWidth = 1080;
const photoQuality = 85;

/// A camera photo upright (its EXIF orientation applied), at most [photoMaxWidth] wide and
/// re-encoded at [photoQuality], by the phone (OfflineChannels.kt, MaganaChannels.swift). The
/// photo as it was if the phone can't (the web, an odd file). Replaceable in tests.
Future<Uint8List> Function(Uint8List) shrinkPhoto = (bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await _channel.invokeMethod<Uint8List>('shrink', {
          'bytes': bytes,
          'maxWidth': photoMaxWidth,
          'quality': photoQuality,
        }) ??
        bytes;
  } on PlatformException {
    return bytes;
  } on MissingPluginException {
    return bytes;
  }
};
