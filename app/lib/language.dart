import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  const AppLanguage(this.code, this.name);
  final String code;
  final String name; // the language's own name, never translated
}

const appLanguages = [
  AppLanguage('en', 'English'),
  AppLanguage('ha', 'Hausa'),
  AppLanguage('yo', 'Yorùbá'),
  AppLanguage('ig', 'Igbo'),
];

AppLanguage languageFor(Locale locale) => appLanguages.firstWhere(
  (l) => l.code == locale.languageCode,
  orElse: () => appLanguages.first,
);

/// The app language the user picked, remembered on the device.
class LanguageController extends ValueNotifier<Locale> {
  LanguageController([super.value = const Locale('en')]);

  static const _key = 'app_language';

  Future<void> load() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(_key);
      if (code != null && appLanguages.any((l) => l.code == code)) {
        value = Locale(code);
      }
    } catch (_) {
      // Storage unavailable: keep the default.
    }
  }

  Future<void> select(String code) async {
    value = Locale(code);
    try {
      await (await SharedPreferences.getInstance()).setString(_key, code);
    } catch (_) {}
  }
}

/// Flutter ships no Material/Cupertino translations for Hausa, Yorùbá or Igbo.
/// For those, built-in widget strings (tooltips, date pickers) fall back to
/// English; every Magana string comes from our own ARB files.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      !GlobalMaterialLocalizations.delegate.isSupported(locale);
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      !GlobalCupertinoLocalizations.delegate.isSupported(locale);
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(
    covariant LocalizationsDelegate<CupertinoLocalizations> old,
  ) => false;
}
