import 'dart:ui' as ui;

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
Future<Uint8List> Function(Uint8List) shrinkPhoto = (bytes) =>
    shrinkTo(bytes, photoMaxWidth, photoQuality);

/// A picture from the gallery that isn't a screenshot: up to 2400 px, as before.
const galleryMaxWidth = 2400;
const galleryQuality = 88;

/// [bytes] upright, at most [maxWidth] wide, re-encoded at [quality] (the phone's own code).
Future<Uint8List> shrinkTo(Uint8List bytes, int maxWidth, int quality) async {
  if (kIsWeb) return bytes;
  try {
    return await _channel.invokeMethod<Uint8List>('shrink', {
          'bytes': bytes,
          'maxWidth': maxWidth,
          'quality': quality,
        }) ??
        bytes;
  } on PlatformException {
    return bytes;
  } on MissingPluginException {
    return bytes;
  }
}

/// The largest screenshot sent as it is (the server takes up to 15 MB).
const screenshotMaxBytes = 8 * 1024 * 1024;

/// A screenshot (tester's dark-mode bank receipt, 27 Oct 2026): a PNG, or a picture shaped
/// like a phone screen (2:1, where camera photos are 4:3). Sent as it is, at full resolution
/// and never re-compressed: its small print and long numbers stay sharp.
Future<bool> looksLikeScreenshot(Uint8List bytes) async {
  if (bytes.length > screenshotMaxBytes) return false;
  const png = [0x89, 0x50, 0x4E, 0x47];
  if (bytes.length > 4 &&
      [for (var i = 0; i < 4; i++) bytes[i]].join() == png.join()) {
    return true;
  }
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final image = await ui.ImageDescriptor.encoded(buffer);
    final long = image.width > image.height ? image.width : image.height;
    final short = image.width > image.height ? image.height : image.width;
    image.dispose();
    buffer.dispose();
    return short > 0 && long / short >= 1.6;
  } catch (_) {
    return false;
  }
}
