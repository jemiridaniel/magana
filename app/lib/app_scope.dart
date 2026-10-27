import 'package:flutter/widgets.dart';

import 'api.dart';
import 'language.dart';
import 'profile.dart';
import 'route_speech.dart';
import 'speech.dart';
import 'touch.dart';

/// Shared services, injectable so tests can swap in fakes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.speaker,
    required this.language,
    required this.profile,
    required this.touch,
    required super.child,
  });

  final MaganaApi api;
  final Speaker speaker;
  final LanguageController language;
  final ProfileController profile;
  final TouchToHear touch;

  /// The services, with speech bound to the screen [context] is on (route_speech.dart): a
  /// covered or closed screen can't talk over the one in front.
  static AppScope of(BuildContext context) => maybeOf(context)!;

  static AppScope? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) return null;
    final route = routeOf(context);
    return route == null ? scope : scope._boundTo(route);
  }

  /// The services with the app's own voice, bound to no screen: for words said as a screen
  /// closes ("Language changed").
  static AppScope app(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>()!;
    return scope.speaker is RouteSpeaker ? scope._unbound() : scope;
  }

  static final _bound = Expando<Expando<AppScope>>();

  AppScope _boundTo(ModalRoute<Object?> route) {
    final perRoute = _bound[this] ??= Expando<AppScope>();
    return perRoute[route] ??= AppScope(
      api: api,
      speaker: RouteSpeaker(voice, route),
      language: language,
      profile: profile,
      touch: touch,
      child: child,
    );
  }

  AppScope _unbound() => AppScope(
    api: api,
    speaker: voice,
    language: language,
    profile: profile,
    touch: touch,
    child: child,
  );

  /// The one shared voice.
  Speaker get voice {
    final s = speaker;
    return s is RouteSpeaker ? s.shared : s;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      speaker != oldWidget.speaker ||
      language != oldWidget.language ||
      profile != oldWidget.profile ||
      touch != oldWidget.touch;
}
