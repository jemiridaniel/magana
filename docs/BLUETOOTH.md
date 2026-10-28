# Voice commands with a Bluetooth headset

Nurse Balogun asked (build 7) whether Hold to speak works through a Bluetooth headset's microphone. This is what the code does, what changed in 0.1.0+13, and how to check it on real phones. **None of it has been tried with a real headset yet**: emulators have no Bluetooth audio.

## What happens

**Android, on-device recogniser** (`speech_to_text`, the usual path):
- The plugin switches a connected headset to its call microphone, but **only if Magana holds the Bluetooth permission** (`BLUETOOTH_CONNECT`, Android 12 and later). It checks this once, when the recogniser starts.
- **Before 0.1.0+13** the app didn't declare that permission, so Hold to speak always used the phone's own microphone, even with a headset on.
- **Now:**
  - The permission is declared in `AndroidManifest.xml`, along with `BLUETOOTH` for Android 11 and earlier, and `MODIFY_AUDIO_SETTINGS`.
  - At the first Hold to speak with a headset connected, Magana asks for it (`prepareBluetoothMicrophone`, `lib/platform/speech_support.dart`). Android's own dialog says "Allow Magana to find, connect to, and determine the relative position of nearby devices?". That's the standard wording for this permission.
  - It is asked before the recogniser starts, because the plugin decides only then.
  - Without the permission, the phone's microphone is used, as before.

**Android, server recogniser (Whisper):** the `record` package switches to the headset's call microphone itself (`manageBluetooth`, on by default). It needs `MODIFY_AUDIO_SETTINGS`, which is now declared.

**iPhone:** both the recogniser and the recorder set the audio session with `allowBluetooth` (and `allowBluetoothA2DP`). So a headset's microphone is used when it is connected. Nothing changed.

**TalkBack / VoiceOver:**
- Magana waits for the screen reader to finish before opening the microphone, as without a headset (docs/TALKBACK_AUDIT.md).
- Expect a short pause and a change in sound quality while the headset switches to its call microphone (Bluetooth "hands-free" mode). Speech returns to normal quality when listening stops.

## Checking it on a phone (testers)

For each phone: Android with TalkBack on, Android with it off, iPhone with VoiceOver on, iPhone with it off.
1. Connect a Bluetooth headset with a microphone (earbuds or a neckband).
2. Home → Hold to speak. Android only, first time: allow the "Nearby devices" permission.
3. Say "read a page" **quietly, close to the headset**, with the phone across the room or under a cushion. The camera should open.
4. Say something Magana doesn't know. It should reply "Sorry, I didn't catch that…" through the headset.
5. On the Reader: Speak a command → "next". It should go to the next line.
6. Disconnect the headset and repeat step 2. The phone's microphone should work, with no error.

Write down, for each: worked / didn't, the phone and headset model, and whether TalkBack or VoiceOver was on.
