# Magana findings log

Running evidence for the hackathon documentation and the accessibility note.
Newest first. Only results we actually measured; nothing estimated or rounded up.
Test names refer to `backend/tests/` (pytest) and `app/test/` (flutter test).

Devices used so far:
- **Mac**: development machine, Tesseract 5.5.3, pages rendered or photographed for tests.
- **Emulator**: Android emulator `Medium_Phone_API_36.1` (Android 16, API 36) with TalkBack, debug build, backend on the Mac with Tesseract.
- **Chrome**: desktop Chrome driven by Playwright, at 1280×900 and 390×844.

No real phone and no blind or low-vision tester has been used yet.

---

## 2026-10-24 · Triage/Ibà, accessibility: the quick check asks about things you need sight to check

- **What we tested and how:** the Ibà quick check on the Emulator, reviewed by Jemiri Daniel Taiwo from screenshots of the answered questions.
- **Result:** at least 3 of the questions can't be answered without sight:
  - "Are you bleeding without a clear reason, from the nose or gums, or in vomit or stool?"
  - "Is your urine very dark, like cola or tea?"
  - "Are your palms, lips or inner eyelids very pale?"

  A blind user can't check these alone, so a "No" may only mean "I can't tell", and a danger sign could be missed.
- **What we changed:** nothing yet. This entry records the problem.
- **Status:** open. The rewording is clinical content and needs Dr. Amos's sign-off.

## 2026-10-24 · Accessibility: TalkBack speaking over the app skipped lines

- **What we tested and how:** on the Emulator with TalkBack on, we played the "Phone basics" lesson and made three TalkBack swipes, 2.5 s apart. We then read a medicine label (`medicine_label.png`, gallery) in the Reader.
- **Result before the fix:** 12 s after pressing Play the lesson was at step 5 of 6. Each TalkBack announcement cut the app's speech off, and the app treated that as "finished" and moved on. The Reader loop works the same way, so a cut-off dose line would have been skipped.
- **Result after the fix:**
  - The same swipe test left the lesson on step 1, paused.
  - Pressing Play still reads straight through: without swipes, the lesson was at step 3 after 25 s, which is normal speaking pace.
  - The medicine label was read to the end, with 4 utterances completed (intro, line 1, line 2, end note). TalkBack's own announcement when the screen opened no longer stops the reading.
- **What we changed:**
  - `Speaker.say` now reports whether an utterance finished (2307965).
  - A line that is cut off is said once more, and reading pauses on it if it is cut off again (420ff0e).
  - Guarded by the tests `TalkBack speaking over a line pauses there, never skips it`, `a line cut off once is said again, then reading goes on` and `TalkBack speaking over a step pauses the lesson there`.
- **Status:** fixed on the Emulator. Untested on a real phone and with real TalkBack users.

## 2026-10-24 · Accessibility (test method): uiautomator dumps disturb TalkBack testing

- **What we tested and how:** on the Emulator, we compared a single touch on a quiz option made right after a `uiautomator dump` with the same touch made 2.5 s after it.
- **Result:**
  - Right after a dump, the touch reached the app as a plain click and answered the question (seen 3 times).
  - 2.5 s later, the same touch only moved TalkBack focus.
  - Polling the screen with dumps also cut off app speech, which made lessons appear to skip steps.
- **What we changed:** the test helper waits 2.5 s between locating a control and touching it, and speech checks avoid polling. These are scratch test tools, not committed.
- **Status:** limitation of our test method. Results from dump-heavy runs before this date may include such artefacts.

## 2026-10-24 · Accessibility: answered quiz options turned grey

- **What we tested and how:** Voice quiz on the Emulator with TalkBack, screenshot after answering.
- **Result:** answered options were disabled, so their text turned grey (below our 7:1 contrast rule) and TalkBack read them as disabled.
- **What we changed:** options stay enabled and full contrast, and touching one again repeats the verdict (b71176f). Test: `wrong answer: says the right one and marks it`.
- **Status:** fixed.

## 2026-10-24 · Accessibility: a medicine reminder could ring up to an hour late

- **What we tested and how:** we saved a reminder on the Emulator and read the scheduled alarm with `adb shell dumpsys alarm`.
- **Result:**
  - Without the "Alarms & reminders" permission, Android 14 and later scheduled it as inexact, with a window of +1h0m.
  - After turning the switch on through the app's prompt (with TalkBack), the alarm was rescheduled with window=0 (exact).
- **What we changed:** the first save explains the permission and opens the switch. If the user refuses, the reminders list warns that reminders may ring up to an hour late (cb43981). Test: `not on time yet: explained once, then the phone setting`.
- **Status:** fixed, as long as the user grants the permission. Untested: a reminder actually firing and ringing on the device. We only checked the schedule.

## 2026-10-24 · Safety: library titles and unreliable numbers

- **What we tested and how:** unit test `titles never show an unreliable number or cut one in half`. The page was a label line whose "500" the backend flagged `low_confidence_number`.
- **Result:** the title reads "Amoxicillin [unclear number] mg capsules …". "500" never appears, and the title is shortened only between whole words.
- **What we changed:** titles are built when shown, from the saved reading, with flagged numbers masked (420ff0e). We found this risk while designing the library, before any user saw it.
- **Status:** fixed (design safeguard).

## 2026-10-24 · Languages: the voice quiz has not been tried with real speech

- **What we tested and how:** the Voice quiz on the Emulator, which has no microphone input. The marking rules are covered by unit tests in `app/test/quiz_test.dart`.
- **Result:** the microphone permission, listening state and "I did not hear an answer" prompt all work. No spoken answer has been recognised, because none was spoken.
- **What we changed:** nothing.
- **Status:** untested. Speech recognition with Nigerian English accents, and in noisy classrooms, is unmeasured.

## 2026-10-24 · Triage/Ibà: "Ibà not configured" and the 10-minute alert

- **What we tested and how:** `test_iba_monitor.py` and `test_triage.py::test_not_configured_uses_the_fallback_questions`, on the Mac.
- **Result:**
  - With no `IBA_API_URL`, Magana uses its built-in questions and rules. It logs `triage source=fallback reason=not_configured` and doesn't count this as an outage.
  - When Ibà is unreachable there is no alert at 9 minutes and exactly one at 10 minutes (CRITICAL log line, plus an optional webhook). Recovery is announced and resets the clock, and a short blip also resets it.
  - Log lines never contain the user's answers.
- **What we changed:** f871953.
- **Status:** fixed (tested with simulated time). No real 10-minute outage has been observed.

## 2026-10-24 · Triage/Ibà: fallback timings and the danger-sign backstop

- **What we tested and how:** Magana against the real iba-natlas `/v1` server on the Mac, with Ibà frozen and then stopped, plus the `test_triage.py` tests.
- **Result:**
  - Ibà frozen: Magana answered from its fallback in 3.01 s.
  - Ibà stopped: Magana answered in 0.02 s.
  - A danger sign is always an emergency, even if Ibà answers otherwise (`test_a_danger_sign_is_an_emergency_even_if_iba_says_otherwise`). The danger-sign ids are checked against iba-natlas (`test_danger_signs_match_iba`).
- **What we changed:** 497196f.
- **Status:** fixed.

## 2026-10-24 · Reading accuracy: lines whose end can't be read

- **What we tested and how:** the real damaged photo `fixtures/misreads/line_end_damaged.jpg` of "Do not take more than 8 in 24 hours", read on the Mac. Only "Lo nol lake mo" was read, at line confidence 0.44. Tests are in `test_line_ends.py`.
- **Result:**
  - The line is now flagged `end_unclear`, and the app says "I can't read the end of line N. Please check it or retake the photo."
  - Not flagged: the clean label at 40 px and 28 px, and a two-column page.
- **What we changed:** 7e3f90e.
- **Status:** limitation. Magana can say the end is missing, but it can't recover the text; the user has to retake the photo or ask someone.

## 2026-10-24 · Reading accuracy: N12,000.00 at 0.88 and the two-readings rule

- **What we tested and how:** a rendered bank statement in 28 px print, read on the Mac. Tests: `test_n12000_two_agreeing_readings_are_accepted`, `test_n12000_in_small_print_is_not_flagged_end_to_end`, `test_two_reading_thresholds`.
- **Result:**
  - "N12,000.00" was read correctly at 0.88 on the page, below the 0.90 rule, so it was a false alarm.
  - Its crop re-read gave the same digits at 0.90.
- **What we changed:** a number is now accepted when the two independent readings agree and both are at least 0.80. Disagreeing readings are always flagged (5627ee1).
- **Status:** fixed. Both thresholds are pending clinical sign-off.

## 2026-10-24 · Reading accuracy: re-reading every number from its own crop

- **What we tested and how:** every number on the test pages (labels, a lab report table, statements), re-read from a crop of the word and its neighbouring words, on the Mac.
- **Result:**
  - 52 numbers re-read, 4 disagreed, and all 4 were real misreads: the faint "8" read as "6", and garbled ×10⁹/L units.
  - 0 false alarms on clean labels or statements.
  - The "6" read at 92% on `dose_faint.png` passes the 0.90 rule on its own; only re-reading catches it, now in schoolwork mode too.
  - While tuning: crops of single words read slivers of letters as "1", and enlarged crops made Tesseract read "500" as "900".
- **What we changed:** d2835e9. Tests: `test_numbers_are_reread_in_every_mode`, `test_misread_dose_photos_are_flagged_in_school_mode_without_a_second_pass`.
- **Status:** fixed for these pages. Untested on a large set of real photos.

## 2026-10-24 · Portal: 10 bugs found in the click-through

- **What we tested and how:** Uploads and Attendance in Chrome at 1280×900 and 390×844 with Playwright and axe-core (WCAG A/AA/AAA).
- **Result:** 10 bugs:
  1. Pages wider than a phone screen, by 216–360 px.
  2. Hidden text widening the page by 16 px on phones.
  3. Download links going to a 404.
  4. Every class showing SS2 Science's register ("Seats used 18 of 30").
  5. Keyboard focus left behind after the P/L/A/E keys.
  6. Scrollable tables unreachable by keyboard (an axe error).
  7. The desktop register squeezed and wrapping.
  8. The phone register about 7,800 px tall; rows went from about 430 px to 160 px after the fix.
  9. The "Session" label pointing at a paragraph.
  10. "Register saved." showing in print.
- **What we changed:** 47a76f7. Lint, build and axe are clean at both sizes.
- **Status:** fixed.
- **Left open:** long session names are cut off in the picker on phones, and uploads stay "Processing" until the backend endpoints exist.

## 2026-10-24 · Accessibility: no tap actions for screen readers

- **What we tested and how:** a TalkBack check on the Emulator and a semantics test over every screen.
- **Result:** no button or switch in the app had a tap action for screen readers. TalkBack reached them only by simulating a touch, and Switch Access, Voice Access and keyboards couldn't use them at all.
- **What we changed:** every control now has its tap action (7a7e3ff).
  - Guarded by `every button and switch can be activated by screen readers` (`app/test/app_test.dart`) and by the `expectAccessible` helper (`app/test/a11y.dart`), which every new screen's tests call.
  - We proved the test can fail: we removed the tap action from "Read from here" and the test caught it.
- **Status:** fixed.

## 2026-10-24 · Languages: font gaps for Hausa, Yorùbá and Igbo letters

- **What we tested and how:** the app in Hausa and Yorùbá on the Emulator.
- **Result:** Atkinson Hyperlegible has no Hausa hooked letters (ɓ ɗ ƙ), no dotted Yorùbá and Igbo vowels (ẹ ọ ṣ ị ụ) and no naira sign. Phones drew those letters in their system font, so the text mixed two fonts.
- **What we changed:** bundled a Latin subset of Noto Sans, about 150 KB each for Regular and Bold (OFL), and used it as the fallback font everywhere (5882f0d). Hooked letters, under-dots and stacked tone marks then rendered cleanly.
- **Status:** fixed. Native speakers haven't checked it yet.

## 2026-10-24 · Reading accuracy: faint dose lines

- **What we tested and how:** a rendered label whose dose line "Do not take more than 8 in 24 hours" is grey on paper of grey 250 (`test_faint.py`), on the Mac.
- **Result:**
  - Plain OCR dropped the faint line entirely.
  - With contrast-boost and retry, it is recovered at grey 150 (blur 1.0), grey 200 (blur 0.6) and grey 235 (blur 0.5).
  - At blur 4.0 the line still can't be read, and it is now reported as a faint region instead of silently missing.
  - Shaded paper and a dark table edge are not mistaken for ink.
- **What we changed:** 409fa5a.
- **Status:** fixed for the rendered cases. On the Emulator, the photographed label `medicine_label.png` read line 2 as "Mo notiake more inan [unclear number] in 24 hours": the dose was flagged, not guessed, but the words around it were garbled (open).

## 2026-10-24 · Safety: "8 in 24 hours" misread as "6" and as "@"

- **What we tested and how:** real photos of a label with "Do not take more than 8 in 24 hours", on the Mac (fixtures in `backend/tests/fixtures/misreads/`):
  - an Emulator photo (JPEG quality 88);
  - the original faint page `dose_faint.png`;
  - broken-print photos at JPEG quality 85 and 88.
- **Result:**
  - The "8" was read as "6" at 64% word confidence, while the whole line averaged 0.766, so the old line-average rule let it through.
  - The "8" was read as "@" (0.26) and as "&".
  - On the faint page the "8" was read as "6" at 92%.
- **How each is now caught (3e6c05c):**
  - "6" at 64%: every number is scored on its own against 0.90 (`low_confidence_number`), in every mode. Test: `test_real_misread_6_at_64_percent_is_flagged_even_though_the_line_looks_fine`.
  - "@" and "&": a non-digit where a number belongs is unreadable and never repaired (`unreadable_number`). Test: `test_real_misread_at_sign_is_flagged`.
  - "6" at 92%: caught only when the number is read a second time. That started as a whole-page second pass in health and money modes, and is now a crop re-read in every mode (see the re-reading entry). Tests: `test_real_misread_6_at_92_percent_is_caught_by_the_second_pass`, `test_misread_dose_photos_never_pass_silently_in_health_mode`.
- **Status:** fixed for these photos. The 0.90 threshold is pending clinical sign-off.

## 2026-10-23 · Reading accuracy: the first Tesseract test

- **What we tested and how:** `test_core.py::test_read_endpoint_reads_text`, a rendered page "Food tests / Starch Iodine solution Blue-black", on the Mac with Tesseract 5.5.3.
- **Result:** Tesseract returned "Food tests Sach ledine solution Blue-black": "Starch" became "Sach" and "Iodine" became "ledine". A capital I read as a lower-case l is a common Tesseract error, and here it would have changed a word a learner needs.
- **What we changed:** the test page renderer now uses a real TrueType font on macOS, so the test is stable (1286433). Tesseract stays a development engine; production OCR is PaddleOCR (77d101c). The test only checks for "odine", so an I/l confusion is tolerated there, not fixed.
- **Status:** limitation of Tesseract. Confidence warnings exist for this kind of error.

---

## User testing sessions

Tester IDs only, never names.

| Date | Tester ID | Blind / low vision | Tasks tried | Completed without sighted help (yes/no) | Time | Errors | What they said | What we changed |
|---|---|---|---|---|---|---|---|---|

## Clinical and language sign-offs

| What was approved | By whom | When |
|---|---|---|
