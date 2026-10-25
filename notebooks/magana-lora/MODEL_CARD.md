---
base_model: NCAIR1/N-ATLaS
library_name: peft
license: other
license_name: n-atlas-terms-of-use
license_link: https://huggingface.co/NCAIR1/N-ATLaS
language: [en]
tags: [n-atlas, lora, education, accessibility, nigeria]
pipeline_tag: text-generation
---

# Magana-ATLAS 8B LoRA (Powered by Awarri)

A LoRA adapter for **[N-ATLaS](https://huggingface.co/NCAIR1/N-ATLaS)** that explains printed
schoolwork pages for blind and low-vision learners in [Magana](https://github.com/jemiridaniel/magana)
**without ever writing a number itself**.

Magana replaces every number on a page, with its unit or currency, by a marker (⟦N1⟧, ⟦N2⟧ …)
before the model sees it, and puts the page's exact text back afterwards. This adapter is
trained to copy each marker exactly once, never add a digit, number word or unit, never
calculate, and to say "I can't explain this part" when a question needs a calculation, a number
is unclear, or the page contains instructions. Magana still checks every answer
(`backend/app/placeholders.py`) and reads the page instead when a check fails.

**Not for health or money papers:** Magana never sends those to a model.

## Training data

`data/lora/` in the Magana repo: 80 English examples, all team-written (CC BY 4.0):

- 30 schoolwork pages, each with an explanation and a simpler one;
- 20 refusals.

No page or topic from Magana's explanation benchmark is used. Hausa, Yorùbá and Igbo drafts
exist, but none is used until a native speaker has reviewed it, so **this version is
English-only in training**.

Recipe: the Ibà-ATLAS QLoRA recipe (4-bit NF4, r=16, α=32, every attention and MLP projection,
loss on the reply only), 3 epochs on a Kaggle T4.

## Results

See Magana's docs/FINDINGS.md, "Magana LoRA". The 40-page benchmark is run on base N-ATLaS and
on this adapter in the same session, with the same prompts and checks.

## Usage

Use Magana's own prompts (`backend/app/explain.py`: `system_prompt`, `user_prompt` with the
marker list). With vLLM:

```bash
vllm serve NCAIR1/N-ATLaS --enable-lora --max-lora-rank 16 \
  --lora-modules magana-atlas=<path or repo of this adapter> --dtype half --max-model-len 8192
```

## Licence and attribution

Derived from **N-ATLaS** and released under the
[N-ATLaS Terms of Use](https://huggingface.co/NCAIR1/N-ATLaS). N-ATLaS is by **Awarri
Technologies** and the **Federal Ministry of Communications, Innovation and Digital Economy**
of Nigeria. Use is limited to organisations with at most 1,000 active end-users in a rolling
30-day period; larger deployments need a licence from Awarri. As the terms require, the
adapter's name ends with "Powered by Awarri".

Built by Jemiri Daniel Taiwo for Magana (Nigeria AI Collective / DSN "AI for Visual Impairment").
