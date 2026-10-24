import 'package:camera/camera.dart' show XFile;

/// Browsers hand photos over as in-memory blobs: nothing to delete.
Future<void> discardFile(XFile photo) async {}
