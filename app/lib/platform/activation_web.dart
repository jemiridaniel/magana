import 'dart:js_interop';

@JS('navigator.userActivation')
external _UserActivation? get _userActivation;

extension type _UserActivation(JSObject _) implements JSObject {
  external bool get hasBeenActive;
}

/// navigator.userActivation.hasBeenActive; true where the browser doesn't say.
bool hasUserActivation() => _userActivation?.hasBeenActive ?? true;
