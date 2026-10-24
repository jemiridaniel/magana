"""Explanation benchmark: number-change rate per language, and outputs for native-speaker rating.

For every page in pages/ and every language, ask the engine to explain the page with the
app's own prompts (backend/app/explain.py), section by section, and run
safety.guard_explanation on each answer. Unlike the app, keep the rejected answers too:
the raters need to see what the model did with the numbers.

Writes to --out:
  outputs.jsonl           one line per page x language (all fields)
  ratings_<lang>.csv      for native speakers: page, explanation, blank rating columns
  summary.json / .md      number-change rate and latency per language
"""
from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))

from app import explain, safety  # noqa: E402


def engine_from(args) -> explain.Engine:
    if args.engine == "stub":
        return explain.StubEngine()
    if args.engine in ("vllm", "hf_space"):
        return explain.OpenAIChatEngine(args.url, args.api_key, args.model)
    if args.engine == "llamacpp":
        return explain.LlamaCppEngine(args.url, args.api_key)
    raise SystemExit(f"unknown engine {args.engine}")


def run(args) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    pages = sorted(Path(args.pages).glob("*.txt"))
    langs = args.langs.split(",")
    engine = engine_from(args)
    rows = []
    for lang in langs:
        for page in pages:
            text = page.read_text().strip()
            parts = explain.sections(text)
            system = explain.system_prompt(lang, guided=False)
            answers, unsupported, t0, error = [], [], time.monotonic(), None
            for n, section in enumerate(parts, 1):
                try:
                    answer = engine.complete(
                        system, explain.user_prompt(section, None, "explain", (n, len(parts))), args.timeout
                    ).strip()
                except explain.ExplainUnavailable as e:
                    error = str(e)
                    break
                answers.append(answer)
                unsupported += safety.guard_explanation(section, answer).unsupported
            seconds = round(time.monotonic() - t0, 2)
            row = {
                "page": page.stem, "lang": lang, "engine": args.engine, "model": args.model,
                "explanation": "\n\n".join(answers), "rejected_by_guard": bool(unsupported),
                "numbers_not_on_page": unsupported, "error": error, "seconds": seconds,
                "sections": len(parts), "source": text,
            }
            rows.append(row)
            flag = "ERROR" if error else ("REJECTED " + ",".join(unsupported) if unsupported else "ok")
            print(f"{lang} {page.stem:22} {seconds:6.1f}s  {flag}", flush=True)

    with open(out / "outputs.jsonl", "w") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    summary = {}
    for lang in langs:
        mine = [r for r in rows if r["lang"] == lang]
        answered = [r for r in mine if not r["error"]]
        rejected = [r for r in answered if r["rejected_by_guard"]]
        summary[lang] = {
            "pages": len(mine),
            "answered": len(answered),
            "errors": len(mine) - len(answered),
            "rejected_by_guard": len(rejected),
            "number_change_rate": round(len(rejected) / len(answered), 3) if answered else None,
            "median_seconds": statistics.median([r["seconds"] for r in answered]) if answered else None,
            "rejected_pages": [r["page"] for r in rejected],
        }
        with open(out / f"ratings_{lang}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["page", "source_page", "explanation", "rejected_by_guard",
                        "fluency_1_5", "faithful_to_page_1_5", "numbers_kept_yes_no",
                        "harmful_or_advice_yes_no", "rater_id", "notes"])
            for r in mine:
                w.writerow([r["page"], r["source"], r["explanation"], r["rejected_by_guard"],
                            "", "", "", "", "", ""])

    meta = {"engine": args.engine, "model": args.model, "url_kind": args.engine,
            "temperature": explain.TEMPERATURE, "repetition_penalty": explain.REPETITION_PENALTY,
            "note": args.note}
    (out / "summary.json").write_text(json.dumps({"run": meta, "by_language": summary}, indent=2,
                                                 ensure_ascii=False))
    lines = [f"# Explanation benchmark: {args.engine} {args.model}", "", args.note or "", "",
             "| Language | Pages | Answered | Rejected by guard | Number-change rate | Median s |",
             "|---|---|---|---|---|---|"]
    for lang, s in summary.items():
        lines.append(f"| {lang} | {s['pages']} | {s['answered']} | {s['rejected_by_guard']} | "
                     f"{s['number_change_rate']} | {s['median_seconds']} |")
    lines += ["", "Unreviewed: fluency and faithfulness need native-speaker ratings (ratings_<lang>.csv)."]
    (out / "summary.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--engine", default="stub", choices=["stub", "vllm", "hf_space", "llamacpp"])
    p.add_argument("--url", default="")
    p.add_argument("--api-key", default="")
    p.add_argument("--model", default="NCAIR1/N-ATLaS", help="base model or LoRA adapter name (vllm)")
    p.add_argument("--langs", default="en,ha,yo,ig")
    p.add_argument("--pages", default=str(Path(__file__).parent / "pages"))
    p.add_argument("--out", required=True)
    p.add_argument("--timeout", type=float, default=120.0,
                   help="per call; the app uses 20 s for the whole explanation")
    p.add_argument("--note", default="")
    run(p.parse_args())
