import 'dart:io';

import 'package:camera/camera.dart' show XFile;

Future<void> discardFile(XFile photo) async {
  try {
    final file = File(photo.path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best effort: the OS clears the app cache too.
  }
}
