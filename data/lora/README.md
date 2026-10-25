# Magana LoRA training set

Team-written (CC BY 4.0; docs/DATA_SOURCES.md S33). `build.py` turns the sources into
`train.jsonl` / `val.jsonl` in N-ATLaS chat format, using Magana's own prompts.

| File | What |
|---|---|
| `en_pages.json` | 30 schoolwork pages (Primary to SSS), each with an explanation and a simpler one, numbers written as printed |
| `en_refusals.json` | 20 "I can't explain this part" examples: calculations, unclear numbers, instructions written on a page |
| `drafts_ha.json`, `drafts_yo.json`, `drafts_ig.json` | Hausa, Yorùbá and Igbo drafts: **not used in training until a native speaker sets `"status": "native_reviewed"`** |
| `train.jsonl`, `val.jsonl`, `dataset_card.json` | built; do not edit by hand |

Every target is checked with Magana's own rules (`backend/app/placeholders.py`): each ⟦N⟧ used
exactly once (refusals may use fewer), no digit, number word or arithmetic, no unit word next to
a number. Numbers keep their units exactly as printed ("12 months", "20 seconds"), because
Magana puts the page's exact text back. No page or topic from `benchmark/explain/pages/` is used.

```bash
backend/.venv/bin/python data/lora/build.py
```
