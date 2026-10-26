"""Explain fail-safe report on the saved 20-prompt set (5 schoolwork pages × 4 languages, base
N-ATLaS and the Magana LoRA, results/2026-10-25-kaggle-t4-magana-lora/lora-bench.jsonl).

    backend/.venv/bin/python benchmark/explain/failsafe_report.py [--out results/<run>/failsafe.json]

Each saved answer goes through today's rules (backend/app/explain.py): every ⟦N⟧ exactly once,
none mangled, no number, number word, unit word or arithmetic added, the answer in the asked
language, then safety.guard_explanation. Counted per model and language:
- spoken: passed, so the app would say it (and, for Hausa, Yorùbá and Igbo, only if Explain
  were switched on for them: it is off, "Explain in <language> is coming");
- safely refused: not spoken; the app says "I couldn't explain this page safely" and reads the page;
- unsafe spoken: spoken, yet an independent check finds a number the page doesn't have (every
  digit run and number word in the spoken text, against the page's own), or a marker missing.
  Numbers put in the wrong place can't be found automatically: every spoken answer is listed
  for a person to read (docs/FINDINGS.md has the developer's reading).
The saved answers are single greedy answers, so the retry at temperature 0 can't be replayed
here: it needs the model running.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[2] / "backend"))
from app import explain, placeholders, safety  # noqa: E402

RUN = HERE.parent / "results" / "2026-10-25-kaggle-t4-magana-lora" / "lora-bench.jsonl"
NUMBER = re.compile(r"\d+(?:[.,/]\d+)*")


def page_numbers(source: str) -> Counter:
    return Counter(NUMBER.findall(source))


def unsafe(spoken: str, source: str, lang: str) -> list[str]:
    """Independent of the marker check: numbers in what would be said that the page lacks."""
    found = []
    have = page_numbers(source)
    for n, count in Counter(NUMBER.findall(spoken)).items():
        if count > have.get(n, 0):
            found.append(f"number {n} ×{count}, page has ×{have.get(n, 0)}")
    on_page = {placeholders.plain(w) for w in placeholders.words(source)}
    for lst in (placeholders.word_list(lang), placeholders.word_list("en")):
        for w in placeholders.words(spoken):
            if placeholders.plain(w) in lst.words and placeholders.plain(w) not in on_page:
                found.append(f"number word {w}")
    return found


def judge(row: dict) -> dict:
    source, raw, lang = row["source"], row["raw_answer"], row["lang"]
    page = placeholders.mask(source)
    text, problems = explain.check_answer(raw.strip(), page, None, lang, allow_left_out=False)
    ok = not problems and safety.guard_explanation(source, text).ok
    out = {"model": row["model"], "lang": lang, "page": row["page"], "spoken": ok,
           "problems": sorted({p.code for p in problems}), "old_rules_spoken": not row["blocked"]}
    if ok:
        out["text"] = text
        out["unsafe"] = unsafe(text, source, lang)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", default=str(RUN))
    ap.add_argument("--out")
    a = ap.parse_args()
    rows = [json.loads(l) for l in open(a.run, encoding="utf-8")]
    judged = [judge(r) for r in rows]
    print(f"{'model':12} {'lang':4} {'spoken':>6} {'refused':>7} {'unsafe':>6}   (old rules: spoken)")
    for model in ("base", "magana-lora"):
        for lang in ("en", "ha", "yo", "ig", "all"):
            js = [j for j in judged if j["model"] == model and (lang == "all" or j["lang"] == lang)]
            spoken = sum(j["spoken"] for j in js)
            bad = sum(bool(j.get("unsafe")) for j in js)
            print(f"{model:12} {lang:4} {spoken:6} {len(js) - spoken:7} {bad:6}   ({sum(j['old_rules_spoken'] for j in js)})")
    print("\nWould be spoken (read each for numbers in the wrong place):")
    for j in judged:
        if j["spoken"]:
            print(f"- {j['model']} {j['lang']} {j['page']}: {j['text'][:400]}")
    if a.out:
        Path(a.out).write_text(json.dumps(judged, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
