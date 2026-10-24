# Magana

Voice-first AI companion that lets blind and low-vision Nigerians read anything printed — schoolwork, medical reports, bank statements — in English, Hausa, Yorùbá or Igbo. Entry for the Nigeria AI Collective / DSN **AI for Visual Impairment Hackathon** (Inclusive Education and Learning track).

Team: Jemiri Daniel Taiwo (AI/ML and full-stack), Dr. Oluba Amos (clinical pharmacist, safety review), Oluremi O. Balogun (RN/RM/RPHN, user research and safeguarding).

## What is in this repo now

`backend/` — FastAPI service (hackathon MVP core)

| Module | What it does |
| --- | --- |
| `app/reader.py` | OCR into lines and tables (rows of cells, each with confidence) + capture check (too dark / blurry). Tesseract for dev; `MAGANA_OCR=paddle` uses PaddleOCR PP-StructureV3 for layout and tables (`pip install -r requirements-paddle.txt`). |
| `app/safety.py` | Verbatim-number guard (rejects explanations that invent doses, amounts, dates) and low-confidence spoken warnings, for lines and for table cells ("row 2, column 3 of table 1"). |
| `app/policy.py` | Age tiers: Standard 18+, Guided 13–17 (guardian consent, curriculum only), Classroom under 13. |
| `app/triage.py` | Ibà quick check: sets nurse call-back priority, danger signs → clinic / 112. Draft rules — clinical sign-off required. |
| `app/main.py` | `/read`, `/explain/check`, `/triage/questions`, `/triage/assess`, `/health`. |

Run it:

```bash
cd backend
pip install -r requirements.txt   # needs tesseract-ocr installed
pytest -q
uvicorn app.main:app --reload     # docs at http://localhost:8000/docs
```

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
