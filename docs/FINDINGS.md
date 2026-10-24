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

## 2026-10-24 · Safety, languages: N-ATLaS explanations in four languages; what the number guard misses (UNREVIEWED)

> **Unreviewed.** These readings of the Hausa, Yorùbá and Igbo outputs are by the developer, not a native speaker. Native speakers must rate `benchmark/explain/results/2026-10-24-q4km-m2pro/ratings_<lang>.csv` (fluency, faithfulness, numbers kept, harmful or advice).

- **What we tested and how:** `benchmark/explain/explain_bench.py`, with the app's prompts and the per-section guard.
  - **Model:** the N-ATLaS base model, QuantFactory Q4_K_M GGUF (SHA-256 checked against Hugging Face), on llama.cpp on the Mac's M2 Pro GPU. Temperature 0.1, repeat penalty 1.12.
  - **Pages:** the 10 team-written test pages, each explained in English, Hausa, Yorùbá and Igbo (40 explanations). No other pages, and nothing sent to Kaggle.
- **Result: the guard's number-change rate** (share of explanations rejected; the app would read the page instead):

  | Language | Rejected | Real number problem | False alarm (number right, written differently) | Median time |
  |---|---|---|---|---|
  | English | 3/10 (30%) | 1 | 2 | 4.2 s |
  | Hausa | 4/10 (40%) | 2 | 2 | 6.2 s |
  | Yorùbá | 4/10 (40%) | 4 | 0 | 6.0 s |
  | Igbo | 3/10 (30%) | 2 | 1 | 6.5 s |

  - **Real problems the guard blocked** (9):
    - **Arithmetic the prompt forbids** (5): rainfall "460 − 280 = 180" (English, Igbo, Yorùbá); fractions "120 × 2/5 = 48" (Hausa, Yorùbá).
    - **Wrong numbers** (3):
      - Hausa rainfall: the June–July difference "is 80 mm (460 − 280)".
      - Yorùbá vaccination card: "from birth to 40 weeks".
      - Igbo school notice: N2,500 became "puku naira abụọ,500".
    - **Wrong months** (1): the Yorùbá bank statement says March and November for October dates, and adds running balances.
  - **False alarms** (5):
    - The model numbered its own list "1. 2. 3." (English school notice, Hausa malaria leaflet, Hausa bank statement).
    - "N45,200" for "N45,200.00" (English bank statement).
    - "October 3" written as "3" (Igbo bank statement).
    
    This corrects the stub-baseline entry below: a rejection does **not** always mean a changed number.
- **What the guard let through (the serious finding).** The guard compares digits only. These accepted explanations appear wrong:
  - **Hausa medicine label:** "1 to 2 tablets every 4 to 6 *hours*" became "kowane **minti** 4 zuwa 6" (every 4 to 6 **minutes**). "Store below 30 degrees C" became "a wuri mai zafi na digiri 30" (in a **hot** place of 30 degrees). Every digit matches, so it passed. Spoken to a patient, this is a dosing error.
  - **Igbo fractions:** the 120-litre tank became "lita iri abụọ" (**20 litres**, in words).
  - **Yorùbá medicine label:** "over 12 years" became "ogbon odun mejila", which mixes thirty (ọgbọ̀n) and twelve.
  - **Yorùbá school notice:** "second term examinations" became "ayẹyẹ keji" (second **celebrations**).
  - **Igbo malaria leaflet:** it starts "Igbo:", and the Igbo school notice echoed "</page>" (it was rejected anyway).
  - **English:** all 7 accepted explanations read as faithful, and their number words match the page.
- **What this means:**
  - In Hausa, Yorùbá and Igbo, **numbers written as words and changed units** ("minti" for hours, "hot" for "below") **pass the guard**. Rule 1 ("numbers, doses … read verbatim") is not yet fully enforced for model explanations in those languages.
  - Explain is already off outside development (no approved host), so no user can hear this today.
  - This decides the next step before the LoRA question:
    1. A guard for number words and dose units in each language, or a rule that explanations of health and money pages keep doses and amounts as the page's exact words. Native speakers would help write the word lists.
    2. A Magana LoRA trained to copy numbers, units and dates verbatim and never calculate, measured on this same benchmark.
- **What we changed:** nothing in the app or guard yet; this is the measurement.
- **Status:** **open, safety**. Explain must stay off for users until number words and units are checked, and that decision needs Dr. Amos's sign-off for health pages. Results unreviewed until native speakers rate them.

## 2026-10-24 · Languages: ASR word error rate in four languages, clean and noisy (UNREVIEWED)

> **Unreviewed.** Native speakers of Hausa, Yorùbá and Igbo have not yet checked the transcripts (`benchmark/asr/results/2026-10-24-cpu-m2pro/transcripts_for_review.csv`).

- **What we tested and how:** `benchmark/asr/asr_bench.py`.
  - **Models:** the NCAIR1 Whisper Small models that Magana's server uses (`ASR_ENGINE=local`): Hausa-ASR, Yoruba-ASR, Igbo-ASR and NigerianAccentedEnglish. transformers fp32 on the Mac's M2 Pro CPU.
  - **Audio:** the first 10 test clips per language of FLEURS (CC BY 4.0). These are read sentences of 10 to 15 s; English is `en_us`, because FLEURS has no Nigerian English.
  - **Noise:** each clip clean and with white noise at 10 dB and 5 dB SNR.
- **Result** (word error rate, lower is better; in brackets, without tone marks and under-dots):

  | Language | Clean | 10 dB | 5 dB | Median time per clip |
  |---|---|---|---|---|
  | Hausa | 29.1% | 56.3% | 66.5% | 3.4 s |
  | Yorùbá | 56.6% (35.8%) | 70.1% (47.4%) | 102.8% (74.1%) | 8.3–10.3 s |
  | Igbo | 41.3% (34.6%) | 114.5% (111.2%) | 147.6% (145.7%) | 6.6–8.5 s |
  | English (US) | 8.5% | 23.2% | 28.4% | 1.7–1.9 s |

  - **Above 100%** means more wrong words than the clip had. The model **looped**, repeating a word or phrase ("ụlọ ụlọ ụlọ …", 113 to 130 words for a 20 to 44-word sentence).
    - 5 of the 120 transcripts looped: 4 Igbo (10 dB and 5 dB) and 1 Yorùbá (5 dB). Without the loops, Igbo at 5 dB is 56%, from only 8 clips.
    - Whisper has no Igbo language token, so Igbo isn't forced to a language, which may contribute.
  - **Yorùbá:** most of the gap between the two figures is tone marks. The model often writes under-dots as a vertical line ("o̩"), which we now count as equal to "ọ". That changed clean WER from 60.6% to 56.6%.
  - **Speed:** the times are for 10 to 15 s clips on the Mac's CPU. Answers of a few seconds have not been timed.
- **What this means:** free speech in Hausa, Yorùbá and Igbo will often be misheard, especially with noise, as in a classroom or market. This supports the quiz's confirm-before-marking design and the tap fallback (entry "quiz answers that survive bad recognition"). Short answers ("B", "bẹ́ẹ̀ni") are not measured yet and may do better or worse.
- **What we changed:**
  - `asr.looped` (6 tests) turns a looping transcript into "heard nothing". The app asks again, then offers tapping. On these 120 clips it caught all 5 loops and nothing else.
  - The benchmark counts "o̩" and "ọ" as the same letter, and `--resummarize` re-scores a run from its saved text.
- **Status:** **unreviewed**. Still to do:
  - native speakers check the transcripts;
  - record our own quiz answers and commands (with consent) in quiet and noisy rooms;
  - measure on the AWS server's CPU.

## 2026-10-24 · Security: rate limits for the public web API key

- **What we tested and how:** `test_ratelimit.py` (8 tests):
  - per-IP and per-device limits;
  - stricter limits on `/read`, `/asr` and `/explain`;
  - `429 too_many_requests` with `Retry-After`;
  - a refused request doesn't use up the other buckets;
  - `/health` is never limited;
  - a malformed device ID falls back to the IP limit.
  
  `web_test.dart` checks that every app request carries `X-Magana-Device` and that a 429 is spoken in the user's language. By hand, through a local Caddy with the production Caddyfile: 125 calls from one IP in under a minute gave 121 × 200 and 4 × 429.
- **Why:** the web build's API key is in its JavaScript, so anyone can copy it.
- **Result:** the limits work, including behind Caddy. The backend only listens inside Docker, and Caddy replaces any `X-Forwarded-For` a client sends, so the IP can't be faked.
- **What we changed:** `backend/app/ratelimit.py`, its middleware in `main.py`, the `too_many_requests` message in four languages, and the settings in docs/DEPLOY_AWS.md §10a.
- **Status:** fixed in tests.
  - **Open:** the limits live in memory, so they reset on restart. They also don't protect against many IPs at once.
  - **Untested:** the right limit for a school class sharing one router.

## 2026-10-24 · Accessibility: the web app (PWA) with screen readers

- **What we tested and how:**
  - **WebKit and Chrome** (Playwright on the Mac), release build served under `/app/`. We read the accessibility tree at first load, before any interaction.
  - **iOS Safari**, iPhone 17 Simulator, iOS 26.4. We opened the PWA and took screenshots.
- **Why:** Flutter web normally builds its screen-reader tree only after the user finds a hidden "Enable accessibility" button. A blind user can't be expected to find it. Magana now calls `SemanticsBinding.instance.ensureSemantics()` at startup on web.
- **Result:**
  - In WebKit and Chrome, the tree is there at first load, with no placeholder button. Language choice reads as the heading "Choose your language", then buttons English, Hausa, Yorùbá, Igbo and Continue.
  - In the iOS Simulator, the PWA loads past the splash screen and the Hausa, Yorùbá and Igbo letters render correctly.
- **Could not test:**
  - **VoiceOver on iOS.** The Simulator has no VoiceOver.
  - **VoiceOver on the Mac with Safari.** It would take over the developer's own Mac, so we didn't turn it on without asking.
  - **TalkBack with Chrome on Android.**
  - **"Add to Home Screen"** on a real iPhone.
  
  The accessibility tree shows the right names and roles, but nobody has yet heard a screen reader speak them.
- **What we changed:** `main.dart` (forced semantics on web).
- **Status:** open until it has been tried with VoiceOver on a real iPhone and TalkBack on Android Chrome.

## 2026-10-24 · Accessibility: the web build never got past the splash screen (fixed)

- **What we tested and how:** the release web build in WebKit, headless and headed Chrome, and iOS Safari (Simulator). We also built an older commit (476bb70) to see whether this was new.
- **Result:** every browser stayed on the splash screen, including the older commit, so **the web build had never worked**. The app had finished starting up, but the splash waited for `waitUntilFirstFrameRasterized`, which never completes on web.
- **What we changed:** on web, the splash waits for `SchedulerBinding.instance.endOfFrame` instead (`splash.dart`). Phones are unchanged.
- **Status:** fixed. Checked in WebKit, Chrome and iOS Safari (Simulator).

## 2026-10-24 · Accessibility: the web app offline, and when the server can't be reached

- **What we tested and how:** the release build with Magana's own service worker (`magana_sw.js`), in Chrome via Playwright. We loaded it online, then reloaded with the network off and pressed buttons that call the server.
- **Result:**
  - **First load online:** about 1.4 to 1.7 s on the Mac.
  - **Offline reload:** the screens load in about **0.95 s**.
  - **A server call offline:** the app shows and **speaks** "I couldn't reach Magana. Check the connection and try again."
  - The service worker never caches API answers.
  - The first precache list was **30.1 MB**, because it included every CanvasKit variant. We cut it to **4.2 MB** (33 files); the renderer the browser actually uses is cached the first time it loads.
- **Found while testing:** in the health worker quick check, a server that couldn't be reached was **shown but not spoken**. It is now spoken too (test `server unreachable: the quick check says so out loud`).
- **Could not test:** going offline in WebKit/Safari. Playwright's WebKit fails with an internal error when a service worker page reloads offline.
- **Also on web:**
  - Reminders say "Reminders need the Android or iPhone app" (`web_test.dart`).
  - Under-18 accounts never use the browser's speech recognition. The order is our server ASR, then tapping.
  - Explain follows the same approved-host rule as the app.
- **Status:** fixed in Chrome. Untested: offline in Safari, and on a real iPhone or Android phone.

## 2026-10-24 · Accessibility, languages: quiz answers that survive bad recognition

- **What we tested and how:**
  - `quiz_test.dart` unit tests: Yorùbá, Hausa and Igbo letter variants ("bí", "dí", "sí", "à" become B, D, C, A), and true/false in four languages ("bẹ́ẹ̀ni", "rárá", "i", "a'a", "ee", "mba").
  - `quiz_test.dart` widget tests:
    - `spoken answer: confirmed first, then marked right`;
    - `a misheard answer is never marked wrong`;
    - `wrong answer, confirmed by tapping Yes: says the right one`;
    - `unclear, then silent: tap instead; marks nothing`;
    - one test per tier that the recogniser is chosen for that account.
- **Why:** the ASR result for Hausa (see "ASR word error rate in four languages"). On 10 FLEURS clips, NCAIR1/Hausa-ASR got **29.1%** of words wrong clean, **56.3%** with noise at 10 dB SNR, and **66.5%** at 5 dB. At that error rate a spoken answer is often misheard, so a mishearing must never cost the learner a mark.
- **Result:**
  - A spoken answer is only marked after "You said B. Is that right?" and a yes, spoken or tapped.
  - A "no", or a misheard letter that is rejected, leaves the score unchanged ("0 right out of 0 answered") and asks again.
  - After two failed tries the app says "Please double tap your answer instead."
  - Tapping an option marks it directly, as before.
  - Answers stay short: a letter, true/false, or one word or number from the option.
- **What we changed:** this commit.
- **Status:** fixed in tests. Untested with real learners' voices or with on-device recognisers. The non-English answer words are drafts for native speakers.

## 2026-10-24 · Privacy: speech recognition for children stays off the network

- **What we tested and how:** `voice_input_test.dart`:
  - which recognisers each tier may use;
  - that `SpeechVoiceInput(onDevice: true)` refuses when the phone has no real on-device recogniser;
  - the chain's fallbacks;
  - in `quiz_test.dart`, that the quiz asks for a recogniser for the account's own tier.
- **Found while building it:** asking `speech_to_text` for on-device recognition doesn't guarantee it. On Android below 12, or without an on-device model, it **silently uses the normal recogniser**, which can send audio to Google. Magana now asks Android directly (`SpeechRecognizer.isOnDeviceRecognitionAvailable`, through `MainActivity`) before using it.
- **Result:**
  - The order is on-device recognition, then Magana's server ASR, then (18+ only) the phone's network recogniser, then tapping.
  - Guided and Classroom accounts have no network-recogniser step at all. If on-device and server both fail, `listen` raises and the screen asks them to tap.
  - "Heard nothing" doesn't move on to the next recogniser. A step that fails isn't retried in the same session.
- **What we changed:** this commit. docs/PRIVACY.md, "Speech recognition", is marked for Nurse Balogun's review.
- **Status:** fixed in tests. Untested on phones: which models have on-device recognition, and for which languages. Hausa, Yorùbá and Igbo are unlikely to have on-device models, so those learners will mostly use the server, which is not deployed yet.

## 2026-10-24 · Privacy: private papers never go to an unapproved Explain host

- **What we tested and how:** `test_explain.py`:
  - `test_outside_development_the_preview_is_off`, for tester, production, unset and an unknown value;
  - `test_a_kaggle_tunnel_never_gets_page_text_in_a_tester_build`;
  - `test_a_tester_build_never_sends_page_text_to_an_unapproved_host`: the real vLLM engine pointed at a `*.trycloudflare.com` URL, with every HTTP request recorded;
  - `test_an_approved_host_is_used`, `test_kaggle_is_allowed_in_development`;
  - `test_approved_hosts_match_docs_models_md`.

  App test: `tester build without an approved host: not available, page read`.
- **Result:**
  - With `MAGANA_ENV` tester, production, unset or unknown, and no approved host (none is approved yet), `/explain` made **0 HTTP requests**. It answered `explain_not_available` with the page text, and the app said "Explain isn't available yet" and read the page.
  - In development, Kaggle is allowed, for the team's own test pages only.
  - We checked the tests can fail: with the deployment rule removed, 5 fail.
- **What we changed:** this commit.
- **Status:** fixed. The approved-host list in docs/MODELS.md and in code are kept the same by a test.

## 2026-10-24 · Safety: the per-number re-read now runs for every OCR engine

- **What we tested and how:** `test_number_reread.py`, 9 tests, on the Mac:
  - `test_every_engine_in_the_reader_is_covered_here` fails if a new OCR engine is added without being tested.
  - For Tesseract and PaddleOCR: every number on a rendered label must be re-read from a crop (`test_every_number_is_reread_from_a_crop`), and the start-up self-test must pass.
  - An engine with no word boxes must be refused, and the server must refuse to start with it.

  PaddleOCR isn't installed here, so its engine ran on a stand-in pipeline that returns PP-OCR-style line boxes (no word boxes), located by Tesseract on the same image.
- **Result:**
  - Before the fix, the PaddleOCR cases failed: 2 of 9 tests (we restored the old code to check).
  - After it, all 9 pass. On the label, all 6 numbers (500, 2, 4, 6, 8, 24) got a second reading in both modes, and the readings agreed.
- **What we changed:**
  - PaddleOCR's words get approximate boxes: the line box split by characters.
  - Engines without their own single-line reader are re-read by Tesseract, which is always installed and is an independent second reader.
  - New start-up self-test (`reader.check_number_reread`): before taking requests, the server reads a rendered dose line with the chosen engine. If any number wasn't re-read, it **refuses to start**. So `OCR_ENGINE=paddle`, or any future engine, can't run without the check.
- **Status:** fixed. Untested with real PaddleOCR (its line boxes on real photos, memory on 4 GiB); measure on the server before real users.

## 2026-10-24 · Safety: N-ATLaS engines behind the number guard, and its false-alarm baseline

- **What we tested and how:**
  - `test_explain.py`, 16 tests: the engines' exact requests, sections, the per-section guard, the 20 s deadline, injection attempts and the Guided prompt.
  - The explanation benchmark (`benchmark/explain/`) run with the **stub** engine, which returns each page unchanged, on the 10 team-written pages in English, Hausa, Yorùbá and Igbo, on the Mac.
- **Result:**
  - **Baseline: the guard rejected 0 of 40 unchanged pages.** The pages are packed with doses ("1 to 2 tablets every 4 to 6 hours"), amounts ("N186,750.00", "N13,636.59"), dates, "7.5%", "4,698 kWh" and a fraction. So any rejection in a real model run means the model added or changed a number, not that the guard misfired. *(Corrected by the N-ATLaS run above: 5 of 14 rejections were numbers written differently, e.g. list numbers "1. 2. 3." the model added.)*
  - **Engine requests:**
    - vLLM gets the card's settings (temperature 0.1, repetition_penalty 1.12) and `chat_template_kwargs.date_string`. `EXPLAIN_MODEL` picks the base model or a LoRA adapter served with `--enable-lora`.
    - For llama.cpp, Magana renders N-ATLaS's Llama 3.1 template itself.
  - **Long pages and the deadline:** long pages go in sections of at most 6,000 characters, within the card's 8,092-token context. An answer that uses a number from another section is rejected. The whole explanation has one 20 s deadline, and a slow or down model means the page is read instead.
  - **Page text is data:** control tokens such as `<|eot_id|>` are stripped from page text, and a page can't close its own `<page>` fence.
- **What we changed:** this commit.
- **Status:** the engines are tested with fakes only. N-ATLaS's real number-change rate and quality per language are measured in a later entry.

## 2026-10-24 · Release build: signed APK size, and the API key

- **What we tested and how:**
  - `flutter build apk --release --split-per-abi`, through `scripts/build-apk.sh`, on the Mac, pointed at a placeholder server. This was a verification build, not for testers.
  - The same build without `android/key.properties`.
  - Backend tests in `test_api_key.py`.
- **Result:**
  - Release APKs, version 0.1.0 (build 1):

    | APK | Size |
    |---|---|
    | arm64-v8a | 21,321,568 bytes (the build tool says 21.3 MB) |
    | armeabi-v7a | 19.0 MB |
    | x86_64 | 22.8 MB |

  - The arm64 APK is signed with the upload key: CN=Magana, O=Magana, C=NG, certificate SHA-256 `84d9da5d8ae21de37d97db79800cafaaa3992374a01e3c76980a72f5b2df92c6`.
  - Without `key.properties`, the release build stopped after 11 s with "No android/key.properties…" instead of signing with the debug key.
  - With `MAGANA_API_KEY` set on the backend, a missing or wrong `X-Magana-Key` gets 401 `bad_api_key`, and the right key gets 200. `/health` and CORS preflights stay open.
- **What we changed:** this commit.
- **Status:** working.
  - Not yet installed on a real phone.
  - The key is built into the app, so it keeps out casual callers, not a determined attacker who unpacks the APK.
  - The deployed-backend entry comes once the server is running.

## 2026-10-24 · Safety, accessibility: "Say the medicine name when locked" (DRAFT)

- **What we tested and how:** `reminders_test.dart`: `say the medicine name when locked: off by default, DRAFT`, plus the existing reminders tests now expecting the private wording.
- **Result:**
  - Off by default. Every notification then shows only "Magana reminder / Open Magana to hear which medicine.", and nothing is spoken.
  - Turned on: every reminder is rescheduled with the medicine and amount as typed. The notification is public, so TalkBack can read it on the lock screen, and an Android alarm speaks "Time for your medicine. Amlodipine 5 mg · 1 tablet" with the phone's voice.
  - Turned off again: everything goes back to the private wording.
  - "Remind in 15 min" follows the same setting.
  - When a spoken alarm fires, it checks again that the setting is on and the reminder still exists, so turning it off or deleting the reminder always wins.
- **What we changed:** this commit.
- **Status:** DRAFT, pending Dr. Amos's sign-off, because people near the phone may see or hear the medicine. Untested on a device:
  - TalkBack reading the public notification on a locked phone;
  - the alarm speaking while the phone is locked;
  - which voice is used when the phone has no Hausa, Yorùbá or Igbo voice (it falls back to English, Nigeria).

## 2026-10-24 · Safety: "Ask a question" could be reached by voice from a Guided account

- **What we tested and how:**
  - The onboarding tests already asserted that the Home tile is hidden for Guided and Classroom accounts: the exact set of tiles per tier.
  - New tests in `learner_test.dart`: `guided: Ask a question is hidden, by tile and by voice` and `classroom: Ask a question is hidden, by tile and by voice`.
- **Result:**
  - The tile needed the open-chat permission (18+), but the spoken command "ask a question" needed only Explain, which Guided learners have. A Guided learner could reach the Ask screen by voice, and "help" read it out to them.
  - Fixed: the command now needs the same permission as the tile. We checked the test fails with the old rule; it showed the Guided learner reaching the Explain screen.
  - Guided learners still have "Explain this" in the Reader, on school pages.
- **What we changed:** this commit.
- **Status:** fixed.

## 2026-10-24 · Accessibility: every app screen has an expectAccessible test

- **What we tested and how:**
  - The older screen-reader test in `app_test.dart` checked Capture and the Reader with its own copy of the tap-action check, but not the 64 px target size. It now uses the shared `expectAccessible`.
  - New test: `5 Reader (table): every control labelled, actionable, 64 px`.
- **Result:**
  - Home, the language sheet, Capture, the Reader and the Reader with a table all pass: every control has a tap action, and every visible button is at least 64×64 px.
  - All 18 app screens on the design canvas now have an `expectAccessible` test (1, 2, 3, 3b, 4, 5, 6, 7, E0–E6, L1–L3). The six portal pages are covered by axe.
- **What we changed:** this commit (tests only).
- **Status:** passed in tests.

## 2026-10-24 · Accessibility: the new app screens with TalkBack on the Emulator

- **What we tested and how:** on the Emulator with TalkBack, using `tools/talkback/`, we walked through Home, Settings, the app-language sheet, Ask a question (Explain without a page) and the Everyday hub. We then ran "Read any paper" on the photographed label `medicine_label.png` from the gallery.
- **Result:**
  - Every control on these screens was announced with its label.
  - Home no longer announces anything as "Coming soon".
  - The language sheet reads each language with its own welcome word ("Hausa. Barka da zuwa", "Yorùbá. Ẹ káàbọ̀", "Igbo. Nnọọ").
  - Settings shows "Version 1.0.0 (build 1)".
  - "Read any paper" identified the real photo as a medicine label: it showed the medicine note, and `/read` returned 200 in the strict letter mode. Line 2's dose stayed "[unclear number]" with its spoken warning.
- **What we changed:** nothing; this is a check of the previous commits.
- **Status:** passed on the Emulator. Not yet tried on a real phone or by a blind user. Voice commands, spoken answers and Explain questions are untested with real speech, because the Emulator has no microphone input.

## 2026-10-24 · Portal: My classes, Learner progress, Consent records and Help built

- **What we tested and how:** Chrome with Playwright and axe-core (wcag2a/aa, 21a/aa, 22aa, best-practice) at 1280×900 and 390×844 on all six portal pages. The script used every control on the four new pages and did a keyboard Tab walk on every page. Also `npm run lint` and `npm run build`.
- **Result:**
  - axe: 0 violations on all six pages at both sizes.
  - Page sideways scroll: 0 px in all 12 page/width combinations.
  - Smallest tap target: 64 px.
  - At 390 px, tables scroll inside their own focusable region: Uploads 219 px, Classes 207 px, Attendance 364 px, Progress 311 px, Consent 217 px.
  - The Progress chart, its "Show as table" view and its text alternative give the same numbers. The SS2 Science sample data averages to the board's 71% (done without sighted help) and 72% (quiz).
- **Bugs found and fixed during the click-through:**
  1. After "View record", focus stayed on the button; it now moves to the record.
  2. Consent at 1280 px squeezed names and cut the learner select off at "Chiamaka Okafor (pen".
  3. A fix for item 2 made the table overflow its scroll area at 1280 px; after the correction, 0 px of sideways scroll with a record open.
  4. An empty gap above the class cards.
  5. Help guides were laid out 3+1 instead of 2×2.
  6. On phones, the Progress suggestion pill wrapped into a very narrow column; the tallest row is now 85 px.
- **Deliberate differences from the boards:**
  - Learners waiting for guardian consent show no progress, because their accounts are locked.
  - The Progress chart uses HTML and CSS instead of SVG, because SVG text shrank to about 5 px at 390 px.
  - "Works with NVDA, JAWS" became "designed for screen readers such as NVDA and JAWS", because that hasn't been tested.
  - The support contact details are marked "to be added", not invented.
- **What we changed:** this commit.
- **Status:**
  - New classes, invites, reminders, consent requests and problem reports stay on the page only, and every one says nothing was sent. Each needs a server endpoint.
  - The guide steps, guardian names and consent dates are sample text.
  - NVDA and JAWS are untested.

## 2026-10-24 · Accessibility: the app and portal compared with every design board

- **What we tested and how:** each of the 24 screens on the design canvas (18 app, 6 portal) compared with the app and portal code, before and after this round of building. (Corrected from 25.)
- **Result before this round:**
  - Built and matching: 1 Choose language, 2 Age check, 4 Capture, 7 Voice quiz, E4 Reminders, E5 Talk to a health worker, L1 Skills, Uploads, Attendance.
  - Built but different: 3 Home (Settings, Ask a question and Hold to speak were "coming soon"), 3b Change app language, 5 Reader, E0, E1, E2, E3, E6, L2, L3.
  - Placeholder: 6 Explain (app), My classes, Learner progress, Consent records, Help (portal).
- **After this round:** every screen is built. What still differs, and why:
  - **Not built, by choice:**
    - Learner names in the Home greeting: there are no accounts.
    - "Use Magana on WhatsApp" on the age check: WhatsApp isn't built.
    - E1's separate label fields: that would mean guessing what each line is.
    - L2's Call and Book training: there's no Champion programme yet.
  - **Behaves differently:**
    - "Hold to speak" became tap to speak, because a hold is awkward with TalkBack.
    - Reminders are a phone notification; they are not spoken on a locked phone.
    - L1 has 3 sample lessons instead of 5 tracks.
  - **Waiting on other work:**
    - Explain is a preview until N-ATLAS is hosted.
    - Jumping to headings and diagrams needs layout data from the backend.
- **Status:** the tests for each screen use `expectAccessible` (app) or axe (portal). A TalkBack check on a device for the new app screens is listed separately.

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

## 2026-10-24 · Safety: in PaddleOCR mode, numbers were not re-read from crops (fixed, see above)

- **What we tested and how:** reading the code while preparing the production deploy: `reader.reread_numbers` and `PaddleStructureEngine`.
- **Result:** `reread_numbers` only re-read words with a box, and PaddleOCR's words had none (PP-OCR boxes whole lines). So with `MAGANA_OCR=paddle` the crop re-read silently did nothing. That is the check that caught the "6" read at 92%. Numbers fell back to the 0.90 rule, plus the whole-page second pass in health and money modes.
- **Status:** fixed in "the per-number re-read now runs for every OCR engine" above.

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
