"""Build the Magana LoRA training set: train.jsonl, val.jsonl, dataset_card.json.

Sources (all team-written, CC BY 4.0; docs/DATA_SOURCES.md S15/S16):
  en_pages.json     schoolwork pages with an explanation and a simpler one, numbers written
                    as printed
  en_refusals.json  "I can't explain this part": calculations, unclear numbers, instructions
                    written on the page
  drafts_<lang>.json  Hausa, Yorùbá and Igbo explanations: used ONLY once a native speaker
                    has set "status": "native_reviewed"

Each example is the app's own prompt (backend/app/explain.py): the page with every number
replaced by ⟦N1⟧ …, then an explanation that uses every ⟦N⟧ exactly once and adds no digit,
number word, unit word or arithmetic (backend/app/placeholders.py checks it; the build fails
on any example that wouldn't pass Magana's own check).

    backend/.venv/bin/python data/lora/build.py
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "backend"))

from app import explain, placeholders as P  # noqa: E402

LANGS = ("en", "ha", "yo", "ig")


def to_markers(text: str, page: P.Masked) -> str:
    """Write an explanation's numbers as the page's markers. Equal texts are interchangeable
    (same value); each page number may be used once."""
    said = P.mask(text)
    free = list(range(len(page.slots)))
    markers = []
    for value in said.slots:
        k = next((i for i in free if page.slots[i] == value), None)
        if k is None:
            raise ValueError(f"{value!r} is not a number on the page (page has {page.slots})")
        free.remove(k)
        markers.append(f"⟦N{k + 1}⟧")
    it = iter(markers)
    return P.PLACEHOLDER.sub(lambda _m: next(it), said.text)


def example(page_text: str, answer: str, lang: str, style: str = "explain", question: str | None = None,
            every_marker: bool = True) -> dict:
    page = P.mask(page_text)
    asked = P.mask(question, start=len(page.slots) + 1) if question else None
    target = to_markers(answer, page)
    every = range(1, len(page.slots) + 1)
    problems = P.check(target, page.text, required=every if every_marker else range(0),
                       optional=range(0) if every_marker else every, lang=lang)
    if not every_marker:
        problems = [p for p in problems if p.code != "placeholder_missing"]
    if problems:
        raise ValueError(f"would be refused: {[(p.code, p.detail) for p in problems]}: {target}")
    markers = [f"⟦N{k}⟧" for k in range(1, len(page.slots) + 1)]
    return {"messages": [
        {"role": "system", "content": explain.system_prompt(lang, guided=False)},
        {"role": "user", "content": explain.user_prompt(page.text, asked.text if asked else None, style, (1, 1), markers)},
        {"role": "assistant", "content": target},
    ]}


def split(key: str) -> str:
    """About 1 in 10 for validation, fixed by the page id (both styles stay together)."""
    return "val" if int(hashlib.sha256(key.encode()).hexdigest(), 16) % 10 == 0 else "train"


def main() -> None:
    pages = json.loads((HERE / "en_pages.json").read_text())
    by_id = {p["id"]: p for p in pages}
    rows: dict[str, list] = {"train": [], "val": []}
    counts = {"en_explain": 0, "en_simpler": 0, "en_refusal": 0}
    for p in pages:
        for style in ("explain", "simpler"):
            rows[split(p["id"])].append(example(p["page"], p[style], "en", style))
            counts[f"en_{style}"] += 1
    for r in json.loads((HERE / "en_refusals.json").read_text()):
        rows[split(r["id"])].append(example(r["page"], r["answer"], "en", question=r["question"], every_marker=False))
        counts["en_refusal"] += 1

    drafts = {"used": {}, "held_back": {}, "would_be_refused": {}}
    for lang in LANGS[1:]:
        path = HERE / f"drafts_{lang}.json"
        for d in json.loads(path.read_text()) if path.exists() else []:
            try:
                ex = example(by_id[d["id"]]["page"], d["explanation"], lang)
            except ValueError as e:
                drafts["would_be_refused"].setdefault(lang, []).append(f"{d['id']}: {e}")
                continue
            if d["status"] == "native_reviewed":
                rows[split(d["id"])].append(ex)
                drafts["used"][lang] = drafts["used"].get(lang, 0) + 1
            else:
                drafts["held_back"][lang] = drafts["held_back"].get(lang, 0) + 1

    for name, items in rows.items():
        (HERE / f"{name}.jsonl").write_text("".join(json.dumps(x, ensure_ascii=False) + "\n" for x in items))
    card = {
        "name": "magana-lora-schoolwork-v1",
        "licence": "CC BY 4.0 (Magana Learn team)",
        "train": len(rows["train"]), "val": len(rows["val"]),
        "counts": counts,
        "languages_in_training": ["en"] + sorted(drafts["used"]),
        "drafts": drafts,
        "rule": "Non-English examples are used only after native review (status native_reviewed).",
        "benchmark_pages_excluded": "No page or topic from benchmark/explain/pages/ is used.",
    }
    (HERE / "dataset_card.json").write_text(json.dumps(card, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(card, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
