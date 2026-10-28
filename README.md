# Magana

Voice-first AI companion that lets blind and low-vision Nigerians read anything printed — schoolwork, medical reports, bank statements — in English, Hausa, Yorùbá or Igbo. Entry for the Nigeria AI Collective / DSN **AI for Visual Impairment Hackathon** (Inclusive Education and Learning track).

Team: Jemiri Daniel Taiwo (AI/ML and full-stack), Dr. Oluba Amos (clinical pharmacist, safety review), Oluremi O. Balogun (RN/RM/RPHN, user research and safeguarding).

## What is in this repo

| Folder | What it is |
| --- | --- |
| `backend/` | The API (FastAPI, Python): OCR, the safety layer, accounts, quizzes, WhatsApp. |
| `app/` | The Android and iPhone app (Flutter), TalkBack-first, with offline reading on the phone. |
| `portal/` | The teacher portal (Next.js), served at teachers.magana.ng. |
| `website/` | The public website (Next.js, static), served at magana.ng. |
| `deploy/` | The test-phase server: Caddy, the server's Dockerfile, the pull-based deploy. |
| `content/` | Phrase templates, number words and word lists. |
| `docs/` | How it works and what we measured. Start with [ARCHITECTURE](docs/ARCHITECTURE.md), [FINDINGS](docs/FINDINGS.md) and the [accessibility note](docs/ACCESSIBILITY_NOTE.md). |

## Build and test it yourself

Nothing below needs a secret. Every part runs on your own computer against a local backend. Only publishing (the signed APK, the deploys) needs the team's keys.

### Prerequisites

| Tool | Version | Needed for |
| --- | --- | --- |
| Python | 3.11 or 3.12 (the server image uses 3.12) | backend |
| Tesseract OCR | 5.x (`brew install tesseract` or `apt install tesseract-ocr`) | backend |
| Flutter | **3.47.7** (pinned in `.github/workflows/ci.yml`) | app |
| Android SDK | from Android Studio | building an APK |
| Node.js | **22** (pinned in CI), with npm | portal, website |
| Google Chrome | any recent | the website's accessibility tests |
| Docker | optional | the backend tests exactly as CI runs them |

### Run each part

```bash
# Backend: the API on http://localhost:8000 (interactive docs at /docs)
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
MAGANA_ENV=development .venv/bin/uvicorn app.main:app --reload

# Try it: read a test photo of a medicine label
curl -F file=@tests/fixtures/misreads/dose_faint.png -F mode=school \
     -H "X-Magana-Tier: standard" http://localhost:8000/read

# App: on a running Android emulator (it talks to http://10.0.2.2:8000, the host's backend)
cd app && flutter pub get && flutter run

# Or backend and app together, with a local dev key made for you (macOS):
scripts/dev.sh            # emulator if there is one, else Chrome

# Teacher portal: http://localhost:3000 (sample data, no backend needed)
cd portal && npm ci && npm run dev

# Website: http://localhost:3000
cd website && npm ci && npm run dev
```

Notes:
- Without `MAGANA_API_KEY` set, the local backend needs no key. Without `DATABASE_URL`, it uses a SQLite file in `backend/data/` (git-ignored). Without `IBA_API_URL`, the quick check uses the built-in danger-sign rules (`backend/app/triage.py`).
- `docker compose up --build` runs the backend next to the Ibà triage service, but only if the iba-natlas repo is checked out next to this one.

### Run the tests (as CI does)

CI (`.github/workflows/ci.yml`) runs four jobs on every push. The same commands work locally:

```bash
# Backend, in the server-like image (Tesseract 5.5.0, as in CI)
docker build -q -t magana-backend backend
docker run --rm --user root -v "$PWD:/m" -w /m/backend magana-backend python -m pytest -q -p no:cacheprovider

# Backend without Docker (your own Tesseract; a few OCR tests skip or read differently by version)
cd backend && .venv/bin/python -m pytest -q

# Backend on Postgres too: point the tests at an empty database
MAGANA_TEST_DATABASE_URL=postgresql://postgres:magana@127.0.0.1:5432/postgres .venv/bin/python -m pytest -q

# App
cd app && flutter pub get && flutter analyze && flutter test

# Portal
cd portal && npm ci && npm run lint

# Website: lint, build, then axe (WCAG 2.2 A/AA and 7:1 contrast) and 64 px checks in Chrome
cd website && npm ci && npm run lint && npx next build && npx playwright test --reporter=line
```

Checked on a Mac on 28 Oct 2026 (Python 3.11.9, Tesseract 5.5.3, Flutter 3.47.7, Node 22.14), without Docker: backend 712 passed, 2 skipped; `flutter analyze` no issues; `flutter test` 343 passed; portal lint and `next build` passed; website lint, build and 20 Playwright checks passed; `flutter build apk --debug` built.

### Get a test APK

- **The published one:** open https://magana.ng/download/android on an Android phone. It redirects to the newest GitHub Release (`magana.apk`, see [Releases](https://github.com/jemiridaniel/magana/releases)). Install steps: https://magana.ng/android/.
- **Build your own (no secrets):** `cd app && flutter build apk --debug`. It talks to `http://10.0.2.2:8000`, the backend on the computer running the emulator. Add `--dart-define=MAGANA_API=http://<your computer's address>:8000` for a phone on the same network.
- **The team's signed tester build:** `scripts/build-apk.sh`, then `scripts/publish-apk.sh`. These need the upload keystore (`app/android/key.properties`) and `~/.magana/app.env` (the server address and app key), which are not in the repo. `build-apk.sh` makes one APK per CPU type (`--split-per-abi`).

## Build plan (to 10 Dec 2026)

| When | Goal |
| --- | --- |
| Now – 12 Nov | Application in. Backend core (done). Recruit blind/low-vision tester. Collect ~100 benchmark pages. Test N-ATLAS + MMS-TTS quality. |
| 13 – 26 Nov | Flutter app shell (TalkBack-first): Home, Capture, Reader. PaddleOCR tables + maths. Confidence warnings spoken. |
| 27 Nov – 3 Dec | N-ATLAS explanations (Hausa, Yorùbá) behind the safety guard. Voice quiz. Everyday papers (medicine label, bank statement). First tester session. |
| 4 – 8 Dec | Teacher portal (uploads → audio/BRF, attendance). Skills lessons. Independence Score. Second tester session. |
| 9 – 10 Dec | Benchmark run, documentation, accessibility note, 5-minute demo video, submit. |

Stretch: WhatsApp channel, Igbo explanations, Champion booking.

## Safety rules (non-negotiable)

- Numbers, doses, amounts and dates are read exactly as printed; generated text that changes them is rejected.
- Unclear text is announced, never guessed.
- No diagnosis, no financial advice; human handoff for health questions.
- Photos are processed in memory and not stored; Magana never asks for a PIN or password.
- Under-18 accounts only with guardian consent; no health, money, WhatsApp or open chat.

The full rules are in [CLAUDE.md](CLAUDE.md); how they are built is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
