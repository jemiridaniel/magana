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

from app import explain, placeholders, safety, templates  # noqa: E402


def engine_from(args) -> explain.Engine:
    if args.engine == "stub":
        return explain.StubEngine()
    if args.engine in ("vllm", "hf_space"):
        return explain.OpenAIChatEngine(args.url, args.api_key, args.model)
    if args.engine == "llamacpp":
        return explain.LlamaCppEngine(args.url, args.api_key)
    raise SystemExit(f"unknown engine {args.engine}")


# Which pages are health or money papers: those never reach the model (templates.py).
PAGE_MODE = {
    "04_medicine_label": "health",
    "05_malaria_leaflet": "health",
    "06_bank_statement": "money",
    "08_electricity_bill": "money",
    "09_vaccination_card": "health",
}


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
            mode = PAGE_MODE.get(page.stem, "school")
            if mode != "school":
                used = templates.translate(text, lang, mode)
                drafts = templates.translate(text, lang, mode, statuses=set(templates.STATUSES))
                row = {
                    "page": page.stem, "lang": lang, "mode": mode, "model_called": False,
                    "sentences": len(used["lines"]),
                    "translated_approved": sum(l["text"] is not None for l in used["lines"]),
                    "would_match_drafts": sum(l["text"] is not None for l in drafts["lines"]) if lang != "en" else None,
                    "lines": used["lines"], "fallback": used["fallback"], "blocked": False, "problems": [],
                    "seconds": 0.0, "error": None, "source": text, "raw_answer": "", "explanation": "",
                }
                rows.append(row)
                print(f"{lang} {page.stem:22} paper ({mode}): model not called; "
                      f"{row['translated_approved']}/{row['sentences']} approved, drafts would cover "
                      f"{row['would_match_drafts']}", flush=True)
                continue
            parts = explain.sections(text)
            system = explain.system_prompt(lang, guided=False)
            raws, finals, problems, t0, error, left = [], [], [], time.monotonic(), None, False
            for n, section in enumerate(parts, 1):
                masked = placeholders.mask(section)
                markers = [f"⟦N{k}⟧" for k in range(1, len(masked.slots) + 1)]
                try:
                    raw = engine.complete(
                        system, explain.user_prompt(masked.text, None, "explain", (n, len(parts)), markers),
                        args.timeout,
                    ).strip()
                except explain.ExplainUnavailable as e:
                    error = str(e)
                    break
                final, found = explain.check_answer(raw, masked, None, lang)
                left = left or (not found and explain.left_out(raw, masked))
                if not found and not safety.guard_explanation(section, final).ok:
                    found = [placeholders.Problem("old_guard")]
                raws.append(raw)
                finals.append(final)
                problems += [{"code": p.code, "detail": p.detail} for p in found]
            seconds = round(time.monotonic() - t0, 2)
            row = {
                "page": page.stem, "lang": lang, "mode": "school", "model_called": True,
                "raw_answer": "\n\n".join(raws), "explanation": "" if problems else "\n\n".join(finals),
                "blocked": bool(problems), "problems": problems, "error": error, "seconds": seconds,
                "numbers_left_out": left and not problems,
                "sections": len(parts), "source": text,
            }
            rows.append(row)
            flag = "ERROR" if error else ("BLOCKED " + ", ".join(sorted({p["code"] for p in problems}))
                                          if problems else "ok")
            print(f"{lang} {page.stem:22} {seconds:6.1f}s  {flag}", flush=True)

    write(rows, out, langs, args)


def rescore(args) -> None:
    """Score a finished run's saved answers again with the current rules, without the model."""
    src = Path(args.rescore)
    rows = [json.loads(line) for line in open(src / "outputs.jsonl")]
    for r in rows:
        if r["mode"] != "school" or r["error"]:
            continue
        assert r["sections"] == 1, "rescoring handles one-section pages"
        masked = placeholders.mask(r["source"])
        final, found = explain.check_answer(r["raw_answer"], masked, None, r["lang"])
        if not found and not safety.guard_explanation(r["source"], final).ok:
            found = [placeholders.Problem("old_guard")]
        r["problems"] = [{"code": p.code, "detail": p.detail} for p in found]
        r["blocked"] = bool(found)
        r["explanation"] = "" if found else final
        r["numbers_left_out"] = not found and explain.left_out(r["raw_answer"], masked)
    meta = json.loads((src / "summary.json").read_text())["run"]
    args.engine, args.model = meta["engine"], meta["model"]
    args.note = f"{meta.get('note', '')} Re-scored from {src.name}: markers left out are allowed when nothing numeric was added."
    write(rows, Path(args.out), sorted({r["lang"] for r in rows}, key="en ha yo ig".split().index), args)


def write(rows, out: Path, langs, args) -> None:
    out.mkdir(parents=True, exist_ok=True)
    with open(out / "outputs.jsonl", "w") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    summary = {}
    for lang in langs:
        mine = [r for r in rows if r["lang"] == lang]
        school = [r for r in mine if r["mode"] == "school" and not r["error"]]
        papers = [r for r in mine if r["mode"] != "school"]
        blocked = [r for r in school if r["blocked"]]
        reasons: dict[str, int] = {}
        for r in blocked:
            for code in {p["code"] for p in r["problems"]}:
                reasons[code] = reasons.get(code, 0) + 1
        summary[lang] = {
            "school_pages": len(school),
            "blocked": len(blocked),
            "passed": len(school) - len(blocked),
            "passed_numbers_left_out": sum(1 for r in school if not r["blocked"] and r.get("numbers_left_out")),
            "blocked_pages": [r["page"] for r in blocked],
            "block_reasons": dict(sorted(reasons.items())),
            "paper_pages": len(papers),
            "paper_model_calls": sum(r["model_called"] for r in papers),
            "paper_sentences": sum(r["sentences"] for r in papers),
            "paper_translated_approved": sum(r["translated_approved"] for r in papers),
            "paper_would_match_drafts": (sum(r["would_match_drafts"] for r in papers) if lang != "en" else None),
            "median_seconds": statistics.median([r["seconds"] for r in school]) if school else None,
            "errors": sum(1 for r in mine if r["error"]),
        }
        with open(out / f"ratings_{lang}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["page", "mode", "source_page", "model_answer_with_placeholders", "explanation_spoken",
                        "blocked", "block_reasons", "fluency_1_5", "faithful_to_page_1_5",
                        "harmful_or_advice_yes_no", "rater_id", "notes"])
            for r in mine:
                w.writerow([r["page"], r["mode"], r["source"], r["raw_answer"], r["explanation"], r["blocked"],
                            " ".join(sorted({p["code"] for p in r["problems"]})), "", "", "", "", ""])

    meta = {"engine": args.engine, "model": args.model, "design": "placeholders + templates",
            "temperature": explain.TEMPERATURE, "repetition_penalty": explain.REPETITION_PENALTY,
            "note": args.note}
    (out / "summary.json").write_text(json.dumps({"run": meta, "by_language": summary}, indent=2,
                                                 ensure_ascii=False))
    lines = [f"# Explanation benchmark: {args.engine} {args.model} (placeholders + templates)", "",
             args.note or "", "",
             "| Language | School pages | Blocked | Passed (numbers left out) | Block reasons | Paper pages: model calls | "
             "Paper sentences: approved / drafts would cover / total |",
             "|---|---|---|---|---|---|---|"]
    for lang, s in summary.items():
        reasons = ", ".join(f"{k} {v}" for k, v in s["block_reasons"].items()) or "—"
        lines.append(f"| {lang} | {s['school_pages']} | {s['blocked']} | {s['passed']} ({s['passed_numbers_left_out']}) | {reasons} | "
                     f"{s['paper_model_calls']} | {s['paper_translated_approved']} / "
                     f"{s['paper_would_match_drafts'] if s['paper_would_match_drafts'] is not None else '—'} / "
                     f"{s['paper_sentences']} |")
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
    p.add_argument("--rescore", help="a finished run's folder: score its saved answers again into --out")
    a = p.parse_args()
    rescore(a) if a.rescore else run(a)
