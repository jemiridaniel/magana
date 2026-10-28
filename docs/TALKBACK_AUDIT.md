# TalkBack audit: the core journey on Android

> **Why:** Nurse Balogun, Android 0.1.0+7 with TalkBack: "the TalkBack voice command isn't working… I could not use this app if I was blind."
>
> **Status:** unreviewed. The fixes are in the build after 0.1.0+12. They still need a blind tester, or Nurse Balogun, to try them on a real phone.

**How it was run (27–28 Oct 2026):**
- **Device:** Android emulator, API 36, TalkBack 16.0.
- **Builds:** 0.1.0+12 against the live server, then the fixed build against a local server. The live server stopped answering during the audit (see the end).
- **Gestures:** swipes and double taps through the emulator console, the way a TalkBack user moves.
- **What TalkBack said:** read from its "Display speech output" captions.
- **Focus:** found from TalkBack's green outline, plus the accessibility tree (label, role and state of every node).

**Not covered by the emulator:** real speech recognition. The emulator's microphone got no sound from the Mac (the recogniser reported "no speech" every time), so a spoken command being *understood* has to be checked on a phone. Everything up to and after recognition was checked.

**The journey:** open app → onboarding → Home → Read a page → Capture → Reader → Back → Everyday papers → Medicine label.

## Checklist

✅ pass · ❌ failed at the start of the audit, now fixed · ⚠️ open

### Every control has a clear label and role
- ✅ Home: "Read a page. Schoolwork, medical reports…, Button"; the six tiles; "Settings, Button"; "App language: English. Change language"; "Speak a command, Button".
- ❌ → ✅ Home heading: the logo was a separate stop, "Magana, Image", next to "Hello". The heading is now one stop: "Magana, Hello".
- ❌ → ✅ Language and class choices said "selected, English, Button". They now say "English, Radio button, checked" / "Hausa, Radio button, not checked".
- ✅ Capture: "Read a page" (heading), "Back to home", "Turn on torch, Switch", "Camera view", the status line, "Auto-capture, Switch, checked", "Take photo", "Choose a photo from the gallery".
- ✅ Reader: title with counts, "Back to home", "Jump within page", "Speak a command", Headings / Columns / Tables, the line, its warning, "What's unclear?", "Save to my library", "Previous line" / "Repeat this line" / "Next line", "Reading speed 1×. Tap to change", "Explain this", "Pause reading" / "Read from here".
- ✅ Everyday papers: title, "Back", and each paper with its description ("Medicine label. Labels and prescriptions").

### Double tap activates
- ✅ Every control used in the journey opened with TalkBack's double tap: Continue, the age and "who is using" choices, Start, Read a page, Take photo, Gallery, Skip, Everyday papers, Medicine label, Speak a command.
- ✅ The camera and microphone permission dialogs (system dialogs) could be answered with TalkBack.

### Focus order is logical
- ✅ Home: heading, language, Settings, Read a page, then the tiles row by row, then Speak a command.
- ✅ Capture and Reader: header, picture or page, then the controls top to bottom.

### Focus lands on the new screen's title after navigation
- ❌ → ✅ Onboarding steps 2–4: focus landed on "Back". It now lands on the step's title ("How old are you?"); "Step 2 of 4" follows it and is no longer a second heading.
- ❌ → ✅ Capture (Read a page, Medicine label) and Reader: focus landed on "Back" / "Back to home". It now lands on the title. The title comes first in reading order, then Back (`ScreenHeader`, `capture.dart`, `reader.dart`).
- ✅ Home after onboarding and after Back: "Magana, Hello".
- ✅ Everyday papers: its title.
- ❌ → ✅ Bottom sheets ("Did you read this page on your own?", the language sheet, Jump within page): focus landed on the sheet's drag handle, "Dismiss". With a screen reader on, the handle is left out; TalkBack's back gesture and the sheet's own buttons still close it.

### Nothing is unreachable by swipe
- ✅ Every control on Home, Capture, the Reader, Everyday papers and the Medicine label capture screen was reached by swiping, with nothing skipped.
- ❌ → ✅ Android Back (and TalkBack's back gesture) during onboarding **closed Magana** and lost the steps. The onboarding steps live in their own navigator, which Back skipped. Back now goes one step back.

### Magana's own speech doesn't talk over TalkBack
- ❌ → ✅ Magana spoke regardless of TalkBack. Now, with TalkBack on, Magana waits until TalkBack is quiet before speaking (up to 4 s).
  - How the phone knows: TalkBack's speech plays as accessibility audio while it talks (`MainActivity.screenReaderSpeaking`).
  - Checked on the emulator: "waited 720 ms for the screen reader".
- ❌ → ✅ Capture's spoken framing cues ("Move closer", "Hold still"), about one a second, now skip while TalkBack is talking, and leave 2.5 s between cues instead of 1 s.
- ❌ → ✅ When the person moves TalkBack to a control, Magana stops talking. In the Reader it pauses on its line, and Play goes on from there.
- ✅ Opening a screen sends one short announcement (title and number of choices), not Magana's spoken introduction (unchanged, `introduceScreen`).

### "Speak a command" with TalkBack on
"Hold to speak" became the tap button "Speak a command" in an earlier build, so it works with a double tap.
- ✅ **Microphone permission:** the first double tap asks for the microphone, and TalkBack reads the dialog.
- ❌ → ✅ **Recognition service: "Listening…" for ever.** On a phone without an on-device English model (the emulator: `error_language_unavailable`), Magana moves on to the phone's online recogniser.
  - **The bug:** both steps share one speech_to_text instance, and a second `initialize` keeps the first step's handlers. The online step's result never reached it, so the button stayed on "Listening… Tap to stop" and nothing more was said.
  - **The fix:** the plugin's events now go to the step that is listening.
  - **Safety net:** a watchdog stops any listen after 16 s, and the server recogniser stops after 9 s even if the microphone reports nothing.
  - This likely explains the tester's report: many low-cost phones have no on-device English model.
- ❌ → ✅ **The microphone heard TalkBack.** It opened while TalkBack was still talking, for example reading the permission dialog's result or "Magana, Hello". Magana now waits until TalkBack is quiet (up to 3 s), then a short vibration means "speak now".
- ❌ → ✅ **Feedback when not understood:** "Sorry, I didn't catch that. Say “read a page” or “help”." It is said when nothing was heard and when the words aren't a command. Hausa, Yorùbá and Igbo are drafts.
- ✅ **"Help"** lists the commands this account can use (unchanged).
- ⚠️ **Recognising a real spoken command** with TalkBack on: not testable on the emulator (above). Please try on a phone: "read a page", "everyday papers", "help".
- ❌ → ✅ **Recognition language:** the recogniser picked the first English on the list (Australian English on the emulator). It now prefers Nigerian, then British, then American English.

## Also found
- **Server down:**
  - **What:** api.magana.ng stopped answering (no TCP on ports 80 or 443) after the 227fc43 deploy passed its health check at 18:33 UTC on 27 Oct.
  - **Effect:** each photo waited the full 60 s request timeout, then 25 s more, before being read on the phone.
  - **Open:** why the instance stopped answering.
- **The emulator's camera:** it auto-captured the virtual room's checkerboard TV again and again, and the local server's rate limit then refused the reads. This is a quirk of the emulator, not a phone, but a real non-page scene that looks like text could do the same.

## Tests
- `app/test/talkback_test.dart`:
  - an online fallback after a failed on-device step ends (it never hangs);
  - the watchdog;
  - the microphone waits for TalkBack, and nothing waits with it off;
  - each onboarding step is reached title first;
  - Android Back goes one step back.
- Updated: `app_test.dart` (one heading "Magana, Hello"), `learner_test.dart` (the new feedback).
