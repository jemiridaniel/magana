# Open text-to-speech for Hausa, Yorùbá, Igbo and Nigerian English: evaluation

28 Oct 2026. Jemiri Daniel Taiwo (run with Claude Code).

**Not shipped: evaluation only.** No app or backend code was changed. Nothing here is in production.

Question: which open TTS model could give Magana voices for Hausa (ha), Yorùbá (yo), Igbo (ig) and Nigerian-accented English?

Short answer:
- **No open model passes on both licence and quality yet.** Native speakers must judge quality before anything is chosen.
- **Commercial use allowed, worth testing with native speakers:** YarnGPT2 (all four languages; Apache 2.0, but it was trained on Nigerian films and podcasts with no stated rights) and the Open Bible VITS voices (ha, yo, ig; CC BY-SA 4.0, Bible-reading style).
- **Non-commercial only:** MMS-TTS (what Magana uses now), OmniVoice, the TWB Hausa voice and most community voices. These are fine for a free pilot but not for a paid service.
- **Speed:** on our ARM server's CPU, only MMS (about real time) and Open Bible VITS (1.2–1.9 × real time) are usable. YarnGPT2 (14–17 ×) and OmniVoice (36–213 ×) are far too slow without a GPU.

## 1. Licences (read before anything was downloaded)

All pages were read on 28 Oct 2026.

| Model | Languages | Licence | Commercial use? | Attribution? | Caps / other limits | Training data | Source read |
|---|---|---|---|---|---|---|---|
| Meta MMS-TTS `facebook/mms-tts-eng`, `-hau`, `-yor` | en, ha, yo | CC BY-NC 4.0 | **No** (NON-COMMERCIAL) | Yes | None besides NC | Bible recordings (MMS paper) | huggingface.co/facebook/mms-tts-hau (card: "licensed as CC-BY-NC 4.0"); same on -yor and -eng |
| MMS-TTS Igbo (`facebook/mms-tts-ibo`, `-ig`) | — | — | — | — | **Does not exist.** The HF API returns "not found" for both names, and the load failed on the server (OSError: not a valid model identifier). docs/MODELS.md is right. | — | huggingface.co/api/models/facebook/mms-tts-ibo |
| YarnGPT2 `saheedniyi/YarnGPT2` (also YarnGPT, YarnGPT2b) | en (Nigerian accent), ha, yo, ig | Apache 2.0 (weights); code MIT (github.com/saheedniyi02/yarngpt README) | Yes, by licence | Apache NOTICE rules | None | "Publicly available Nigerian movies, podcasts (using the subtitle-audio pairs) and open source Nigerian-related audio data". **The rights to the film and podcast audio are not stated: DATA RIGHTS UNCLEAR.** The card also says "for experimental purposes". | huggingface.co/saheedniyi/YarnGPT2 (card) |
| ↳ WavTokenizer decoder (needed by YarnGPT2) | — | MIT | Yes | Yes (MIT notice) | The checkpoint the YarnGPT2 card uses comes from a Google Drive link, not from Hugging Face | — | github.com/jishengpeng/WavTokenizer; huggingface.co/novateur/WavTokenizer-large-speech-75token |
| YarnGPT-local `saheedniyi/YarnGPT-local` | ha, yo, ig | CC BY-NC-SA 4.0 | **No** (NON-COMMERCIAL) | Yes; share-alike | — | "Open source dataset on Yoruba, Igbo and Hausa" | huggingface.co/saheedniyi/YarnGPT-local. Not run: YarnGPT2 covers the same languages under a better licence. |
| VITS Open Bible `multilingual-tts/VITS-OpenBible-Hausa`, `-Yoruba`, `-Igbo` | ha, yo, ig | CC BY-SA 4.0 | Yes | Yes; **share-alike**: changed versions of the model (e.g. fine-tunes) must stay CC BY-SA. Generated audio is probably not a derivative, but we have not had that checked. | None | Biblica Open Bible recordings (open.bible), through the `davidguzmanr/open-bible-resources` dataset. Biblica's audio editions are CC BY-SA 4.0 and need an attribution line to biblica.com and open.bible (seen on Biblica's edition pages). The dataset card itself states no licence. open.bible returned HTTP 403 to us. | huggingface.co/multilingual-tts/VITS-OpenBible-Igbo (and -Hausa, -Yoruba); code: github.com/davidguzmanr/open-bible-models (MIT) |
| F5-TTS Open Bible `multilingual-tts/F5-TTS-OpenBible-Hausa` (and Yoruba, Igbo) | ha, yo, ig | CC BY-SA 4.0 | Yes | Yes; share-alike | Needs reference audio for every voice | Open Bible | huggingface.co/multilingual-tts/F5-TTS-OpenBible-Hausa. **Not run** (time); a candidate for later. |
| OmniVoice `k2-fsa/OmniVoice` | 600+ incl. en, ha, yo, ig, pcm | Code Apache 2.0. **Weights CC BY-NC**: a maintainer (zhu-han) wrote "the CC‑BY‑NC license does not allow any commercial usage" (GitHub issues #258 and #211). The HF card has no licence field. Its audio tokenizer has its own **Boson Higgs Audio 2 Community Licence** (based on Llama 3's; needs an expanded licence above 100,000 annual active users). | **No** (NON-COMMERCIAL) | Yes | 100k-user cap on the tokenizer | Training includes Emilia (non-commercial). Hours per language (docs/languages.md): Hausa 17.75 h, Igbo 13.69 h, Yorùbá 15.66 h, Nigerian Pidgin 11.04 h. | huggingface.co/k2-fsa/OmniVoice; github.com/k2-fsa/OmniVoice (LICENSE, issues #211, #258, #284); audio_tokenizer/LICENSE in the HF repo |
| TWB Voice Hausa `CLEAR-Global/TWB-Voice-Hausa-TTS-1.0` | ha | CC BY-NC 4.0 | **No** (NON-COMMERCIAL) | Yes | — | TWB Voice (female, Kano dialect) + open.bible (2 male). Its own human rating: pronunciation 2.52 / 5. | huggingface.co/CLEAR-Global/TWB-Voice-Hausa-TTS-1.0. Not run. |
| Murya Piper Hausa `adab-tech/murya-piper-hausa-tts` | ha | CC BY-NC-SA 4.0 | **No** (NON-COMMERCIAL) | Yes; share-alike | — | not checked | huggingface.co/adab-tech/murya-piper-hausa-tts. Not run. |
| Piper official voices `rhasspy/piper-voices` | — | MIT (repo) | — | — | **No ha, yo or ig voice.** The listing (last changed 2026-10-20) has 53 language folders, none of them Nigerian. | — | huggingface.co/rhasspy/piper-voices (file tree) |
| Coqui XTTS-v2 `coqui/XTTS-v2` | 17 languages, **none Nigerian** | Coqui Public Model Licence (CPML) | **No** (non-commercial). Coqui has shut down, so a commercial licence can't be bought. | — | — | — | huggingface.co/coqui/XTTS-v2 (license_link coqui.ai/cpml). Ruled out. |
| NCAIR1 / N-ATLaS | — | N-ATLaS Terms of Use v1.0 (docs/MODELS.md: 1,000-active-user cap) | — | — | — | — | **NCAIR1 publishes no TTS model.** Its five models are N-ATLaS (text) and four ASR models (HF org listing). Nothing to test. |
| Community uploads (e.g. `naijaml/f5-tts-yoruba`, `LyngualLabs/YorubaEnglish-CodeSwitching-TTS`: CC BY-NC 4.0; `nexusbert/igbo-mms-tts`, `aybdee/Igbo-SpeechSynthesis`: **no licence stated**; `Ngadou/nigerian_accent_tts_en`: MIT, SpeechT5) | various | as listed | NC ones: no. **Unlicensed ones: LICENCE UNCLEAR, don't use.** | | | Fine-tunes of MMS (NC) inherit NC. | HF API, 28 Oct 2026. Not run. |
| Spitch, Intron and similar | ha, yo, ig, en | Paid commercial APIs, not open models | Paid licence | | | | Not evaluated: out of scope (not open). |

The round-trip check below also used **`facebook/mms-1b-all`** (speech recognition, CC BY-NC 4.0). It was used for evaluation only.

## 2. Measurements on the server

Setup:
- Server: Oracle Ampere A1 (Neoverse-N1, aarch64), Ubuntu 24.04.
- Each run used a throwaway Docker container limited to 1.5 CPUs and 6 GB, at low CPU priority, with production containers left alone.
- Software: PyTorch 2.15.0+cpu, 2 threads, float32.
- Each model and language ran in a fresh process. The short and long texts were each synthesised once, short first.
- Texts were fed as given, with digits and no number-to-words step. "Short" means the first two sentences of each test text.
- Load time is with the model already downloaded, except OmniVoice English (marked).
- "Peak RSS" is the peak memory of the whole Python process.
- RTF = synthesis seconds ÷ audio seconds. Below 1 is faster than real time.

| Model | Lang | Load (s) | RSS after load (MB) | Peak RSS (MB) | Short: synth s / audio s / RTF | Long: synth s / audio s / RTF | Output |
|---|---|---|---|---|---|---|---|
| MMS-TTS | en | 4.24 | 534 | 835 | 2.54 / 2.40 / 1.06 | 6.69 / 6.54 / 1.02 | 16 kHz |
| MMS-TTS | ha | 4.53 | 485 | 828 | 2.72 / 2.59 / 1.05 | 6.65 / 6.50 / 1.02 | 16 kHz |
| MMS-TTS | yo | 4.23 | 518 | 767 | 2.84 / 2.69 / 1.06 | 5.23 / 5.14 / 1.02 | 16 kHz |
| MMS-TTS | ig | — | — | — | no model | no model | — |
| Open Bible VITS | ha | 3.04 | 1,825 | 1,870 | 8.99 / 7.03 / 1.28 | 15.18 / 11.93 / 1.27 | 22.05 kHz |
| Open Bible VITS | yo | 7.64 | 1,824 | 1,864 | 7.93 / 4.22 / 1.88 | 10.69 / 8.11 / 1.32 | 22.05 kHz |
| Open Bible VITS | ig | 3.03 | 1,849 | 1,891 | 7.11 / 5.82 / 1.22 | 12.58 / 10.06 / 1.25 | 22.05 kHz |
| YarnGPT2 (float32) | en | 11.65 | 2,540 | 3,238 | 22.61 / 1.31 / 17.3 | 94.94 / 6.27 / 15.2 | 24 kHz |
| YarnGPT2 (float32) | ha | 11.51 | 2,541 | 3,238 | 25.12 / 1.51 / 16.7 | 66.46 / 4.52 / 14.7 | 24 kHz |
| YarnGPT2 (float32) | yo | 11.73 | 2,532 | 3,229 | 25.93 / 1.51 / 17.2 | 51.60 / 3.47 / 14.9 | 24 kHz |
| YarnGPT2 (float32) | ig | 11.53 | 2,552 | 3,249 | 25.38 / 1.71 / 14.9 | 61.76 / 4.41 / 14.0 | 24 kHz |
| OmniVoice (auto voice, 32 steps) | en | 72.0 (includes first download) | 1,375 | 3,073 | 69.89 / 1.96 / 35.7 | 252.71 / 6.74 / 37.5 | 24 kHz |
| OmniVoice | ha | 5.30 | 1,245 | 2,956 | 84.66 / 1.89 / 44.8 | 215.42 / 4.72 / 45.6 | 24 kHz |
| OmniVoice | yo | 5.27 | 1,245 | 2,954 | 89.28 / 0.42 / 212.6 | 184.30 / 3.38 / 54.5 | 24 kHz |
| OmniVoice | ig | 5.36 | 1,245 | 2,927 | 91.57 / 2.24 / 40.9 | 206.56 / 4.57 / 45.2 | 24 kHz |

Notes on the numbers:
- MMS takes about as long to synthesise as the audio lasts, on 1 or 2 threads (checked with repeated runs). That is slower than we expected for a 36 M-parameter model, but it was the same in every run.
- Open Bible VITS uses about 1.8 GB of memory per language. The download is about 1 GB per language because the checkpoint also contains the optimiser state.

## 3. Rough intelligibility check (not a quality judgement)

Each sample was transcribed with `facebook/mms-1b-all` speech recognition and compared with the input text. CER is the character error rate on lower-cased text with tone marks and dots removed; 0 is a perfect match. English was scored against the text with numbers spelled out.

This is only a pointer. The recogniser makes its own mistakes, especially in Yorùbá and Igbo, and it shares training data with MMS-TTS, which may favour MMS. **Real quality judgement must come from native speakers: Nurse Balogun ("Remi") and others.**

| Model | en short / long | ha short / long | yo short / long | ig short / long |
|---|---|---|---|---|
| MMS-TTS | 0.00 / 0.21 | 0.00 / 0.10 | 0.07 / 0.08 | — |
| Open Bible VITS | — | 0.17 / 0.24 | 0.04 / 0.05 | 0.91 / 0.23 |
| YarnGPT2 | 0.10 / 0.19 | 0.03 / 0.12 | 0.14 / 0.22 | 0.41 / 0.26 |
| OmniVoice | 0.00 / 0.01 | 0.03 / 0.07 | 1.00 / 0.36 | 0.88 / 0.14 |

The full transcripts are in `asr_check.json` in the samples folder. These problems need a native speaker to confirm:
- **Numbers.**
  - YarnGPT2 Hausa long: the last word "uku" (three) is missing from the transcript.
  - YarnGPT2 English: "Share 12" came back as "sheats were f".
  - YarnGPT2 Yorùbá: "méjìlá" (twelve) came back as "méjìya".
  - MMS Yorùbá: "méje" (seven) came back as "méjì" (two) in both samples.
  - MMS English fed raw digits: "Lesson 4 … 12 … 3" came back as "lessen the … shareful … the". This is why `spoken.for_voice` already spells numbers out before MMS (backend/app/tts.py).
- **Broken output.**
  - OmniVoice Yorùbá short is 0.42 s and nothing was recognised.
  - OmniVoice Yorùbá long loses its first sentence.
  - OmniVoice Igbo short and Open Bible Igbo short are mostly not recognised.
  - Open Bible Hausa short is 7 s long for 5 words, so there are probably long pauses.

## 4. Text handling found in the code and vocabularies (checked, not guessed)

- **YarnGPT2 removes all tone marks and special letters before the model sees the text.** Its `process_text` runs uroman and then keeps only a–z. So the Yorùbá test text reaches the model as "a ti ka oju iwe naa ila meje pin osan mejila dogba si agbon meta". Hausa ɓ, ɗ, ƙ, ƴ become b, d, k, y, and Igbo ụ, ị, ọ lose their dots.
  - Numbers are turned into **English** words with `inflect` in every language, so "12" in a Hausa sentence would be read as "twelve".
  - Tone and vowel quality can therefore only be guessed by the model. This is a big risk for Yorùbá, where tone changes meaning.
- **MMS-TTS** keeps Yorùbá tone marks (they are in its vocabulary in NFC form) and Hausa ɓ ɗ ƙ. It drops all punctuation.
  - The English voice knows only the digits 0–6, so a raw "7", "8" or "9" is silently skipped. Magana's `spoken.for_voice` already guards against this.
- **Open Bible VITS** has Yorùbá tones, Hausa hooked letters and Igbo ị ọ ụ ṅ in its vocabulary. Text must be NFC: the separate combining dot below (U+0323) is not in its vocabulary.
  - The cards say "multispeaker", but the checkpoints have no speaker-embedding weights (`use_speaker_embedding: false`). Each language has one voice, and the speaker name has no effect. Coqui refuses to run the Hausa and Igbo models until the extra speaker names are removed (our harness does that).
- **OmniVoice** has an optional `normalize_text` step. For Hausa, Yorùbá and Igbo it falls back to `num2words`. We did not turn it on.

## 5. What failed and why

- **MMS Igbo:** the model doesn't exist.
- **YarnGPT2 as written on its card (`torch_dtype="auto"` → bfloat16):** one short phrase took more than 25 minutes, and we stopped it. PyTorch warned "mkldnn_matmul bf16 path needs a cpu with bf16 support"; the Neoverse-N1 has no bf16 instructions. Every YarnGPT2 number above is float32, which generated about 5.3 tokens a second.
- **Open Bible Hausa and Igbo, first try:** Coqui's "multi-speaker model" error. Fixed in the test harness only (section 4).
- **Not run (time, or licence already rules them out):** F5-TTS Open Bible, YarnGPT-local, TWB Hausa, Murya Piper Hausa, community uploads, XTTS-v2 (no Nigerian languages).
- **OmniVoice voice cloning** (its most stable mode, according to its authors) was not tried, because it needs a reference recording from a consenting speaker. Only "auto voice" was tested.

## 6. Recommendation

1. **Ask native speakers to listen first.** Use the samples page (Section 7) with Nurse Balogun and at least one speaker each of Hausa, Yorùbá and Igbo. Ask about:
   - tone and meaning
   - whether every number word is said right (seven, twelve, three)
   - naturalness and speed
2. **Try with native speakers (commercial use allowed):**
   - **Open Bible VITS** (ha, yo, ig). It is the only commercial-use option that runs near real time on our CPU (RTF 1.2–1.9, about 1.9 GB of memory per language) and that keeps tone marks. Risks:
     - Bible-reading style.
     - One voice per language.
     - Share-alike on any fine-tune.
     - The Igbo short sample looks broken.
     - Attribution to Biblica / open.bible is needed.
   - **YarnGPT2** (en, ha, yo, ig). It is the only Nigerian-accented English option with a commercial licence. Problems:
     - 14–17 × slower than real time on our CPU, so it needs a GPU or must be made ahead of time.
     - It strips tone marks.
     - It reads numbers in English words in every language.
     - The rights to its training audio (Nigerian films and podcasts) are unclear. Ask the author before any public or paid use.
3. **Keep for the free pilot only (NON-COMMERCIAL):** MMS-TTS (current; en, ha, yo) and OmniVoice. OmniVoice is the most intelligible in English and Hausa by the round-trip check, but it is 36–213 × slower than real time on CPU and broke on Yorùbá.
4. **Rule out on licence grounds:**
   - XTTS-v2 (CPML; Coqui closed; no Nigerian languages)
   - YarnGPT-local, TWB Hausa and Murya Piper Hausa (all NC)
   - unlicensed community uploads (LICENCE UNCLEAR)
   - any MMS fine-tune (inherits NC)
5. **Whatever is chosen:** numbers must still go through `spoken.for_voice` (words, never digits), and segments with unknown characters must still be refused (CLAUDE.md rule 1). A native speaker must check every number word in each language before a voice reads health or money papers.

The Hausa, Yorùbá and Igbo test sentences are machine-made drafts. A native speaker must check them too.

## 7. Files

- Samples, with an `index.html` player page with licence badges, raw results (`results.jsonl`), ASR transcripts (`asr_check.json`) and the test scripts: `/Users/danieljemiri/magana-tts-samples/` (outside the repo).
- On the server, only `/home/ubuntu/tts-eval/` remains: 5.3 MB of samples and scripts. Eval images, environments and model caches were deleted, and disk use is back to 7.2 GB. Production containers were not touched.

**Not shipped: evaluation only.**
