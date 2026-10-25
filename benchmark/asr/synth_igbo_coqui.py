"""Igbo quiz-answer clips from the CC BY-SA 4.0 VITS OpenBible Igbo voice (Coqui TTS).

MMS-TTS has no Igbo voice. Run with a Python that has coqui-tts installed (kept apart
from the backend's packages); answers_bench.py calls it:
  <coqui python> synth_igbo_coqui.py <model dir> <out dir> '<json list of [intended, said]>'
Writes <out dir>/coqui-ig-<speaker>x<speed>-<intended>.npy at 16 kHz.
"""
import json
import sys
from pathlib import Path

import numpy as np
from TTS.api import TTS

model_dir, out_dir, answers = Path(sys.argv[1]), Path(sys.argv[2]), json.loads(sys.argv[3])
tts = TTS(model_path=str(model_dir / "model_last.pth"), config_path=str(model_dir / "config.json"))
speakers = (tts.speakers or [None])[:3]
# One speaker only: vary the speaking rate as for MMS (0.85, 1.0, 1.2 times).
SPEEDS = (0.85, 1.0, 1.2)
rate = tts.synthesizer.output_sample_rate
out_dir.mkdir(parents=True, exist_ok=True)
for speaker in speakers:
  for speed in SPEEDS:
    tts.synthesizer.tts_model.length_scale = 1 / speed
    for intended, said in answers:
        wav = np.asarray(tts.tts(text=said, speaker=speaker), dtype=np.float32)
        t = np.arange(0, len(wav) / rate, 1 / 16000)
        wav16 = np.interp(t, np.arange(len(wav)) / rate, wav).astype(np.float32)
        np.save(out_dir / f"coqui-ig-{speaker or 'one'}x{speed}-{intended}.npy", wav16)
print(json.dumps({"speakers": speakers, "rate": rate}))
