# Models: N-ATLaS and the NCAIR1 speech models

Magana uses five open models from the **NCAIR1** organisation on Hugging Face, all under the **N-ATLaS Terms of Use v1.0** (September 2025):

| Use in Magana | Model | What it is |
|---|---|---|
| Explain (Hausa, Yorùbá, Igbo, English) | [`NCAIR1/N-ATLaS`](https://huggingface.co/NCAIR1/N-ATLaS) | Llama 3.1 8B fine-tune, 8.03 B parameters, bf16, 16.06 GB |
| Voice input, Hausa | [`NCAIR1/Hausa-ASR`](https://huggingface.co/NCAIR1/Hausa-ASR) | Whisper Small fine-tune, about 242 M parameters, fp32, 967 MB |
| Voice input, Yorùbá | [`NCAIR1/Yoruba-ASR`](https://huggingface.co/NCAIR1/Yoruba-ASR) | same |
| Voice input, Igbo | [`NCAIR1/Igbo-ASR`](https://huggingface.co/NCAIR1/Igbo-ASR) | same |
| Voice input, English | [`NCAIR1/NigerianAccentedEnglish`](https://huggingface.co/NCAIR1/NigerianAccentedEnglish) | same |

Facts below are from each model's card, `config.json`, `tokenizer_config.json` and the Hugging Face API, read on 24 Oct 2026. Where a source is unclear, this says so.

## Licence (N-ATLaS Terms of Use v1.0)

The terms are at the bottom of each model card; there is no separate LICENSE file. They describe "an Open-Source Research and Innovation License inspired by permissive licenses such as Apache 2.0 and MIT, but with additional restrictions", and say N-ATLaS is **not** an enterprise-grade or commercial system.

- **Grant:** worldwide, royalty-free, non-exclusive, non-transferable right to download, use, run, modify and redistribute, under the same Terms.
- **User cap (§3):** "Use of N-ATLaS is limited to organizations, institutions, or projects with no more than **1000 active end-users**."
  - An active end-user is "an individual who directly interacts with N-ATLaS outputs (e.g., via an app, website, or integrated service) within a rolling 30-day period".
  - For Magana that means everyone who hears an explanation **or** uses voice input through these models in any 30 days, counted together.
- **Beyond 1,000 users:** a **commercial licence** is required, "directly from Awarri Technologies in partnership with the Federal Ministry of Communications, Innovation, and Digital Economy". Contacts (§11): Awarri, datasupport@awarri.com; the Ministry via NCAIR, ncair@nitda.gov.ng. **Magana must arrange this before going past 1,000 active users.**
- **Permitted uses (§4)** include accessibility for persons with disabilities, education and training, language preservation and civic tech: Magana's purpose.
- **Prohibited (§4):** surveillance, discriminatory profiling, disinformation or impersonation, military use, exploitative or unlawful use.
- **Derivatives** (for example a Magana LoRA) must be released under the same Terms. If renamed, they must carry the suffix **"Powered by Awarri."** The Ibà adapter already does: `jemiridaniel/Iba-ATLAS-8B-LoRA-Powered-by-Awarri`.
- **Other terms:**
  - provided as is, with no liability;
  - users must report accuracy, bias and limitations openly (§6; `docs/FINDINGS.md` does this);
  - no personal-data scraping or profiling;
  - Nigerian law applies;
  - rights can be revoked for breach.
- **Gated access:** all five repos are gated "auto" (click-through, approved automatically).

### Required attribution (verbatim; shown in the app under Settings → About)

- **N-ATLaS:** "N-ATLaS is an initiative of the Federal Ministry of Communications, Innovation and Digital Economy, and powered by Awarri Technologies."
- **Hausa-ASR:** "Hausa-ASR is powered by Awarri Technologies in an initiative of the Federal Ministry of Communications, Innovation and Digital Economy"
- **Yoruba-ASR:** "Yoruba-ASR is developed by Awarri Technologies in partnership with the Federal Government of Nigeria."
- **Igbo-ASR:** "Igbo-ASR is powered by Awarri Technologies in an initiative of the Federal Ministry of Communications, Innovation and Digital Economy."
- **NigerianAccentedEnglish:** "NigerianAccentedEnglish is powered by Awarri Technologies and an initiative of the Federal Ministry of Communications, Innovation and Digital Economy."
- **Condition §2(1), for all of them:** "Awarri Technologies and the Federal Ministry of Communications, Innovation and Digital Economy."

## N-ATLaS facts

- **Base:**
  - The card says "Llama-3 8B", but `config.json` is Llama 3.1: `rope_type: llama3`, factor 8, original 8,192, max 131,072. The chat template is Llama 3.1's.
  - 32 layers, 128,256-token vocabulary.
  - Released September 2025.
- **Context:** the card says "**8,092 tokens**" (probably 8,192) and, under Limitations, "Limited to 8,092 tokens for optimal performance". The config allows 131,072.
  - Magana keeps to the card. It sends at most 12,000 characters per explanation, in sections of at most 6,000 characters, and leaves room for the prompt and a 700-token answer.
  - vLLM servers use `--max-model-len 8192`.
- **Chat template:** Llama 3.1. The system header carries "Cutting Knowledge Date: December 2023" and "Today Date: {date_string}".
  - `date_string` defaults to "26 Jul 2024".
  - The card sets it with `datetime.now().strftime('%d %b %Y')`, for example "24 Oct 2026". Magana does the same: vLLM gets `chat_template_kwargs.date_string`, and llama.cpp gets the template rendered by `explain.render_llama31`.
- **Generation:**
  - The card's example uses `temperature=0.1`, `repetition_penalty=1.12`, `max_new_tokens=1000`; Magana uses the same values with a 700-token cap.
  - `generation_config.json` defaults are Llama's (temperature 0.6, top_p 0.9), so callers must set their own.
- **Card's own evaluation** (human ratings, out of 5; no automatic benchmarks):

  | | English | Hausa | Yorùbá | Igbo |
  |---|---|---|---|---|
  | Evaluations | 1,662 | 140 | 542 | 296 |
  | Average score | 4.21 | 3.98 | 2.69 | 3.87 |
  | Fluency | 4.30 | 4.23 | 2.71 | 3.89 |
  | Coherence | 4.22 | 3.70 | 3.23 | 3.80 |
  | Relevance | 4.28 | 3.76 | 2.89 | 3.85 |
  | Accuracy | 4.23 | 3.72 | 3.13 | 3.92 |
  | Bias/Fairness | 3.18 | 1.11 | 2.23 | 4.01 |
  | Usefulness | 4.09 | 5.00 | 4.03 | 3.84 |

  The card itself says Yorùbá has "room for improvement". Hausa's Bias/Fairness score (1.11) comes from only 140 ratings. Magana's own measurements are in `docs/FINDINGS.md`, unreviewed until native speakers rate them.
- **Hardware:** not stated on the card.
  - fp16 needs about 16 GB of GPU memory, so 2 × T4 with tensor parallelism on Kaggle.
  - A 4-bit build runs on one 16 GB GPU, or on a 16 GB Apple Silicon Mac with llama.cpp. Community GGUFs exist (none official), e.g. `QuantFactory/N-ATLaS-GGUF`, where Q4_K_M is 4.92 GB.

## Speech models (ASR) facts

- **Model:** all four are Whisper Small fine-tunes (`WhisperForConditionalGeneration`). The cards say 244 M parameters; the stored `pytorch_model.bin` is 967 MB fp32. There is no safetensors file.
- **Input:** 16 kHz mono, 30-second maximum per call.
- **No published error rates:** none of the four cards reports a WER or CER, or names a test set; the training logs have training loss only. Magana's own measurements are in `docs/FINDINGS.md`.
- **Igbo:** Whisper has no Igbo language token (`<|ig|>`), so Igbo-ASR is run without a forced language.
- **CPU:**
  - The cards say nothing about CPU use.
  - Our assessment, not the cards': Whisper Small runs on a server CPU, typically a few seconds per short clip.
  - On a low-cost phone it would need an int8 conversion (about 250 MB), which nobody has published for the Hausa, Yorùbá or Igbo models.
  - So Magana runs these models on the **server** (`ASR_ENGINE=local`), and phones fall back to their own speech recognition.

## How Magana reaches the models

| Setting | Options |
|---|---|
| `EXPLAIN_ENGINE` | `stub` (preview: the page text, no model), `vllm` (OpenAI-compatible vLLM with `--enable-lora`; `EXPLAIN_MODEL` = `NCAIR1/N-ATLaS` or a LoRA adapter name), `hf_space` (OpenAI-compatible server on a Hugging Face Space), `llamacpp` (llama.cpp server with a GGUF) |
| `EXPLAIN_URL`, `EXPLAIN_API_KEY` | the server and its key (vLLM `--api-key`) |
| `ASR_ENGINE` | `device` (default: the phone's own recogniser) or `local` (the four NCAIR1 Whisper models on the backend's CPU; `backend/requirements-asr.txt`) |

- **Every explanation** goes through `safety.guard_explanation`, section by section, within a 20-second deadline. If an answer adds or changes a number, or the model is slow or down, the app reads the page instead.
- **Guided learners (13 to 17)** get a curriculum-only prompt.
- **One GPU, several adapters:** vLLM with `--enable-lora --max-lora-rank 16` serves the base model, the Ibà adapter (`iba-atlas`) and a future Magana adapter side by side. Choose with `EXPLAIN_MODEL`.
- **Base model first:** a Magana LoRA is decided from the benchmark (`benchmark/explain/`): its number-change rate per language, and native-speaker ratings of the saved outputs.

## Kaggle: development and demos only

`notebooks/magana-serve` serves N-ATLaS on vLLM in a Kaggle notebook (GPU T4 × 2), protected by an API key, behind a temporary Cloudflare tunnel. `scripts/set_explain_url.sh <url>` points the AWS server at it. Kaggle is **not** a production host:

- **GPU time:** about **30 hours per week**, resetting weekly. It varies by account; check the quota shown in the notebook editor.
- **Sessions:** at most about **12 hours** each (some sources say 9), and they stop sooner when idle. The tunnel URL changes every session, so Explain falls back to reading the page whenever the notebook isn't running.
- **Terms:** Kaggle's terms cover notebooks for data science work, not running a public service for real users.

Sources for these limits are secondary and vary: [AIMultiple, free cloud GPUs](https://aimultiple.com/free-cloud-gpu), [PyPI kgz](https://pypi.org/p/kgz), [Logicity](https://logicity.in/en/blog/how-to-run-70b-llms-free-using-kaggle-s-hidden-gpu-tier). The notebook's settings panel is authoritative.

For real users, N-ATLaS needs a GPU server that stays up:
- **DSN's compute**, if it can give a persistent GPU;
- or a cloud GPU with at least 16 GB (24 GB is more comfortable for fp16 plus LoRA). On AWS that is a g5/g6 instance, which is **not** in the free plan; agree the cost before starting one.
