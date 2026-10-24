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

## 2026-10-24 · Accessibility: Independence Score history and sharing (L3)

- **What we tested and how:** `skills_score_test.dart`: `L3: the starting score is remembered, shown after a week` and `L3: up from where you started; share with my teacher` (with `expectAccessible`).
- **Result:**
  - The first score is remembered on the phone. "Up from 10 when you started, 2 weeks ago" is shown and spoken once at least a week has passed; before that, nothing is claimed.
  - "Share my score with my teacher" is the learner's choice. Nothing is sent until the class is connected to the teacher portal, and the screen says so.
- **Bug found by the test and fixed:** tapping the share row's text did nothing; only the small switch reacted. The whole 64 px row now toggles it.
- **What we changed:** this commit.
- **Status:** fixed.
  - L1 Skills has 3 sample lessons instead of the board's 5 tracks, as decided earlier.
  - L2 Champions stays a static sample profile, without the board's Call, Voice message and Book training buttons, because no Champion programme exists yet.

## 2026-10-24 · Safety, accessibility: Everyday papers built to the design (E0–E3, E6)

- **What we tested and how:** app tests in `everyday_more_test.dart`, 11 in all:
  - the read-any-paper word rules;
  - the spoken-answer word rules;
  - one test each for E0, letters, E1, E2, E3 and E6, plus the under-18 refusal.

  Backend test: `test_letter_mode_is_adults_only_and_gets_the_second_pass`.
- **Result:**
  - "Read any paper" always reads in the strict letter mode (second pass and every number rule). It then picks the paper type by fixed word rules: at least two signs and no tie, otherwise "letter". It never changes what is read.
  - "What does this mean?" on a medical report never interprets the result. It says only a health worker can, then offers Save question (the question is shown in Talk to a health worker) and Ask a nurse.
  - The statement summary shows the balance lines exactly as printed.
  - "Find a transaction" ignores commas: "6450" found "N6,450.00", and a word that isn't on the page is said back.
  - Spoken quick-check answers accept only fixed words. "maybe" is said back and the question is asked again.
- **Bug found by the tests and fixed:** the "Find a transaction" dialog disposed its text controller while the dialog was still closing. That threw and overflowed the layout by 99,674 px in the test. The dialog now owns its controller.
- **What we changed:** this commit.
- **Status:** fixed in tests; not yet checked with TalkBack on a device.
  - Not built, by choice: E1's separate label fields ("Directions", "Expiry date", "Prescribed for"). Labelling parts of a label means guessing what each line is. The Reader reads the lines exactly as printed instead.
  - The spoken-answer words in Hausa, Yorùbá and Igbo need native-speaker checks, and recognising them depends on the phone's recogniser.

## 2026-10-24 · Safety: in PaddleOCR mode, numbers are not re-read from crops

- **What we tested and how:** reading the code while preparing the production deploy: `reader.reread_numbers` and `PaddleStructureEngine`. Not yet measured on a device or a real page.
- **Result:**
  - `reread_numbers` only re-reads words that have a box (`w.width and w.height`). PaddleOCR's words carry no boxes (PP-OCR scores whole lines), so in Paddle mode the crop re-read finds no work and silently does nothing.
  - Paddle has no `snippet_engine` either.
  - So with `MAGANA_OCR=paddle`, the check that caught the "6" read at 92% (see "Re-reading every number from its own crop") does not run. Numbers fall back to the 0.90 rule, and in health and money modes also to the whole-page second pass.
- **What we changed:** nothing yet. Production stays on Tesseract until this is fixed and measured.
- **Status:** open, and it blocks using PaddleOCR in production.

## 2026-10-24 · Safety: the Explain preview and the number guard

- **What we tested and how:**
  - Backend tests in `test_explain.py`:
    - `test_preview_gives_back_the_page_text_unchanged`
    - `test_an_explanation_with_a_number_not_on_the_page_is_never_given`
    - `test_guided_learners_may_use_explain_but_classroom_may_not`
    - `test_empty_or_too_long_source_is_refused`
    - `test_unknown_language_or_style_is_refused`
    - `test_only_the_preview_engine_exists_until_natlas_is_hosted`
  - App tests in `learner_test.dart`: `6 explain (preview): page text through the guard, unclear stays unclear` and `explain: when the guard fails, the page is read instead`.
- **Result:**
  - The new `/explain` endpoint runs every explanation through `guard_explanation`. A fake model that answered "Take 3 tablets" for a page saying "Take 2" got no explanation through; the page text was returned to read instead (`numbers_unconfirmed`).
  - The app hands Explain the page as it was read, with flagged numbers already said as "unclear number". On a label whose "500" was flagged, the text sent to `/explain` contained "Amoxicillin unclear number mg" and never "500".
  - We checked the test can fail: with the unmasked text sent, it failed.
  - Until N-ATLAS is hosted, the preview engine returns the page text unchanged, and the screen says it is a preview.
- **What we changed:** this commit.
- **Status:** fixed for the preview. N-ATLAS's real explanations, and their quality in Hausa, Yorùbá and Igbo, are untested.

## 2026-10-24 · Triage/Ibà, accessibility: "I can't tell" on every quick-check question

- **What we tested and how:**
  - Backend tests in `test_triage.py`:
    - `test_every_question_offers_cant_tell_and_sight_based_ones_are_reworded`
    - `test_fallback_questions_offer_cant_tell`
    - `test_cant_tell_is_sent_as_unanswered_never_as_no`
    - `test_cant_tell_on_a_danger_sign_is_at_least_urgent_and_asks_someone_to_check`
    - `test_cant_tell_on_a_danger_sign_beats_an_urgent_fever`
    - `test_cant_tell_elsewhere_is_never_left_at_routine`
    - `test_a_yes_is_still_an_emergency_whatever_else_is_unknown`
    - `test_cant_tell_without_iba`
    - `test_reworded_sight_based_questions_are_the_drafted_ones`
  - App tests in `health_worker_test.dart`: `Iba down: built-in questions, labelled honestly, buttons stay on screen`, `a danger sign you cannot tell: never a no, ask someone to check`, `"I can't tell" is offered for the number of fever days too`.
  - On the Emulator with TalkBack, using `tools/talkback/quick_check.py`: all 10 built-in questions, with "I can't tell" on question 5 (bleeding).
- **Result:**
  - Every question now offers "I can't tell", including the number of fever days.
  - Magana sends it to Ibà as unanswered (`null`), never as `false`. Ibà's `assess_self_report` currently counts unanswered as "no", so Magana sets its own floor:
    - "I can't tell" on a danger sign gives at least urgent, with "Please ask someone near you to check, or go to a clinic."
    - "I can't tell" on any other question never leaves the result at routine, because the rule that needed the answer couldn't be applied.
    - A "Yes" is still always an emergency.
  - On the Emulator the result screen read: "Please ask someone near you to check, or go to a clinic. A nurse should call you within 2 hours. Request a call back now. If you get worse, go to a clinic or call 112." The backend logged `priority=urgent`, with no answers.
  - The three sight-dependent questions were reworded as drafted:
    - bleeding: felt or tasted blood, or someone told you;
    - dark urine: someone near you has seen it;
    - pallor: someone told you, or weak, dizzy or out of breath on standing.

    The yellow-eyes wording from the previous entry stays. This replaces the previous entry's "I can't check" answer, which applied only to the four sight-based questions and was sent to Ibà as `false`.
- **What we changed:** this commit, plus the iba-natlas issue https://github.com/jemiridaniel/iba-natlas/issues/1, so that Ibà's `/v1` self-report mode makes the same change.
- **Status:** fixed in Magana, but the whole rule is a DRAFT pending Dr. Amos's sign-off. That covers the "never No" floor, raising unknown non-danger answers to urgent (our choice, since the user asked only about danger signs), the wording, and the Hausa, Yorùbá and Igbo drafts. The pallor question now also asks about symptoms (weak, dizzy, breathless), which widens the sign; Dr. Amos should confirm. Ibà itself still counts unanswered as "no" (iba-natlas issue). Not yet tried by a blind user.

## 2026-10-24 · Reading accuracy: words around the dose garbled on a photographed label

- **What we tested and how:** the photographed medicine label `medicine_label.png`, chosen from the gallery on the Emulator and read in health mode (Tesseract on the Mac backend).
- **Result:**
  - Line 1, "Paracetamol 500 mg tablets", was read correctly.
  - Line 2, "Do not take more than 8 in 24 hours", came back as "Mo notiake more inan [unclear number] in 24 hours".
  - The dose number was flagged, not guessed, but the words around it were garbled, so a user hears a sentence that doesn't make sense.
- **What we changed:** nothing yet.
- **Status:** open. Untested with PaddleOCR, the production engine, on this photo.

## 2026-10-24 · Triage/Ibà, accessibility: the quick check asks about things you need sight to check

- **What we tested and how:** the Ibà quick check on the Emulator, reviewed by Jemiri Daniel Taiwo from screenshots of the answered questions.
- **Result:** 4 of the 10 danger-sign questions need sight to answer:
  - bleeding "in vomit or stool";
  - "eyes or skin turned yellow";
  - "palms, lips or inner eyelids very pale";
  - "urine very dark, like cola or tea".

  A blind user can't check these alone, so a "No" may only mean "I can't tell", and a danger sign could be missed.
- **What we changed (this commit):**
  - Magana now words these four questions so they can be answered without sight: "Has anyone told you…", and for bleeding also signs you can feel, such as a nosebleed or blood you can taste. The wording exists in English, Hausa, Yorùbá and Igbo.
  - The four questions also offer "I can't check", with a note suggesting the user ask someone they trust.
  - "I can't check" is sent to Ibà as "no", so it is never an emergency on its own. If the result would be routine, Magana raises it to the faster call-back. The result says "You could not check N signs. Tell the nurse when they call."
  - A "Yes" is still always an emergency.
  - Ibà's own rules and question ids are unchanged.
- **Also found while testing:** on a 390×844 phone, the long bleeding question pushed "Yes" below the visible screen. The answer buttons are now pinned above the 112 banner.
- **Tests:**
  - Backend: `test_sight_based_questions_are_asked_without_needing_sight`, `test_cant_check_is_never_a_yes_and_ibà_sees_false`, `test_cant_check_never_lowers_a_higher_priority`, `test_cant_check_without_iba`.
  - App: `Iba down: built-in questions, labelled honestly, buttons stay on screen`, `a sign you need sight for: worded for a blind user, cannot check`.
- **Emulator check with TalkBack:** we went through all 10 built-in questions with "I can't check" on question 5. The answer buttons were visible on every question. The result was "urgent" (`triage source=fallback reason=not_configured priority=urgent`, with no answers logged) and showed the could-not-check note. An earlier automated run left the quick check at about question 6 without an error; the step-by-step rerun completed, and we didn't find the cause (possibly our tap automation).
- **Status:** fixed in Magana. The wording, the translations and the "can't check → faster call-back" rule are drafts pending Dr. Amos's sign-off, and the translations need native speakers. Ibà's own wording (iba-natlas) still assumes sight. Not yet tried by a blind user.

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
- **What we changed:** the test helper waits 2.5 s between locating a control and touching it, and speech checks avoid polling. The helpers are committed in `tools/talkback/`.
- **Also measured later the same day:** a script that dumped the screen between TalkBack swipes, to look for a control below the fold, never reached it. It ran for more than 10 minutes until we stopped it, because each dump resets TalkBack focus. `scroll_to()` now focuses the lowest item in the scrolling area and swipes 3 times between dumps; with it, the quick-check walk-through reached the button.
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
- **Status:** fixed for the rendered cases. A real photographed label is still open: see "Words around the dose garbled on a photographed label".

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
