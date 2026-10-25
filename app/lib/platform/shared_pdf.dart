import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('magana/shared_pdf');

/// A PDF opened with Magana ("Open with", or Share from WhatsApp, Gmail or Files).
/// Its bytes stay in memory; Android hands them over once and keeps no copy.
class SharedPdf {
  const SharedPdf(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

SharedPdf? _fromMap(Object? m) {
  if (m is! Map) return null;
  final bytes = m['bytes'];
  if (bytes is! Uint8List) return null;
  return SharedPdf(bytes, m['name'] as String? ?? 'document.pdf');
}

/// The PDF the app was opened with, if any (taken once). Replaceable in tests.
Future<SharedPdf?> Function() takeSharedPdf = () async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return _fromMap(await _channel.invokeMethod<Object?>('take'));
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
};

/// Calls [onPdf] when a PDF is shared while Magana is already open.
void listenForSharedPdfs(void Function(SharedPdf pdf) onPdf) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'arrived') {
      final pdf = _fromMap(call.arguments);
      if (pdf != null) onPdf(pdf);
    }
  });
}
