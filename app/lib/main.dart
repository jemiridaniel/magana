import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'app_scope.dart';
import 'l10n/app_localizations.dart';
import 'language.dart';
import 'platform.dart';
import 'profile.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/splash.dart';
import 'screens/start.dart';
import 'speech.dart';
import 'voices.dart';
import 'theme.dart';
import 'route_speech.dart';
import 'touch.dart';
import 'layout.dart';

/// Phones use the full width; on the web the app is a centred column. Tablets lay
/// themselves out (layout.dart, boards T1 and T2).
const double maxContentWidth = phoneMaxWidth;

/// Kept for the app's lifetime: on the web, Flutter builds the screen-reader tree only
/// when asked, behind a hidden "Enable accessibility" button that VoiceOver users may
/// never find. Forcing it on means VoiceOver and TalkBack work from the first screen.
SemanticsHandle? webSemantics;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) webSemantics = SemanticsBinding.instance.ensureSemantics();
  final language = LanguageController();
  final speaker = Speaker();
  // Before the first press the browser refuses to speak: show "Start Magana".
  if (kIsWeb && !pageHasBeenActivated()) speaker.needsStart.value = true;
  final profile = ProfileController();
  // On until the person chooses (board 10b): Magana's users are blind or low vision.
  final touch = TouchToHear(defaultOn: true);
  // The splash shows while the saved profile, language and voice load.
  final ready = () async {
    await loadDeviceId();
    await profile.load();
    await touch.load();
    await language.load();
    await speaker.setRate(await VoiceSettings.rate());
    await speaker.setLanguage(language.value.languageCode);
    unawaited(speaker.clips.load()); // recorded prompts, where there are any (clips.dart)
  }();
  await precacheSplash();
  runApp(
    MaganaApp(
      api: MaganaApi(headers: () => profile.headers),
      speaker: speaker,
      language: language,
      profile: profile,
      touch: touch,
      ready: ready,
    ),
  );
}

/// For app-wide notices ("Magana is waking up, one moment…").
final appMessenger = GlobalKey<ScaffoldMessengerState>();

class MaganaApp extends StatelessWidget {
  MaganaApp({
    super.key,
    required this.api,
    required this.speaker,
    required this.language,
    required this.profile,
    TouchToHear? touch,
    this.ready,
    this.firstFrameShown,
  }) : touch = touch ?? TouchToHear();

  final MaganaApi api;
  final Speaker speaker;
  final LanguageController language;
  final ProfileController profile;

  /// Touch to hear (board 10); off unless given (tests).
  final TouchToHear touch;

  /// Start-up work the splash waits for; null (tests) goes straight to Home.
  final Future<void>? ready;

  /// When the first frame is on screen (see [SplashGate]); replaceable in tests.
  final Future<void> Function()? firstFrameShown;

  @override
  Widget build(BuildContext context) {
    // The free test-phase server sleeps: while a request waits for it (up to 60 s, api.dart),
    // "Magana is waking up, one moment…" is said and shown once.
    onServerWaking = () {
      final text = lookupAppLocalizations(language.value).serverWaking;
      speaker.say(text);
      appMessenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
    };
    // Hausa, Yorùbá or Igbo with no voice for it on this phone: never read with another
    // language's voice (Nurse Balogun, build 7). Said once, in the app language when it has a
    // voice, otherwise in English; shown too. The text itself stays on the screen.
    speaker.onNoVoice = (lang) async {
      final name = appLanguages
          .firstWhere((a) => a.code == lang, orElse: () => appLanguages.first)
          .name;
      final app = language.value.languageCode;
      final shown = lookupAppLocalizations(language.value).noVoiceYet(name);
      appMessenger.currentState?.showSnackBar(SnackBar(content: Text(shown)));
      final appVoice = app != lang && await speaker.canSpeak(app);
      await speaker.say(
        appVoice
            ? shown
            : lookupAppLocalizations(const Locale('en')).noVoiceYet(name),
        language: appVoice ? app : 'en',
      );
    };
    return AppScope(
      api: api,
      speaker: speaker,
      language: language,
      profile: profile,
      touch: touch,
      child: ValueListenableBuilder<Locale>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          scaffoldMessengerKey: appMessenger,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          // One screen talks at a time: a change of screen stops the voice (route_speech.dart).
          navigatorObservers: [SpeechRouteObserver(speaker, touch)],
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
                constraints: BoxConstraints(
                  maxWidth: isTablet(context)
                      ? double.infinity
                      : maxContentWidth,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: speaker.needsStart,
                  builder: (context, needsStart, _) {
                    final cover = needsStart && runningOnWeb;
                    return Stack(
                      children: [
                        // Out of reach of screen readers and the keyboard while covered.
                        ExcludeFocus(
                          excluding: cover,
                          child: ExcludeSemantics(
                            excluding: cover,
                            child: VoiceKeeper(
                              speaker: speaker,
                              child: TouchExplorer(child: child!),
                            ),
                          ),
                        ),
                        if (cover)
                          Positioned.fill(
                            child: StartMagana(onStart: speaker.start),
                          ),
                      ],
                    );
                  },
                ),
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

/// Stops the voice when Magana leaves the screen (another app, the lock button, a phone call),
/// and tells it whether VoiceOver or TalkBack is on.
class VoiceKeeper extends StatefulWidget {
  const VoiceKeeper({super.key, required this.speaker, required this.child});
  final Speaker speaker;
  final Widget child;

  @override
  State<VoiceKeeper> createState() => _VoiceKeeperState();
}

class _VoiceKeeperState extends State<VoiceKeeper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.speaker.stop();
  }

  @override
  Widget build(BuildContext context) {
    widget.speaker.screenReaderOn =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    return widget.child;
  }
}
