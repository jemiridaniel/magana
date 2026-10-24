# Explanation benchmark (N-ATLaS)

Ten short pages written by the Magana team (`pages/`, CC BY 4.0), mostly full of numbers,
doses, amounts and dates. Each page is explained in each language by the engine under test
(`explain_bench.py`), section by section with the same prompts as the app.

Reported per language:
- **number-change rate**: the share of explanations `safety.guard_explanation` rejects
  (they added or changed a number). In the app those are never spoken; the page is read instead.
- latency per explanation.

Every explanation is saved, with the page, for native-speaker rating (`ratings_<lang>.csv`:
fluency, faithfulness, numbers kept, notes). Results are **unreviewed** until rated.

Run (base model first; a Magana LoRA is decided from these results):
```bash
backend/.venv/bin/python benchmark/explain/explain_bench.py \
  --engine llamacpp --url http://127.0.0.1:8080 --langs en,ha,yo,ig --out benchmark/explain/results/<run>
backend/.venv/bin/python benchmark/explain/explain_bench.py \
  --engine vllm --url https://<tunnel> --api-key ... --model NCAIR1/N-ATLaS --out ...
```
