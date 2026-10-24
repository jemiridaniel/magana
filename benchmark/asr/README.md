# ASR benchmark (NCAIR1 Whisper models)

Word error rate (WER) of NCAIR1/Hausa-ASR, Yoruba-ASR, Igbo-ASR and NigerianAccentedEnglish
(`backend/app/asr.py`, `ASR_ENGINE=local`) on short read-speech clips, clean and with added
white noise at 10 dB and 5 dB signal-to-noise ratio.

**Test audio:** the first 10 test utterances per language of **FLEURS** (Conneau et al., 2022,
`google/fleurs`, **CC BY 4.0**), streamed by `asr_bench.py` and cached outside the repo in
`~/.cache/magana-bench/fleurs`. FLEURS has no Nigerian-accented English, so English uses `en_us`.
These are read sentences recorded by native speakers, not learners' answers in a classroom: our own
recordings of quiz answers and commands, with consent, are still to do (docs/FINDINGS.md).

WER is reported on FLEURS's normalised transcription and, for Hausa, Yorùbá and Igbo, also with
tone marks and under-dots removed. Every transcript is saved in `transcripts_for_review.csv` for
native speakers. Results are **unreviewed** until they check them.

```bash
HF_TOKEN=... backend/.venv/bin/python benchmark/asr/asr_bench.py --langs ha,yo,ig,en --clips 10 \
  --out benchmark/asr/results/<run> --note "<hardware and settings>"
```
Needs `backend/requirements-asr.txt` and a Hugging Face token that accepted the N-ATLaS terms.
