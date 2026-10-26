# White paper audit: the Flutter app, 26 October 2026

An audit of the Android app (`app/`) and the server calls it depends on, against ten questions for the white paper. **No code was changed.** Every claim names the file it comes from or the measurement behind it. Anything not measured says so.

**Status key:** **Exists** = built and tested. **Partly** = built, with gaps named below. **Missing** = not built.

**Evidence limits that apply throughout:**
- No real phone and no blind or low-vision tester has used Magana yet (docs/FINDINGS.md, header).
- Every TalkBack check so far was on the Android emulator (Android 16, API 36).
- The live server's settings could not be read for this audit: SSH timed out, because inbound SSH is limited to your own IP. Production settings below come from `deploy/.env.example` and from FINDINGS.

## Status after the fixes (updated 26 Oct 2026)

The audit below is as written on 26 Oct, before any fix. These are the statuses now, after the fixes from the design boards (5c, 5d, 5e, 8, 9) and Explain's fail-safe. Measurements are in docs/FINDINGS.md.

| # | Item | Status now | What changed |
|---|---|---|---|
| 1 | Capture guidance | **Partly** | A tilt cue from the page's edges and a blur check while framing (no auto-capture while blurry) were added. Thresholds are untuned on a real camera, and there is still no real-phone test. |
| 2 | Confidence signalling | **Exists** | Gallery photos with text cut off at the edge now say "Part of the page is cut off at the <side>". On Hausa, Yorùbá and Igbo pages, a digit inside a word is "unclear letter", never a number. |
| 3 | Offline | **Partly** (much better) | Basic reading works on the phone (ML Kit and the phone's voice), with number safety. The photo is queued, encrypted, for the full reading. Tables, columns and Explain still need the server. APK +13 MB. |
| 4 | Low-end phones | **Partly** | Unchanged: still never run on a real low-end phone. |
| 5 | Structure | **Partly** (much better) | Two-column pages are read column by column: words in order went from 64% to 100% on team pages. There are headings, "Next column" and a page map. Real photographed textbook pages are still to be measured. |
| 6 | Accessibility tests | **Partly** | More `expectAccessible` checks (help check, report a problem, unclear letters, Explain), plus portal axe checks on the new pages. Still no TalkBack test on a real phone. |
| 7 | Feedback | **Exists** | "Did you need help?" (board 8) feeds a real "Done without sighted help" figure, with "No answers yet" when empty. "Report a problem" (board 9) goes to the team's Reports list and emails support. The support email can be tapped. |
| 8 | Consent | **Partly** | Unchanged. The new problem reports and shared totals follow the age rules: no voice note under 18, nothing from Classroom sessions, nothing before consent. |
| 9 | Explain | **Partly** (still off in production) | Fails safe: every marker exactly once, one retry at temperature 0, then the page is read. English goes only to the LoRA. Hausa, Yorùbá and Igbo are "coming", with English offered. On the 20-prompt set the LoRA in English gave 2 spoken, 3 refused, 0 unsafe. There is no approved host yet. |
| 10 | Language | **Partly** | Hausa, Yorùbá and Igbo pages are warned once. Yorùbá and Igbo pages are read again with better models. Words that may have lost a letter are marked and spelled, and a digit inside a word is an unclear letter. Hausa ɓ ɗ ƙ ƴ are still lost by every model. The UI text is still a draft. |

## Summary (as audited, before the fixes)

| # | Item | Status | One line |
|---|---|---|---|
| 1 | Capture guidance | **Partly** | Spoken cues, tone and vibration for edges, distance, darkness and movement; auto-capture when steady; accessible buttons. No tilt cue, no sharpness check while framing, no real-phone test. |
| 2 | Confidence signalling | **Exists** (one gap) | Per-word and per-line confidence; spoken warnings; "unclear number"; faint and cut-off line ends flagged. A gallery photo with the page cut off at the photo's edge is not detected. |
| 3 | Offline | **Partly** | Saved readings, TTS, bundled quizzes, lessons, reminders and the 112 banner work offline. **Reading a new page needs the server**: there is no on-device OCR, and the ML Kit fallback in CLAUDE.md is not built. About 37–98 KB up and 1.2–2.2 KB down per page, on simulated photos. |
| 4 | Low-end phones | **Partly** | 22 MB APK (arm64), minSdk 24 (Android 7.0+). Requires a camera and microphone. RAM while reading not measured; never run on a 2 GB or Android 8–10 phone. |
| 5 | Structure | **Partly** | Reading order is top to bottom; **two-column pages are merged line by line** (measured). Tables only from PDFs, not from photos in production (Tesseract). No headings. The Reader moves by line and by row and jumps to tables; there's no column or heading navigation. |
| 6 | Accessibility tests | **Partly** | 56 `expectAccessible` checks (tap action and 64 px) across 16 test files, run in CI on every push. No contrast or label guideline tests. The TalkBack walkthroughs are manual, on the emulator. |
| 7 | Feedback | **Missing** (mostly) | "Report a problem" is text that says to email support@magana.ng; the address can't be tapped. No measure of sighted help: the portal's "Done without sighted help" has nothing feeding it. |
| 8 | Consent | **Partly** | The teacher records consent in the portal (signed form, in person, or by phone), so a guardian can consent by voice. No script or accessible form for the guardian. The app's own consent screen strings are unused. |
| 9 | Explain | **Partly** (off in production) | 20-prompt set: base N-ATLaS **6/20 and 8/20** (two runs), Magana LoRA **13/20**, but the LoRA answers every language in English. Top failures: invented numbers, dropped placeholders, false alarms on markers. |
| 10 | Language | **Partly** | UI: all strings in Hausa, Yorùbá and Igbo, machine-assisted drafts. Medicine label templates: native-reviewed and clinically approved (4 Igbo stay English). TTS, ASR and Explain mostly fall back to English or are off. **OCR strips Hausa, Yorùbá and Igbo letters without a warning** (measured). |

---

## 1. Capture guidance for blind users: **Partly**

**What exists:**
- **Live framing** (`app/lib/capture/frame_analysis.dart`, `FrameAnalyzer`; `app/lib/screens/capture.dart`).
  - About 5 camera frames a second are reduced to a 48×64 greyscale grid.
  - The page is found as the bright region against a darker background (Otsu threshold).
  - Advice (`Advice` enum): too dark, no page, move closer, move further (`liftPhone`), move up, down, left or right (an edge is cut), hold still, ready.
  - Thresholds are named constants (`darkMean = 45`, `minPageArea = 0.30`) so they can be tuned with testers.
- **Spoken cues:** one or two words (`cueMoreLight`, `cueCloser`, `cueLeft`…), said whenever the voice has been quiet for 1 s (`_guide`).
- **Non-speech cues:** a tick and a light vibration that speed up as the page fits (`_tick`, `tickInterval(fit)`; `capture/feedback.dart`).
- **Auto-capture:** when the page is whole and has been steady for 4 frames in a row (about 1 s; `steadyFramesNeeded = 4`). Auto-capture is a switch, on by default (`_AutoCaptureToggle`).
- **Torch:** a toggle with a TalkBack label and state (`Semantics(toggled: …)`).
- **TalkBack-friendly controls:** every button has a `Semantics` label, its own tap action and a size of at least 64 px (`test/a11y.dart`, `expectAccessible`).
  - The guidance text is deliberately **not** a live region, so TalkBack doesn't announce it on top of the app's speech (comment in `capture.dart`, around line 469).
- **Feedback after the photo:** the server returns photo tips that are spoken (`too_dark`, `blurry`, `small_print`; `backend/app/reader.py` around line 336; `app/lib/messages.dart`).

**Gaps:**
- **Tilt:** no cue. The app reads no accelerometer or gyroscope, so a skewed page is caught only indirectly, through its edges or the page's size.
- **Blur while framing:** not checked. "Hold still" comes from frame-to-frame movement, not sharpness. Blur is caught only *after* the photo, by the server's edge-variance check (`blurry` below variance 50).
- **Too far:** handled ("move closer" below 30% of the frame). **Too close:** handled only when edges are cut on opposite sides ("move further").
- **Web (PWA):** no live framing or torch (`liveFramingSupported => !kIsWeb`, `app/lib/platform.dart`).
- **Never tried on a real phone or by a blind user.** The emulator has no real camera scene. Thresholds are untuned.

**What's needed:** a tilt cue from the accelerometer; a sharpness score per frame (for example, edge variance on the grid) before auto-capture; tuning the thresholds with testers on 2–3 real low-cost phones.

## 2. Confidence signalling: **Exists**, with one gap

**What exists:**
- **Per word and per line:**
  - Tesseract gives each word a confidence, and the line's confidence is their average (`TesseractEngine.read`, `backend/app/reader.py` around line 95).
  - PaddleOCR scores whole lines; each word carries its line's score.
- **Warnings** (`backend/app/main.py`, `checked`; `backend/app/safety.py`):

  | Check | When |
  |---|---|
  | `confidence_warnings` | line below **0.75** |
  | `number_warnings` | each number below **0.90**, or two readings that agree at **0.80 or more** each (pending clinical sign-off) |
  | `line_end_warnings` | ink carries on past the read text |
  | `line_part_warnings` | print in the line that no word covers |
  | `handwritten_health` | handwritten lines on a health paper |
  | `number_mismatches` | a second whole-page pass on health and money pages disagrees |
  | `money_photo_check` | a money page from a photo: no partial amounts |

- **Faint print:** `recover_faint` finds bands of faint ink the OCR dropped and reports them as `faint_region`. The Reader speaks them as "faint print" with their position.
- **In the app** (`app/lib/screens/reader.dart`):
  - Each warning is spoken after its line.
  - A number that wasn't read reliably is spoken and shown as "unclear number", never as the guessed digit.
  - The header shows how many items are unsure, and "Jump within page" can go to the warnings.

**Blurry page:**
- The server returns `blurry` (edge variance below 50) and the app says "The photo looks blurry. Hold the phone still and try again."
- Lines it still reads carry their low-confidence warnings.

**Partly cut-off page:**
- With the live camera, framing advice ("move left"…) stops auto-capture until the page is whole.
- **Gap:** a gallery photo, a system-camera photo or a PDF page that is cut at the photo's edge is **not detected**. `line_end_unclear` fires only when ink continues *inside* the image. Text running off the photo's edge ends cleanly at the border, so it is read as if complete.

**What's needed:** a server check for text touching the image border, giving a tip such as `page_cut_off`, so an edge-cut gallery photo gets a spoken warning.

## 3. Offline: **Partly**

| Feature | Offline? | Where |
|---|---|---|
| Read a new page (photo) | **No**: `POST /read` | `app/lib/api.dart` `read()` |
| Read a PDF | **No**: `POST /read-pdf` | `api.dart` `readPdf()` |
| Reader, for a saved reading (Library, kept 30 days) | **Yes** | `app/lib/library.dart` |
| Text to speech | **Yes**: the phone's engine (`flutter_tts`), if a voice is installed | `app/lib/speech.dart` |
| Quiz, team-made packs (12, Primary to SSS) | **Yes**: bundled in `assets/quiz/` | `app/lib/quiz.dart` `Quiz.load` |
| Quiz, a teacher's class session | **No**: `GET /learner/quizzes` | `api.dart` |
| Spoken quiz answers | **Only** with the phone's on-device recogniser; otherwise the server (`/asr`, `/asr/choose`) or tap | `app/lib/voice_input.dart` |
| Explain | **No**: `POST /explain`, and off in production | `api.dart`, `screens/explain.dart` |
| Health check (Ibà) | **No**: `/triage/questions`, `/triage/assess`. Offline it shows and speaks the error. The "Emergency? Call 112" banner still works (it dials the number) | `screens/health_worker.dart` |
| Call-back request | **No**: `POST /callback` | `api.dart` |
| Join or change class, consent status | **No**: `/learner/join`, `/learner/me`, `/learner/change-class` | `api.dart`, `screens/onboarding.dart` |
| Skills lessons, reminders, Independence Score | **Yes**: on the phone | `assets/lessons`, `reminders.dart`, `tasks.dart` |

- **On-device OCR is missing.** CLAUDE.md plans "offline fallback with ML Kit OCR + device TTS", but `pubspec.yaml` has no ML Kit or other on-device OCR package. Without internet, the main feature does not work.

**Data used per page read (measured today):**
- **Method:** three team-made benchmark pages (`benchmark/explain/pages/`), drawn at 300 dpi and made phone-like (`bank_benchmark.photo_like`: tilt, blur, uneven light, JPEG).
- **Two upload sizes:**
  - **Live camera:** `ResolutionPreset.high`, about 1280×720 in the camera plugin (the actual still size can vary by phone). The page fills about 85% of the frame; JPEG q95.
  - **Gallery or system camera:** `maxWidth: 2400`, `imageQuality: 88` (`capture.dart` around line 294).
- Posted to `/read` on the local backend (Tesseract); response sizes are raw and gzipped (Caddy serves the API with `encode gzip`, `deploy/Caddyfile`). The measuring script was a one-off and is not in the repo.

| Page | Upload: camera | Upload: 2400 px | Response (gzipped) | Words read: camera / 2400 px |
|---|---|---|---|---|
| 01 food tests (school) | 35.5 KB | 86.3 KB | 1.2 / 1.4 KB | 39/41 / 40/41 |
| 03 fractions (school) | 35.5 KB | 85.0 KB | 1.5 / 2.2 KB | 60/61 / 60/61 |
| 04 medicine label (health) | 37.9 KB | 96.1 KB | 1.5 / 1.7 KB | 59/59 / 59/59 |

- **About 37–40 KB per page with the live camera, and 87–98 KB from the gallery,** plus the HTTPS and multipart overhead (not measured).
- **These are lower bounds.** Simulated photos compress better than real ones: a real phone photo has more noise and texture, so its JPEG will be larger. **Not yet measured on a real phone.**
- At 1280×720, word recall on these pages (about 10 pt print) matched the 2400 px photos. **Small print at 720p is untested.**

**What's needed:**
- An on-device OCR fallback (ML Kit Text Recognition, Latin script). Read offline with the same "unclear" rules, and tell the user that the offline reading has no second number check.
- Measure data on a real phone with real pages.

## 4. Low-end phones: **Partly**

**App size:**
- Release APK split per ABI, built 26 Oct (`app/build/app/outputs/flutter-apk/`):
  - arm64-v8a: **22,137,494 bytes (22.1 MB)**
  - armeabi-v7a: 19.9 MB
  - x86_64: 23.7 MB
- Download size and installed size on a phone have not been measured.

**Android versions:**
- The built APK says **minSdkVersion 24 (Android 7.0)** and targetSdk 36 (`aapt2 dump badging`). Android 8–10 is therefore inside the supported range, but **never tested** on those versions: the only device used is the Android 16 emulator.

**RAM:**
- **Not measured.** No phone or emulator was running, and starting the emulator would load your Mac heavily.
- To measure: `adb shell dumpsys meminfo com.magana.app` while the Reader speaks a page and while Capture is framing, on a 2 GB phone.
- Design choices that help: frames are analysed at about 5 a second on a 48×64 grid (`capture.dart` `_onFrame`); OCR runs on the server, not the phone.

**Required hardware and permissions:**
- **Required:** camera (`android.hardware.camera.any` and `android.hardware.camera`, the default `required="true"`). Microphone is implied by `RECORD_AUDIO` and also required. Play Store hides the app from phones without them.
- **Not used:** accelerometer, gyroscope, GPS.
- **Permissions:** camera, microphone, notifications, exact alarms and boot (for reminders), vibration, and storage up to Android 9.

**What's needed:**
- Install on 2–3 real low-cost phones (Android 8–10, 2 GB, for example Itel, Tecno or Infinix entry models). Record install size, cold-start time, RAM while framing and reading, and battery for 10 pages.
- Consider `required="false"` for the microphone, since everything works by tapping.

## 5. Structure: **Partly**

**Reading order:**
- Both OCR engines sort lines **top to bottom by their top edge** (`TesseractEngine`: `sorted(… key=top)`, `reader.py` around line 109; PaddleOCR: `lines.sort(key=top)`, around line 292).
- **Two-column pages are merged.** Measured today with Tesseract: a page with two columns of three lines came back as three lines, each joining the left and right columns: "LEFT one: plants need light. RIGHT one: the heart pumps."
- Textbooks, newspapers and many leaflets use columns.

**Headings:**
- **None.** The server sends lines and tables, with no heading or layout labels.
- The Reader's "Jump within page" says "Jumping to headings and diagrams is not available yet." (`jumpNotYet`, `reader.dart` around line 224).

**Tables:**
- **From PDFs (text layer):** yes (`backend/app/pdfs.py`).
- **From PaddleOCR PP-StructureV3:** yes, but **Paddle is not in production.** `OCR_ENGINE=tesseract` on the t3.small, and the Paddle decision is due around 20 Nov.
- **With Tesseract, photographed tables come back as plain lines.**
- When a table exists, the Reader reads it **row by row**, each cell as "header: value", with "unclear number" for flagged cells (`reader.dart` around line 123).

**Navigation with TalkBack:**
- Previous, Repeat and Next work by line, or by row inside a table, as 64 px buttons with labels ("Next row" and so on).
- "Jump within page" goes to the start, to each table, or to the first warning.
- "Find" searches for words, dates or amounts.
- **No column navigation**, and no way to read one column down the rows.
- The Reader shows one item at a time, so TalkBack's own heading and line navigation has nothing to use; navigation is through the app's buttons.

**What's needed:**
- Column detection before ordering, using Tesseract's `block_num` or `par_num`, or Paddle's layout.
- Headings from Paddle's layout labels, then "next heading".
- Tables from photos (Paddle).
- A "read this column" action in tables.

## 6. Accessibility tests: **Partly**

**What exists:**
- **`app/test/a11y.dart` `expectAccessible`:** every enabled button or switch has a semantics **tap action** and every Material button is **at least 64×64 px**. It is used **56 times in 16 test files**.
- **Other semantics checks:** 31 uses of `ensureSemantics` or semantics handles in tests, for example labels, headers and toggled state.
- **CI** (`.github/workflows/ci.yml`): `flutter analyze` and `flutter test` run on **every push and pull request**, and the deploy waits for them. The last 5 runs on main all passed (latest 3fda704).
- **Manual TalkBack walkthroughs:** `tools/talkback/` (`talkback.py`, `quick_check.py`) drive TalkBack on the emulator. FINDINGS records 9 emulator TalkBack sessions. These are **not in CI**.
- The web portal and website run axe (WCAG 2.2 AA plus the 7:1 contrast rule) in CI. That's a separate surface from the app.

**Gaps:**
- Flutter's built-in guidelines are not used: `textContrastGuideline`, `labeledTapTargetGuideline`, `androidTapTargetGuideline`.
- No integration test runs with TalkBack.
- No real TalkBack user has tested the app.

**What's needed:** add `meetsGuideline(textContrastGuideline)` and `labeledTapTargetGuideline` to `expectAccessible`, and test sessions with 3–5 blind users.

## 7. Feedback: **Missing** (mostly)

**Report a problem:**
- Settings and Explain show "Report a problem" as text (`reportHow`): "Tell the Magana team three things: the name of the screen, what you did, and what Magana said." (`screens/settings.dart` around line 172; `screens/explain.dart` `_report`).
- The address `support@magana.ng` appears on the About screen as plain text (`screens/about.dart`). It **can't be tapped**: there is no `mailto:` link.
- There is no in-app form, voice note or attached reading.

**Measure of sighted help:**
- **The app never asks** whether the user needed sighted help.
- The Independence Score (`app/lib/tasks.dart`, `screens/score.dart`) counts tasks finished in the app over 30 days, kept on the phone only. "Share my score with my teacher" is a stored switch; nothing is sent yet.
- The portal's Home shows **"Done without sighted help"**, read from `learner_stats.unaided` (`backend/app/portal_api.py` around line 1300). **Nothing ever writes to `learner_stats`.** No endpoint fills it and the app sends no statistics, so the figure is always empty.

**What's needed:**
- A one-tap, spoken "Did you need help from someone who can see?" (Yes / No / Skip) after a reading or task, kept on the phone.
- An endpoint that receives the weekly counts the learner chooses to share, so the portal figure becomes real.
- A tappable `mailto:` link, or an in-app "Send a problem report" that sends the screen name and app version, never page text without asking.

## 8. Consent: **Partly**

**How it works now:**
- For a learner in a class, the **teacher records the guardian's consent in the portal**: Learner page, Record consent (`portal/app/(portal)/learner/page.tsx`).
- The teacher chooses how the guardian agreed: **signed form, in person, or phone call** (`ConsentIn.how`, `backend/app/portal_api.py` around line 1118).
- No guardian name or phone number is stored.
- The app learns the status from `/learner/me` (`screens/onboarding.dart`). Until consent is recorded, a Guided learner may read schoolwork pages only (`GUIDED_WAITING`; DRAFT, pending Nurse Balogun).
- The portal's screens pass axe (WCAG 2.2 AA) and work with a screen reader.

**Screen reader or audio only:**
- "In person" and "phone call" mean a **blind or non-reading guardian can consent by voice**, through the teacher.
- **No consent script or accessible information exists** for the teacher to read or play to the guardian: no printed form, no audio, nothing in the four languages. `docs/PRIVACY.md` covers what the guardian should know, but it is long and English only.
- The app still holds strings for an old in-app consent screen (`consentTitle`, `consentBody`, `consentPoint1`–`3`, `consentConfirm`, in `app/lib/l10n/*.arb`). **No screen uses them.**

**What's needed:**
- A short consent script (about 150 words) for the teacher to read aloud or play, in English, Hausa, Yorùbá and Igbo. Recorded audio, and an accessible printable form (large print, plus a Braille-ready file from the existing BRF path).
- Nurse Balogun to approve the script.
- Remove or reuse the unused app strings.

## 9. Explain: **Partly** (off in production)

**Status:**
- Production runs `EXPLAIN_ENGINE=stub` (`deploy/.env.example`): Explain is off outside development.
- The app shows "Explain preview" text and reads the page instead.

**The 20-prompt set:** 5 schoolwork pages × 4 languages (`benchmark/explain/`). Latest results (docs/FINDINGS.md, 25 Oct):

| Run | English | Hausa | Yorùbá | Igbo | **All** |
|---|---|---|---|---|---|
| Base N-ATLaS, Q4_K_M on the Mac, re-scored with list bullets | 1/5 | 4/5 | 0/5 | 3/5 | **8/20** |
| Base N-ATLaS, Kaggle T4 4-bit | 1/5 | 3/5 | 0/5 | 2/5 | **6/20** |
| Magana LoRA (English-trained), Kaggle T4 | 4/5 | 4/5\* | 3/5\* | 2/5\* | **13/20\*** |

\* The LoRA answers **in English whatever language is asked for**. The wrong-language check now refuses those answers (15 of 15), so routing sends only English to the LoRA (`explain.ADAPTER_LANGS = {"en"}`).
- The pass rate of the routing as built (LoRA for English, base for the others) **has not been measured in one run**.
- No native speaker has rated any answer.

**Top 3 failure reasons** (base model, 20 answers):
1. **The model writes numbers itself:** 9 of 20 answers invented or added numbers, number words or units (dates, naira amounts, "5 minutes", "48 hours days"). All were refused, and the page is read instead.
2. **Placeholders dropped:** 12 of 20 answers dropped some ⟦N⟧ markers; 5 dropped enough to fail. Nothing wrong would have been said, but the page is read instead.
3. **False alarms on badly formed markers:** "⟦1⟧" without the N, "N1" without brackets, a marker repeated in worked steps. There were 3 in the latest run; earlier, innocent words such as Igbo "ọnwa" (month).

For the LoRA, the main failure is the **wrong language**, plus harmless ordinal words ("the first column").

**What's needed:** LoRA version 2 with native-reviewed Hausa, Yorùbá and Igbo examples; one benchmark run of the routing as built; native-speaker rating of the answers that pass.

## 10. Language: **Partly**

| | English | Hausa | Yorùbá | Igbo |
|---|---|---|---|---|
| **UI text** (`app/lib/l10n/app_*.arb`, 537 strings) | Real | All 537 present; **machine-assisted draft**, needs native review (`@@x-review`) | Same | Same |
| **Spoken voice (TTS)** | Phone voice (en-NG, else en-GB or en-US) | **Falls back to the English voice** unless the phone has a Hausa voice, which most don't (`speech.dart` `_pickVoice`). Server MMS-TTS exists but the app doesn't use it | Same | Same |
| **Reading a page in that language (OCR)** | Real (Tesseract `eng`) | **Letters lost.** Only `eng` is installed (`backend/Dockerfile`); measured below | Same | Same |
| **Health papers** (medicine label templates, 15) | Real | Native-reviewed and clinically approved (25 Oct) | Same | Approved except #7, #9, #12, #13, which stay in English for now |
| **Explain** | Base or LoRA; **off in production** | Base N-ATLaS; **off** | Same | Same |
| **ASR (speech in)** | Phone's recogniser. Server Whisper exists but production uses `ASR_ENGINE=device`. Quiz "Say": on for adults and JSS/SSS (79% closed-set) | Phone's recogniser if it has Hausa; "Say" hidden (51%) | Same; "Say" hidden (58%) | Same; "Say" hidden (28%) |
| **WhatsApp voice notes** | Off (`WHATSAPP_VOICE=off`) | Off | Off | Off |

**OCR of local-language print (measured today):**
- One clean line each, rendered in a font that has the letters, read with production's Tesseract `eng`:
  - "Ọmọ náà ń ṣeré nínú ọgbà." came back as "Omo naa Nn seré ninud ogba." (confidence 0.70, warned).
  - "Ƙasar … ɗalibai" came back as "Kasar … dalibai" (**0.92, no warning**).
  - "Ụmụaka na-agụ akwụkwọ n'ụlọ akwụkwọ." came back as "Umuaka na-agu akwukwo n'ulo akwukwo." (**0.87, no warning**).
- **Hausa and Igbo letters are silently replaced.** For Hausa, ɗ/d and ƙ/k are different sounds and can change a word's meaning.

**What's needed:**
- Install Tesseract `hau`, `yor` and `ibo` data and choose it from the app language, or test PaddleOCR's Latin model on these letters. Measure on real Hausa, Yorùbá and Igbo pages.
- Use MMS-TTS on the server for Hausa, Yorùbá and Igbo voices, or say clearly when the English voice reads Hausa text.
- Native review of the UI strings.

---

## Highest-priority gaps for the white paper

*As audited. Since then items 1–4 below have been addressed in code (see "Status after the fixes" above). Item 5, a real phone and a blind tester, is still open.*

1. **No offline reading** (item 3). The main promise ("partly offline") isn't met: reading a page needs the server.
2. **Two-column pages merge their columns** (item 5). A comprehension risk on textbooks and leaflets.
3. **Hausa, Yorùbá and Igbo print loses its letters without a warning** (item 10).
4. **No measure of sighted help** (item 7). The portal shows a figure that nothing feeds.
5. **No real phone and no blind tester yet** (items 1, 4 and 6). Every accessibility claim is emulator-only.
