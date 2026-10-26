# Testing Magana on your Android phone

Thank you for helping test Magana. Magana reads printed pages aloud: schoolwork, medicine labels, letters and more. This is an early test version, so some things will go wrong. That's what we want to find out.

## 1. Get the app

On your phone, open **https://magana.ng/android/** and tap **Download the app**. Or save the file we send you, called something like `magana-0.1.0+3.apk`, from WhatsApp, email or Google Drive. It is about 21 MB.

**If you already have Magana installed,** install the new version over it, without uninstalling first. Your settings stay. Versions before 0.1.0+3 keep working for now, but please update: they use the old server address.

## 2. Allow your phone to install it

Android only installs apps from the Play Store unless you allow it.

1. Open the APK file, for example from your Downloads or from the WhatsApp chat.
2. Your phone says something like "For your security, your phone is not allowed to install unknown apps from this source." Tap **Settings**.
3. Turn on **Allow from this source**, then go back.
4. Tap **Install**.

On some phones this is under **Settings → Apps → Special app access → Install unknown apps**. Choose the app you opened the file with (Files, Chrome or WhatsApp) and turn it on.

### If Play Protect stops you

Google Play Protect may say **"App blocked to protect your device"** or "Unsafe app blocked", because it doesn't know Magana yet. To install anyway:

1. Tap **More details**.
2. Tap **Install anyway**.

If you only see **OK**, tap the small arrow or **More details** first. Magana is safe to install. It is only unknown to Google because it is not in the Play Store yet.

## 3. Turn on TalkBack (if you don't use it already)

TalkBack is Android's screen reader. Magana is built to work with it.

- **Fastest way:** press and hold **both volume buttons** for 3 seconds. Your phone may ask you to confirm the shortcut the first time.
- **Or:** **Settings → Accessibility → TalkBack → Use TalkBack.**

With TalkBack on:
- touch something to hear it;
- **double tap** anywhere to press it;
- **swipe right or left** with one finger to move to the next or previous item;
- **swipe with two fingers** to scroll.

To turn TalkBack off, hold both volume buttons again.

## 4. First start

1. Open **Magana**. Choose your language, your age group, then your class (for example Primary 5 or JSS 2). Adults can choose "I'm not in school". If you chose the wrong class, a teacher can change it in Settings → My class.
2. When Magana asks for the camera, microphone or notifications, tap **Allow**. Magana does not keep your photos: each page is read and then deleted.

## 5. What to try

Please try these, without help from a sighted person if you can:

1. **A medicine label.** Home → **Everyday papers** → **Medicine label**. Point the camera at the box or bottle. Magana tells you how to move the phone ("left", "closer") and takes the photo when the label fits. Listen to the reading. Does it read the dose and the numbers correctly?
2. **A printed letter.** Home → **Everyday papers** → **Read any paper** (or **Letters & forms**).
3. **A page of schoolwork.** Home → **Read a page**. Try a page with a table if you have one. Use **Previous**, **Repeat** and **Next** to move line by line.

If you have time, also try:
- **Practice quiz**: choose a subject for your class and answer by voice or by tapping. Questions marked "Sample questions" were written by the Magana team and are waiting for a teacher's check;
- **Talk to a health worker** → the quick health check;
- **Settings**.

Magana should **never guess a number**. If it says "unclear number", that is on purpose. Please tell us whether the number on the paper really was hard to read.

## 6. Reporting a problem

Please send us three things, by email to **support@magana.ng**, or by WhatsApp to the person who gave you the app:

1. **The name of the screen.** Magana says it when the screen opens, for example "Medicine label" or "Practice quiz".
2. **What you did.** For example: "I took a photo of my paracetamol box in my kitchen in the evening."
3. **What Magana said.** As close to the exact words as you can. A voice note is fine.

Also tell us your **version**: Home → **Settings** → it says, for example, "Version 0.1.0 (build 1)".

Please don't send photos of private papers such as your own bank statement or medical results. Describe them instead.

---

## The web version (for testing on iPhone, or without installing the APK)

Magana also runs in the phone's browser and can be added to the home screen like an app. **It is for testing only.** The real iPhone app comes later through TestFlight. Its address is **https://app.magana.ng**.

What is different in the web version:
- **Reminders don't work.** The screen says "Reminders need the Android or iPhone app".
- **No live camera guidance.** Capture opens the phone's camera; take the photo yourself, holding the phone about a forearm's length above the page.
- **Speech recognition:** for under-18 accounts, Magana never uses Safari's or Chrome's speech recognition, because that sends audio to Apple or Google. They use Magana's own server or tap their answers.
- It needs the internet to read pages. The screens open without it, and if the server can't be reached Magana says "I couldn't reach Magana. Check the connection and try again."

### Install on iPhone

1. Open the address in **Safari** (not Chrome; on iPhone only Safari can add it to the home screen as an app).
2. Tap the **Share** button (the square with an arrow pointing up, at the bottom of the screen; with VoiceOver it is called "Share").
3. Scroll down and tap **Add to Home Screen**, then **Add**.
4. Open **Magana** from the home screen. It opens full screen, without Safari's address bar.

**VoiceOver** (the iPhone screen reader): **Settings → Accessibility → VoiceOver**, or ask Siri "Turn on VoiceOver". Touch to hear, **double tap** to press, **swipe right or left** to move between items. Magana turns on its screen-reader support by itself; you don't need to find an "Enable accessibility" button.

When Safari asks for the **microphone** or **camera**, tap **Allow**.

### Install on Android Chrome

1. Open the address in **Chrome**.
2. Chrome may offer **Install app** or **Add Magana to Home screen** at the bottom. Tap **Install**.
3. If it doesn't, tap the **⋮ menu** (top right; with TalkBack it is called "More options") → **Install app** or **Add to Home screen** → **Install**.
4. Open **Magana** from the home screen or the app drawer.

If you can install the APK (sections 1 and 2), please use the APK instead: it has reminders and live camera guidance.

---

## For the team: signing and building the APK

Every Magana APK, and later the Play Store upload, must be signed with the **same upload key**. If the key is lost, testers have to uninstall and reinstall to get updates, and the Play listing would need a key reset.

**Where it is (outside the repo):**
- the keystore: `~/.magana/magana-upload.jks`, alias `magana-upload`, PKCS12, RSA 4096, valid for 10,000 days;
- its password, in plain text: `~/.magana/key.properties`. Both files are `chmod 600`.

`app/android/key.properties` is a git-ignored link to the password file. Release builds fail on purpose without it; they never fall back to the debug key.

**Back it up now, in two places:**
1. Copy both files into your password manager as secure attachments (1Password, Bitwarden and similar), or into an encrypted disk image:
   ```bash
   hdiutil create -encryption AES-256 -srcfolder ~/.magana -volname magana-keys ~/Desktop/magana-keys.dmg
   ```
   Then copy that `.dmg` to a USB drive or cloud storage. It is protected by the password you choose; store that password in your password manager.
2. Never commit these files, and never send them over WhatsApp or email unencrypted.

**To create a new key instead** (only before any APK has gone out):
```bash
keytool -genkeypair -v -keystore ~/.magana/magana-upload.jks -storetype PKCS12 \
  -alias magana-upload -keyalg RSA -keysize 4096 -validity 10000
```
`keytool` is in `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/`. Then update `~/.magana/key.properties` (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`).

**Build for testers:**
1. Put the server address and API key in `~/.magana/app.env`:
   ```bash
   MAGANA_API=https://api.magana.ng
   MAGANA_API_KEY=<the server's MAGANA_API_KEY>
   ```
2. Bump `version:` in `app/pubspec.yaml`. The number after `+` must go up with every build you hand out.
3. Run `scripts/build-apk.sh`. It prints the arm64 APK's path, size and signing fingerprint.
4. Run `scripts/publish-apk.sh` to put it on the website: **https://magana.ng/downloads/magana.apk**, linked from https://magana.ng/android/.

Send testers `app-arm64-v8a-release.apk`, renamed to `magana-<version>.apk`. It fits almost every phone from the last several years. Very old 32-bit phones need `app-armeabi-v7a-release.apk`.
