import 'package:camera/camera.dart';

import '../platform.dart';
import 'frame_analysis.dart';

/// Turns a live camera frame into the small, upright brightness grid the
/// [FrameAnalyzer] reads. [sensorOrientation] is the camera's rotation in
/// degrees (90 on most Android back cameras).
LumaGrid lumaGridFrom(CameraImage image, int sensorOrientation) {
  final plane = image.planes.first;
  final (pixelStride, channelOffset) = lumaLayout(
    image.format.group,
    plane.bytesPerPixel,
  );
  return LumaGrid.sample(
    bytes: plane.bytes,
    frameWidth: image.width,
    frameHeight: image.height,
    rowStride: plane.bytesPerRow,
    pixelStride: pixelStride,
    channelOffset: channelOffset,
    quarterTurns: sensorOrientation ~/ 90,
  ).withText(
    frameTextOf(
      bytes: plane.bytes,
      frameWidth: image.width,
      frameHeight: image.height,
      rowStride: plane.bytesPerRow,
      pixelStride: pixelStride,
      channelOffset: channelOffset,
    ),
  );
}
