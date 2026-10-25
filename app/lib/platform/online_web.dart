import 'dart:js_interop';

@JS('navigator.onLine')
external bool? get _onLine;

/// navigator.onLine: false when the browser knows it has no network.
bool browserOnline() => _onLine ?? true;
