import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'app_scope.dart';
import 'l10n/app_localizations.dart';
import 'language.dart';
import 'profile.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/splash.dart';
import 'speech.dart';
import 'theme.dart';

/// Phones use the full width; on tablets and the web the app is a centred column.
const double maxContentWidth = 480;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = LanguageController();
  final speaker = Speaker();
  final profile = ProfileController();
  // The splash shows while the saved profile, language and voice load.
  final ready = () async {
    await profile.load();
    await language.load();
    await speaker.setLanguage(language.value.languageCode);
  }();
  await precacheSplash();
  runApp(
    MaganaApp(
      api: MaganaApi(headers: () => profile.headers),
      speaker: speaker,
      language: language,
      profile: profile,
      ready: ready,
    ),
  );
}

class MaganaApp extends StatelessWidget {
  const MaganaApp({
    super.key,
    required this.api,
    required this.speaker,
    required this.language,
    required this.profile,
    this.ready,
    this.firstFrameShown,
  });

  final MaganaApi api;
  final Speaker speaker;
  final LanguageController language;
  final ProfileController profile;

  /// Start-up work the splash waits for; null (tests) goes straight to Home.
  final Future<void>? ready;

  /// When the first frame is on screen (see [SplashGate]); replaceable in tests.
  final Future<void> Function()? firstFrameShown;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: api,
      speaker: speaker,
      language: language,
      profile: profile,
      child: ValueListenableBuilder<Locale>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: maganaTheme(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            FallbackMaterialLocalizationsDelegate(),
            GlobalCupertinoLocalizations.delegate,
            FallbackCupertinoLocalizationsDelegate(),
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => ColoredBox(
            color: MaganaColors.ground,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: child,
              ),
            ),
          ),
          home: firstFrameShown == null
              ? SplashGate(
                  ready: ready,
                  child: const ProfileGate(home: HomeScreen()),
                )
              : SplashGate(
                  ready: ready,
                  firstFrameShown: firstFrameShown!,
                  child: const ProfileGate(home: HomeScreen()),
                ),
        ),
      ),
    );
  }
}
