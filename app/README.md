# Magana app (Flutter)

TalkBack-first Android app that also runs on the web, built to be iOS-ready. Screens: Home, Capture (live camera with spoken framing guidance about every second, auto-capture when the page is whole and steady, torch, gallery), Reader (reads lines or table rows aloud with Repeat, Previous, Next, Pause and speed; speaks low-confidence warnings). UI in English, Hausa, Yorùbá and Igbo.

## Run

Start the backend first (`cd ../backend && uvicorn app.main:app --port 8000`).

```bash
flutter pub get
flutter test

# Android emulator (talks to the host machine through 10.0.2.2)
flutter run -d emulator-5554

# Web at phone size
flutter run -d chrome --web-port 5600 --web-browser-flag=--window-size=412,915
```

The backend address defaults to `http://localhost:8000` on web and iOS simulator and `http://10.0.2.2:8000` on the Android emulator. Real phones need `--dart-define=MAGANA_API=https://your-backend`.

If the emulator stalls ("System isn't responding"), the AVD probably has one CPU core: start it with `emulator -avd <name> -cores 4 -memory 4096`.

## Layout

| File | What it does |
| --- | --- |
| `lib/theme.dart` | Colours, Atkinson Hyperlegible (bundled, works offline), 64 px minimum targets |
| `lib/platform.dart` | Everything that differs by platform (default backend address, normal speech rate) |
| `lib/language.dart` | App language choice (saved on the device) and English fallback for Flutter's own widget strings |
| `lib/l10n/` | All UI strings, one ARB file per language; see `lib/l10n/README.md` |
| `lib/api.dart` | `/read` client; turns lines, tables and the backend's warnings into reading items |
| `lib/speech.dart` | `flutter_tts` wrapper whose `say()` completes when speech ends (Android, iOS, web) |
| `lib/capture/` | Frame analysis for live framing (page found, cut edge, too far, dark, steady), pure Dart and unit-tested |
| `lib/screens/` | Home, Capture, Reader |
| `assets/brand/` | Logo and icon sources; launcher icons via `dart run flutter_launcher_icons` |

The layout is a centred column of at most 480 px on tablets and the web.

## Adding iOS

Every package used (`camera`, `image_picker`, `flutter_tts`, `http`, `flutter_svg`, `shared_preferences`, `flutter_localizations`) supports Android and iOS. Platform-specific code lives only in `lib/platform.dart` (backend address, speech rate, camera frame format, torch, deleting the captured photo) and `lib/platform/`.

1. `flutter create --platforms ios .`
2. In `ios/Runner/Info.plist` add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` (say photos are read and not stored).
3. In `pubspec.yaml` set `flutter_launcher_icons: ios: true` and run `dart run flutter_launcher_icons`.
4. Speech should still play with the silent switch on: in `lib/speech.dart` call `setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [...])` behind a `defaultTargetPlatform == TargetPlatform.iOS` check.
5. Test on a real iPhone with VoiceOver: every control already has a Semantics label, and VoiceOver uses the same labels as TalkBack.

## Accessibility checks

`flutter test` fails if any button or switch has no screen-reader tap action (TalkBack, VoiceOver, Switch Access and Voice Access all need it), or if a Home control is under 64 px.

## Camera notes

- Framing looks for a near-white page against a darker background. Thresholds are named constants in `lib/capture/frame_analysis.dart`; tune them with testers on real phones and paper.
- The captured photo's temporary file is deleted as soon as its bytes are read.
- In browsers there is no live frame analysis or torch: the preview shows, Take photo works, and guidance is spoken once.
- On the emulator the back camera is a virtual room; `adb emu virtualscene-image table page.png` puts a page in it, but aiming needs the emulator window's keyboard controls.

## Not built yet

Voice commands, and the Home tiles other than Read a page (they announce "coming soon").

Fonts: Atkinson Hyperlegible, with a bundled Noto Sans subset as the fallback for letters Atkinson lacks (Hausa ɓ ɗ ƙ, Yorùbá and Igbo ẹ ọ ṣ ị ụ, ₦). Both are SIL Open Font License; see `assets/fonts/README.md`.
