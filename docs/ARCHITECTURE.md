# Architecture

How Magana is put together, and how one page gets from a camera to the learner's ears. Hosting details are in [INFRA.md](INFRA.md), deploys in [DEPLOY.md](DEPLOY.md), and measurements in [FINDINGS.md](FINDINGS.md).

## The parts

```
 Phone (Flutter app, TalkBack-first)          Browser
   camera, voice commands, speech out           teachers.magana.ng (portal)   magana.ng (website)
   offline reading: ML Kit / Apple Vision        Cloudflare Pages              Cloudflare Pages
        │                                              │
        └──────────── HTTPS, X-Magana-Key, tier headers ┘
                              │
                 api.magana.ng — Oracle Cloud server, London
                 Caddy (TLS) ──▶ FastAPI container (slot a or b)
                              │   OCR: Tesseract; RapidOCR (WhatsApp amounts)
                              │   safety layer, age-tier checks, rate limits
                              ├──▶ Neon Postgres (London): accounts, classes, quizzes
                              ├──▶ Resend: sign-in codes, invitations
                              └──▶ Ibà triage service (optional; built-in rules if absent)

 GitHub Actions: tests ──▶ git tag "production" ─ ─ ▶ server pulls it every minute
```

| Part | Code | What it does |
| --- | --- | --- |
| App | `app/lib/` | Flutter, Android first (iPhone in testing). Every screen works with TalkBack and by voice (`voice_input.dart`, `commands.dart`). Age tiers hide what a tier can't use (`policy.dart`). |
| Offline reading | `app/lib/offline/offline_reader.dart` | Reads a page on the phone (ML Kit on Android, Apple Vision on iPhone) when the server can't be reached. Same number rules; the photo waits encrypted for a full reading (`photo_queue.dart`). |
| API | `backend/app/main.py` | `/read`, `/read-pdf`, `/explain`, `/triage/*`, accounts, portal and WhatsApp endpoints. Returns message codes, never sentences (`messages.py`); the app words them in the user's language (`app/lib/l10n/`). |
| Server | `deploy/server/` | Caddy for TLS and the caller's address; the API in Docker, read-only. |
| Database | `backend/app/database.py` | Neon Postgres when `DATABASE_URL` is set, SQLite otherwise (dev and tests). Photos and page text are never stored. |
| Email | `backend/app/mailer.py` | Resend, for sign-in codes and invitations. |
| Portal | `portal/` | Next.js. Teachers' classes, consent records, uploads, progress. |
| Website | `website/` | Next.js, static. Information, the APK download, the tester tasks. |

## How a page is read

1. **Capture** (`app/lib/screens/capture.dart`). The app speaks framing cues ("Move closer", "Hold still"), takes the photo when it sees text, turns it upright and shrinks it to at most 1080 px wide.
2. **Send.** The app posts the photo to `/read` with the paper type (`mode`: school, health, money, letters) and its tier headers (`X-Magana-Tier`, plus consent or teacher-session headers). `policy.check_request` refuses what the tier may not use (`backend/app/policy.py`). If the server can't be reached or doesn't answer in time, the phone reads the page itself (`serverWait` in `capture.dart`).
3. **OCR** (`backend/app/reader.py`). Behind the `OCREngine` interface: Tesseract (the server's engine; PaddleOCR is optional for tables). The reader straightens the photo, flattens faint print, skips barcodes, finds two columns and tables, and gives every word a confidence. The photo stays in memory only.
4. **Every number is read twice.** `reader.reread_numbers` reads each number again from a crop around it and its neighbouring words. Health and money pages also get a whole-page second pass (`safety.number_mismatches`). On WhatsApp, money amounts get a second engine, RapidOCR (`second_ocr.py`). In the app, money papers and screenshots are also read on the phone (`app/lib/amount_check.dart`). An amount is said only when both readings agree (`amounts.py`).
5. **Safety checks** (`backend/app/safety.py`):
   - Low-confidence lines get a spoken warning (`confidence_warnings`).
   - Each number is scored on its own (`number_warnings`): below 0.90, or without two agreeing readings each at 0.80 or more, it is said as "unclear number". A digit read as a symbol is never repaired. These thresholds are pending clinical sign-off.
   - Handwriting on a health paper: numbers are never read; the learner is told to ask the pharmacist (`handwritten_health`).
6. **Reading aloud** (`app/lib/screens/reader.dart`). Line by line, tables row by row, Repeat and Next, one summary of the warnings, and "What's unclear?" for the details. The phone's own voice speaks.

## Explanations and translations

- **Health, money and letter papers never go to a model.** Only approved phrase templates are used (`backend/app/templates.py`, `content/templates/`). A line without an approved template is read in English with "I can't translate this line safely…".
- **Schoolwork** can be explained by N-ATLaS, but the model never sees a number. `placeholders.py` replaces every number and unit with a marker. The answer is refused unless each marker appears exactly once and nothing numeric was added; then `safety.guard_explanation` runs too. If anything fails, the page is read instead (`explain.py`).
- **Today:** Explain is off on the test server (`EXPLAIN_ENGINE=stub`), and Hausa, Yorùbá and Igbo explanations wait for native review (FINDINGS, 2026-10-26).

## Health questions

The quick check calls the Ibà service when it is configured (`iba_client.py`). Without it, or if it takes more than 3 s, Magana's own danger-sign rules answer (`triage.py`); a danger sign is always an emergency. Ibà is not run in the test phase. Answers are never logged or stored.

## Deploys

1. Every push runs the tests (`.github/workflows/ci.yml`): backend on SQLite and Postgres, app, portal, website.
2. On main, when all pass, CI moves the git tag `production` to the commit. It holds no key to the server.
3. Every minute the server reads the tag (`deploy/server/magana-deploy`). A new commit is built, started next to the live one, and must answer `/health` with its commit and a working database. Then traffic switches. If it fails, the old one keeps serving.
4. The website, the tester web app and the portal are built in CI and go to Cloudflare Pages. The Android APK goes to GitHub Releases (`scripts/publish-apk.sh`).
