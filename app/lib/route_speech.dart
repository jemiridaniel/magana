import 'package:flutter/widgets.dart';

import 'speech.dart';
import 'touch.dart';

/// One voice, owned by one screen at a time (iPhone test, 27 Oct 2026: "Read a page" kept talking
/// after going back to Home). Every screen speaks through a [RouteSpeaker] bound to its route
/// (AppScope.of gives it): a covered or closed screen's words are dropped, and every change of
/// screen stops whatever was being said ([SpeechRouteObserver]) before the new screen's own
/// summary, which starts after the change.
class RouteSpeaker implements Speaker {
  RouteSpeaker(this.shared, this.route);

  /// The app's one voice.
  final Speaker shared;
  final ModalRoute<Object?> route;

  /// This screen is the one in front: its words may be said.
  bool get inFront => route.isCurrent;

  @override
  Future<bool> say(String text, {bool Function()? wanted}) async {
    if (!inFront) return false;
    return shared.say(text, wanted: () => inFront && (wanted?.call() ?? true));
  }

  @override
  Future<bool> sayThrough(String text, {required bool Function() wanted}) =>
      say(text, wanted: wanted);

  @override
  Future<void> stop() => shared.stop();

  @override
  ValueNotifier<bool> get needsStart => shared.needsStart;
  @override
  double get rate => shared.rate;
  @override
  bool get speaking => shared.speaking;
  @override
  bool get screenReaderOn => shared.screenReaderOn;
  @override
  set screenReaderOn(bool on) => shared.screenReaderOn = on;
  @override
  Future<void> setLanguage(String code) => shared.setLanguage(code);
  @override
  Future<void> setRate(double rate) => shared.setRate(rate);
  @override
  Future<void> start() => shared.start();
  @override
  Future<Spoken> utter(String text) =>
      inFront ? shared.utter(text) : Future.value(Spoken.stoppedByMagana);
}

/// Stops the voice (and clears Touch to hear's caption) whenever the screen changes: pushed,
/// popped, replaced or removed. Called during the change, so before the new screen speaks.
class SpeechRouteObserver extends NavigatorObserver {
  SpeechRouteObserver(this.speaker, this.touch);
  final Speaker speaker;
  final TouchToHear touch;

  void _changed(Route<Object?>? route) {
    // Snack bars and the like aren't routes; popup routes (sheets, dialogs) are screens too.
    if (route is! ModalRoute) return;
    speaker.stop();
    touch.focused.value = null;
    touch.caption.value = null;
  }

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) =>
      _changed(route);
  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      _changed(route);
  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) =>
      _changed(route);
  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) =>
      _changed(newRoute);
}

/// The route [context] belongs to, without making [context] depend on it. ModalRoute.of
/// can't be called from initState (debug builds assert); the screen's own route marker is
/// found by walking up instead.
ModalRoute<Object?>? routeOf(BuildContext context) {
  try {
    return ModalRoute.of(context);
  } catch (_) {
    ModalRoute<Object?>? found;
    context.visitAncestorElements((e) {
      if (e.widget.runtimeType.toString() == '_ModalScopeStatus') {
        found = (e.widget as dynamic).route as ModalRoute<Object?>?;
        return false;
      }
      return true;
    });
    return found;
  }
}
