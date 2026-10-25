"""The 40-page explanation benchmark on Kaggle: base N-ATLaS and the Magana LoRA, same run.

Loads the 4-bit base once, then answers the 20 schoolwork page-language prompts with the
adapter off (base) and on, using Magana's own prompts and checks (backend/app/explain.py,
placeholders.py). Health and money pages never go to a model, so they are not run here.
Only the team's own test pages (benchmark/explain/pages/) are used: docs/MODELS.md.

    python notebooks/magana-lora/bench.py --adapter outputs/magana-lora --out results/lora-bench.jsonl
"""
import argparse
import json
import sys
import time
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "benchmark" / "explain"))

from app import explain, placeholders, safety  # noqa: E402
from explain_bench import PAGE_MODE  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="NCAIR1/N-ATLaS")
    ap.add_argument("--adapter", default="outputs/magana-lora")
    ap.add_argument("--out", default="results/lora-bench.jsonl")
    ap.add_argument("--langs", default="en,ha,yo,ig")
    args = ap.parse_args()

    tok = AutoTokenizer.from_pretrained(args.base)
    base = AutoModelForCausalLM.from_pretrained(
        args.base, device_map={"": 0}, torch_dtype=torch.float16,
        quantization_config=BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type="nf4",
                                               bnb_4bit_compute_dtype=torch.float16, bnb_4bit_use_double_quant=True))
    model = PeftModel.from_pretrained(base, args.adapter)
    model.eval()

    def generate(messages, use_adapter: bool) -> str:
        # Render to text first, as train.py does: apply_chat_template's tensor return type
        # differs across transformers versions (a BatchEncoding in newer ones).
        text = tok.apply_chat_template(messages, add_generation_prompt=True, tokenize=False)
        ids = tok(text, add_special_tokens=False, return_tensors="pt")["input_ids"].to(0)
        kw = dict(max_new_tokens=explain.ANSWER_TOKENS, do_sample=False,
                  repetition_penalty=explain.REPETITION_PENALTY, pad_token_id=tok.eos_token_id)
        with torch.no_grad():
            if use_adapter:
                out = model.generate(input_ids=ids, **kw)
            else:
                with model.disable_adapter():
                    out = model.generate(input_ids=ids, **kw)
        return tok.decode(out[0][ids.shape[1]:], skip_special_tokens=True).strip()

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w") as f:
        for lang in args.langs.split(","):
            for page in sorted((ROOT / "benchmark" / "explain" / "pages").glob("*.txt")):
                if PAGE_MODE.get(page.stem, "school") != "school":
                    continue
                text = page.read_text().strip()
                masked = placeholders.mask(text)
                markers = [f"⟦N{k}⟧" for k in range(1, len(masked.slots) + 1)]
                messages = [{"role": "system", "content": explain.system_prompt(lang, guided=False)},
                            {"role": "user", "content": explain.user_prompt(masked.text, None, "explain", (1, 1), markers)}]
                for model_name, use in (("base", False), ("magana-lora", True)):
                    t0 = time.monotonic()
                    raw = generate(messages, use)
                    final, found = explain.check_answer(raw, masked, None, lang)
                    if not found and not safety.guard_explanation(text, final).ok:
                        found = [placeholders.Problem("old_guard")]
                    row = {"model": model_name, "lang": lang, "page": page.stem, "raw_answer": raw,
                           "explanation": "" if found else final, "blocked": bool(found),
                           "problems": [{"code": p.code, "detail": p.detail} for p in found],
                           "numbers_left_out": not found and explain.left_out(raw, masked),
                           "seconds": round(time.monotonic() - t0, 1), "source": text}
                    f.write(json.dumps(row, ensure_ascii=False) + "\n")
                    f.flush()
                    print(model_name, lang, page.stem, "BLOCKED" if found else "ok", row["seconds"], flush=True)


if __name__ == "__main__":
    main()
