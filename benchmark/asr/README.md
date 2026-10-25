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

Yorùbá under-dots written with a vertical line (U+0329, "o̩", as the model often does) and with a
dot (U+0323, "ọ", as FLEURS does) count as the same letter. **Runaway clips** are those where the
model repeated itself and gave more than twice as many words as the reference.

```bash
HF_TOKEN=... backend/.venv/bin/python benchmark/asr/asr_bench.py --langs ha,yo,ig,en --clips 10 \
  --out benchmark/asr/results/<run> --note "<hardware and settings>"
```
Add `--resummarize` to re-score a finished run from its `outputs.jsonl` without the models.
Needs `backend/requirements-asr.txt` and a Hugging Face token that accepted the N-ATLaS terms.

## Quiz answers: is the right answer understood?

`answers_bench.py` measures what matters for the quiz: whether "A, B, C, D, yes, no, true,
false" (Yorùbá "à, bí, sí, dí"…) is taken for the answer the learner meant. It scores the
app's own rules (`app/test_tool/score_answers_test.dart`), not word error rate.

- **Clips:** synthetic, until we have consented recordings. English, Hausa and Yorùbá come
  from MMS-TTS (CC BY-NC 4.0) at three speaking rates; English also from four macOS voices;
  Igbo from the VITS OpenBible Igbo voice (CC BY-SA 4.0) through Coqui TTS in its own
  environment (`synth_igbo_coqui.py`). Each clip is tested clean and at 10 dB and 5 dB SNR.
- **Outcomes:** right, wrong (the app would then ask "You said C. Is that right?"), or
  unclear (asked again). Looping transcripts count as heard nothing, as on the server.

```bash
COQUI_PYTHON=<python with coqui-tts> HF_TOKEN=... backend/.venv/bin/python benchmark/asr/answers_bench.py \
  --langs en,ha,yo,ig --out benchmark/asr/results/<run>
backend/.venv/bin/python benchmark/asr/answers_bench.py --rescore --out benchmark/asr/results/<run>
```
