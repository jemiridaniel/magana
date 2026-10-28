# iPhone builds (Ad Hoc, for testing)

Bundle ID **ng.magana.app**, team **Daniel Jemiri (7MB7UQXJB4)**, automatic signing, iOS 15.5 or later (ML Kit needs 15.5). Version and build number come from `app/pubspec.yaml`, the same as Android.

## Ad Hoc .ipa for Diawi

```bash
scripts/build_ios_adhoc.sh
```

- Builds `app/build/ios/ipa/Magana.ipa` with `app/ios/ExportOptions.plist`: method ad-hoc, no bitcode, thinning none, automatic signing.
- **What is built in:** the server's address and the public app key (`MAGANA_API`, `MAGANA_API_KEY` from `~/.magana/app.env`), the same as the APK and the PWA. The key is an app identifier, not a secret: the server's rate limits and daily caps protect it (docs/INFRA.md). The script runs `scripts/check_bundle_secrets.py` on the .ipa and refuses to finish if it finds any real secret (AWS, model or WhatsApp keys, private keys, signing passwords).
- Only iPhones registered in the Apple Developer account (Certificates, IDs & Profiles → Devices) can install it. After adding a new device, run the script again: automatic signing makes a new profile that includes it.
- Upload the .ipa to diawi.com, then open the Diawi link **in Safari on the iPhone** and tap Install. Then: Settings → General → VPN & Device Management is **not** needed for Ad Hoc (only for enterprise builds). If the app doesn't open, check the device is in the profile.
- The profile expires on 4 Apr 2027 (the date printed by the check in docs/FINDINGS.md). Rebuild before then.

## Daily testing over a cable (Xcode)

1. Connect the iPhone with a cable, unlock it, and tap **Trust This Computer**.
2. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (it restarts). The switch appears after the iPhone has been connected to Xcode once.
3. Open the workspace (not the project):
   ```bash
   open app/ios/Runner.xcworkspace
   ```
4. In Xcode, choose **Runner** and your iPhone at the top. Under **Signing & Capabilities**, check that "Automatically manage signing" is on and the team is "Daniel Jemiri" (not Locomex).
5. Press **Run** (⌘R). The first time, the iPhone may ask you to trust the developer: **Settings → General → VPN & Device Management → Apple Development: Daniel Jemiri → Trust**.

Or from the terminal, for a release build on the cabled phone:
```bash
cd app && flutter run --release --dart-define=MAGANA_API=<the server address>
```
`flutter devices` lists the iPhone's ID if more than one device is connected.

## What is different on iPhone

- **Offline reading** uses ML Kit on the phone, through `ios/Runner/MaganaChannels.swift` (upright, crop, the encrypted queue). **ML Kit gives no confidence on iOS**, so offline every number is "unclear number" and the page gets one warning ("This phone can't say how sure it is…") instead of one per line.
- **Speech recognition:** the on-device step sets `requiresOnDeviceRecognition`, so iOS never sends that audio to Apple. Under-18s have only that step and Magana's own server. Adults may also use Apple's online recogniser, just as adults on Android may use Google's.
- **Voices:** Apple has no Hausa, Yorùbá or Igbo voice and no Nigerian English voice. English uses en-GB or en-US. Hausa, Yorùbá and Igbo text is read by the English voice, as on most Android phones.
- **Spoken reminders** (the alarm that speaks) are Android only. iPhone reminders are notifications.
- **"Open with Magana" for PDFs** is Android only so far. On iPhone, use Read a PDF inside the app.
