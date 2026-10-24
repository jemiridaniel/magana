import 'package:flutter/widgets.dart';

import 'api.dart';
import 'language.dart';
import 'profile.dart';
import 'speech.dart';

/// Shared services, injectable so tests can swap in fakes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.speaker,
    required this.language,
    required this.profile,
    required super.child,
  });

  final MaganaApi api;
  final Speaker speaker;
  final LanguageController language;
  final ProfileController profile;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      speaker != oldWidget.speaker ||
      language != oldWidget.language ||
      profile != oldWidget.profile;
}
