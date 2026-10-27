"""Teachers' lesson notes (private): inventory, reading test, and draft practice quizzes.

The notes are a teacher's own work, shared with the team privately. Nothing here leaves the Mac:
the photos are read with Tesseract, and labels and quizzes come from N-ATLaS running locally
(llama.cpp, LESSON_LLM_URL, default http://127.0.0.1:8099). Everything this writes goes to
~/magana-private-pages/, never into the repository, and it prints counts and labels only.

    .venv/bin/python scripts/lesson_notes.py prepare   # EXIF-free copies, OCR, typed or handwritten
    .venv/bin/python scripts/lesson_notes.py label     # subject, class, topic (local model)
    .venv/bin/python scripts/lesson_notes.py inventory # the table, no note text
    .venv/bin/python scripts/lesson_notes.py accuracy  # reading accuracy, typed vs handwritten
    .venv/bin/python scripts/lesson_notes.py quiz      # DRAFT quizzes from the typed notes
    .venv/bin/python scripts/lesson_notes.py review    # the review spreadsheet for the teacher
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.reader import read_page  # noqa: E402

PRIVATE = Path.home() / "magana-private-pages"
SOURCE = PRIVATE / "teacher-lesson-notes"
WORK = PRIVATE / "testset" / "lessonnote"
DRAFTS = PRIVATE / "quiz-drafts"
LLM = os.environ.get("LESSON_LLM_URL", "http://127.0.0.1:8099")
APP_WIDTH = 1080  # what the app sends (docs/FINDINGS.md, 0.1.0+8)


def pages() -> list[Path]:
    return sorted(p for p in SOURCE.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".heic"})


def page_id(n: int) -> str:
    return f"note{n:02d}"


def manifest() -> list[dict]:
    path = WORK / "manifest.json"
    return json.loads(path.read_text()) if path.exists() else []


def save_manifest(rows: list[dict]) -> None:
    (WORK / "manifest.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2))


def words_of(result: dict) -> list[dict]:
    return [w for l in result["lines"] for w in l.get("words", []) if w.get("text", "").strip()]


# ---------- prepare: EXIF-free copies, read as the app would send them

def prepare() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    trocr = None
    if "--trocr" in sys.argv:
        # Handwritten lines read again by TrOCR on this Mac (never Azure: images would leave it).
        from app.handwriting import TrOCRReader

        trocr = TrOCRReader()
    rows = []
    for n, src in enumerate(pages(), 1):
        img = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
        clean = Image.new("RGB", img.size)
        clean.paste(img)  # pixels only: no EXIF, no location
        pid = page_id(n)
        clean.save(WORK / f"{pid}.jpg", "JPEG", quality=92)
        sent = clean.resize((APP_WIDTH, round(clean.height * APP_WIDTH / clean.width)), Image.LANCZOS)
        result = read_page(sent)
        (WORK / f"{pid}.json").write_text(json.dumps(result, ensure_ascii=False))
        if trocr:
            again = read_page(sent, handwriting=trocr)
            (WORK / f"{pid}.trocr.json").write_text(json.dumps(again, ensure_ascii=False))
        lines = result["lines"]
        hand = sum(1 for l in lines if l.get("script") == "handwritten")
        rows.append({"id": pid, "source": src.name, "type": "lessonnote", "lines": len(lines),
                     "words": len(words_of(result)), "script": result["script"],
                     "handwritten_lines": hand,
                     "kind": "handwritten" if result["script"] == "handwritten" or (lines and hand / len(lines) >= 0.5)
                     else "typed"})
    save_manifest(rows)
    kinds = Counter(r["kind"] for r in rows)
    print(f"{len(rows)} photos prepared: {kinds['typed']} typed, {kinds['handwritten']} handwritten")


# ---------- label: subject, class, topic (patterns first, then the local model, checked)

SUBJECTS = {
    "mathematics": ["mathematics", "maths", "math"], "english": ["english"],
    "basic_science": ["basic science", "science"], "social_studies": ["social studies"],
    "civic_education": ["civic"], "basic_technology": ["basic tech", "technology"],
    "computer_studies": ["computer", "ict"], "agriculture": ["agric"], "home_economics": ["home economics"],
    "crs": ["c.r.s", "crs", "christian religious"], "irs": ["i.r.s", "irs", "islamic"],
    "physical_health": ["physical and health", "p.h.e", "phe"], "security": ["security"],
    "verbal_reasoning": ["verbal"], "quantitative_reasoning": ["quantitative"],
    "cca": ["cultural and creative", "c.c.a", "cca"], "french": ["french"],
    "yoruba": ["yoruba"], "hausa": ["hausa"], "igbo": ["igbo"], "history": ["history"],
}


def reading(pid: str) -> dict:
    """Tesseract's reading. Not TrOCR's: on these handwritten notes it writes fluent English that
    isn't on the page ("The American Revolution" on a Nigerian Basic 4 note, 27 Oct 2026), so its
    text is never used for labels or quizzes; it is only measured."""
    return json.loads((WORK / f"{pid}.json").read_text())


def ocr_text(pid: str) -> str:
    return "\n".join(l["text"] for l in reading(pid)["lines"])


def _class(text: str) -> str:
    m = re.search(r"\b(?:basic|bsc|bas1c|primary|pry|p)\s*[-.:]?\s*([1-9])\b", text, re.I)
    if m and m.group(1) in "45":
        return f"Basic {m.group(1)}"
    return f"Basic {m.group(1)}" if m else "unclear"


def _subject(text: str) -> str:
    low = text.lower()
    m = re.search(r"subject\s*[:;.-]?\s*([^\n]{3,40})", low)
    for area in ([m.group(1)] if m else []) + [low]:
        for key, words in SUBJECTS.items():
            # Whole words: "irs" is not "first".
            if any(re.search(rf"(?<![a-z]){re.escape(w)}(?![a-z])", area) for w in words):
                return key
    return "unclear"


def _topic(text: str) -> str:
    m = re.search(r"(?:topic|title|theme)\s*[:;.-]?\s*([^\n]{3,60})", text, re.I)
    if not m:
        return "unclear"
    topic = re.sub(r"[^A-Za-z0-9 ,'()-]", " ", m.group(1)).strip()
    return topic if _real_words(topic) else "unclear"


def _real_words(text: str) -> bool:
    """Read as real words (never a guess): mostly dictionary words, one of 4+ letters."""
    words = re.findall(r"[A-Za-z]{3,}", text)
    known = [w for w in words if w.lower() in _dictionary()]
    return bool(words) and len(known) / len(words) >= 0.6 and any(len(w) >= 4 for w in known)


_words_cache: set[str] | None = None


def _dictionary() -> set[str]:
    global _words_cache
    if _words_cache is None:
        _words_cache = {w.strip().lower() for w in open("/usr/share/dict/words")}
    return _words_cache


def ask_local(system: str, user: str, schema: dict, n_predict: int = 400) -> dict | None:
    """N-ATLaS on this Mac (llama.cpp), JSON constrained by [schema]; never a remote API."""
    import httpx

    from app.explain import render_llama31, today

    if not LLM.startswith(("http://127.0.0.1", "http://localhost")):
        raise SystemExit("LESSON_LLM_URL must be a model on this machine")
    r = httpx.post(f"{LLM}/completion", timeout=600, json={
        "prompt": render_llama31(system, user, today()), "temperature": 0, "n_predict": n_predict,
        "json_schema": schema})
    try:
        return json.loads(r.json()["content"])
    except (ValueError, KeyError):
        return None


def _model_labels(text: str) -> dict:
    schema = {"type": "object", "properties": {k: {"type": "string"} for k in ("subject", "class", "topic")},
              "required": ["subject", "class", "topic"]}
    out = ask_local(
        "You label photos of Nigerian primary school lesson notes. The text was read by OCR and "
        "may be garbled. Answer with words that appear in the text only; write unclear for "
        "anything the text does not show clearly.",
        f"OCR text:\n{text[:3000]}\n\nThe subject, the class (for example Basic 4) and the topic.", schema, 120)
    return out or {}


def label() -> None:
    rows = manifest()
    for r in rows:
        text = ocr_text(r["id"])
        found = {"subject": _subject(text), "class": _class(text), "topic": _topic(text)}
        if "unclear" in found.values():
            guess = _model_labels(text)
            low = text.lower()
            for key in found:
                value = str(guess.get(key, "")).strip()
                # The model's answer counts only if its words are on the page.
                if found[key] == "unclear" and value.lower() != "unclear" and _real_words(value) and all(
                        w.lower() in low for w in re.findall(r"[A-Za-z]{3,}", value)):
                    found[key] = {"subject": _subject(value), "class": _class(value)}.get(key, value)
        r.update(found)
    save_manifest(rows)
    print(f"labelled {len(rows)}: subject {sum(r['subject'] != 'unclear' for r in rows)}, "
          f"class {sum(r['class'] != 'unclear' for r in rows)}, topic {sum(r['topic'] != 'unclear' for r in rows)}")


def inventory() -> None:
    """One row per photo, then per note (subject, class, topic): no note text."""
    rows = manifest()
    for r in rows:
        print(f"{r['id']}  {r.get('subject', '?'):<18} {r.get('class', '?'):<9} {r['kind']:<11} "
              f"1 page  topic: {r.get('topic', '?')}")
    notes = defaultdict(list)
    for r in rows:
        notes[(r.get("subject"), r.get("class"), r.get("topic"))].append(r["id"])
    print(f"{len(rows)} photos (pages); {len(notes)} distinct subject/class/topic groups; "
          f"by class: {dict(Counter(r.get('class') for r in rows))}; "
          f"by kind: {dict(Counter(r['kind'] for r in rows))}")


# ---------- accuracy: typed vs handwritten

def _tokens(text: str) -> list[str]:
    return [t.lower() for t in re.findall(r"[A-Za-z]{3,}", text)]


def _edit_distance(a: list, b: list) -> int:
    row = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        prev, row[0] = row[0], i
        for j, y in enumerate(b, 1):
            prev, row[j] = row[j], min(row[j] + 1, row[j - 1] + 1, prev + (x != y))
    return row[-1]


def accuracy() -> None:
    """Without a typed transcript there is no true accuracy: what is measured is OCR confidence,
    the share of words read that are real words, and how much of the page the app would flag.
    With transcripts (WORK/transcripts/<id>.txt, typed by the team), word and character error
    rates too."""
    from app.main import checked

    dictionary = _dictionary()
    groups = defaultdict(lambda: Counter())
    for r in manifest():
        for engine, path in (("tesseract", WORK / f"{r['id']}.json"), ("trocr", WORK / f"{r['id']}.trocr.json")):
            if not path.exists():
                continue
            result = json.loads(path.read_text())
            g = groups[(r["kind"], engine)]
            words = words_of(result)
            toks = [t for w in words for t in _tokens(w["text"])]
            g["pages"] += 1
            g["lines"] += len(result["lines"])
            g["words"] += len(words)
            g["conf"] += sum(w["confidence"] for w in words)
            g["tokens"] += len(toks)
            g["real"] += sum(t in dictionary for t in toks)
            flagged = {w["block_index"] for w in checked(result)["warnings"]}
            g["flagged_lines"] += len(flagged)
            truth = WORK / "transcripts" / f"{r['id']}.txt"
            if truth.exists():
                want, got = truth.read_text().split(), " ".join(l["text"] for l in result["lines"]).split()
                g["truth_words"] += len(want)
                g["word_errors"] += _edit_distance(want, got)
                g["truth_chars"] += len(" ".join(want))
                g["char_errors"] += _edit_distance(list(" ".join(want)), list(" ".join(got)))
    for (kind, engine), g in sorted(groups.items()):
        line = (f"{kind:<11} {engine:<9} pages {g['pages']:>2}  lines {g['lines']:>4}  words {g['words']:>5}  "
                f"mean confidence {g['conf'] / max(1, g['words']):.2f}  real words {g['real'] / max(1, g['tokens']):.0%}  "
                f"lines flagged unclear {g['flagged_lines'] / max(1, g['lines']):.0%}")
        if g["truth_words"]:
            line += (f"  WER {g['word_errors'] / g['truth_words']:.0%}  CER {g['char_errors'] / g['truth_chars']:.0%}")
        print(line)
    if not any(g["truth_words"] for g in groups.values()):
        print("no transcripts yet: true accuracy needs typed transcripts in", WORK / "transcripts")


# ---------- quiz: DRAFT practice quizzes from the typed notes (local model, checked)

DRAFT = "DRAFT – needs teacher review"
NUMBER_WORDS = {"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
                "twelve", "twenty", "thirty", "forty", "fifty", "hundred", "thousand", "million", "half",
                "first", "second", "third", "fourth", "fifth"}
QUIZ_SCHEMA = {"type": "object", "properties": {"questions": {"type": "array", "minItems": 5, "maxItems": 10, "items": {
    "type": "object", "properties": {
        "question": {"type": "string"}, "A": {"type": "string"}, "B": {"type": "string"},
        "C": {"type": "string"}, "D": {"type": "string"}, "answer": {"enum": ["A", "B", "C", "D"]},
        "quote": {"type": "string"}},
    "required": ["question", "A", "B", "C", "D", "answer", "quote"]}}}, "required": ["questions"]}


def _norm(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", text.lower())).strip()


def _numbers(text: str) -> set[str]:
    low = text.lower()
    return set(re.findall(r"\d+(?:[.,/:]\d+)*", low)) | {w for w in re.findall(r"[a-z]+", low) if w in NUMBER_WORDS}


def check_question(q: dict, notes: str) -> str | None:
    """Why a drafted question is refused, or None. The answer must stand in the notes (its
    supporting sentence quoted from them, the right option's words in that sentence), and no
    number may appear that the notes don't have: the model invents nothing."""
    options = [q[k].strip() for k in "ABCD"]
    if len({_norm(o) for o in options}) < 4 or not all(options) or not q["question"].strip():
        return "options"
    quote, source = _norm(q["quote"]), _norm(notes)
    if len(quote.split()) < 3 or quote not in source:
        return "quote not in the notes"
    right = [w for w in _norm(q[q["answer"]]).split() if len(w) > 2] or _norm(q[q["answer"]]).split()
    if not right or sum(w in quote.split() for w in right) / len(right) < 0.6:
        return "answer not in the quote"
    if _numbers(" ".join([q["question"], *options])) - _numbers(notes):
        return "number not in the notes"
    if len(q["question"].split()) > 25:
        return "too long for 9-11 year olds"
    return None


def draft_quiz(notes: str, subject: str, level: str) -> tuple[list[dict], Counter]:
    out = ask_local(
        "You write practice quizzes for Nigerian primary school pupils aged 9 to 11. Use only facts "
        "stated in the lesson notes; never add a fact, name or number that is not in them. Short, "
        "plain words. Each question has four options A to D, exactly one correct. For each question, "
        "copy the sentence from the notes that gives the answer into quote, word for word.",
        f"Class: {level}. Subject: {subject}.\nLesson notes:\n{notes[:6000]}\n\n"
        "Write 5 to 10 multiple-choice questions.", QUIZ_SCHEMA, 2500)
    kept, refused = [], Counter()
    for q in (out or {}).get("questions", []):
        why = check_question(q, notes)
        if why:
            refused[why] += 1
        else:
            kept.append({**shuffled(q), "status": DRAFT})
    return kept, refused


def shuffled(q: dict) -> dict:
    """The model puts the right answer first: options in an order fixed by the question's text,
    so answers spread over A to D and a re-run gives the same sheet."""
    import hashlib
    import random

    options = [q[k] for k in "ABCD"]
    right = q[q["answer"]]
    random.Random(hashlib.sha256(q["question"].encode()).digest()).shuffle(options)
    return {**q, **dict(zip("ABCD", options)), "answer": "ABCD"[options.index(right)]}


def quiz() -> None:
    DRAFTS.mkdir(parents=True, exist_ok=True)
    groups = defaultdict(list)
    for r in manifest():
        if r["kind"] == "typed" and r.get("class") in ("Basic 4", "Basic 5"):
            groups[(r["class"], r.get("subject", "unclear"), r.get("topic", "unclear"))].append(r["id"])
    drafts, refused = [], Counter()
    for (level, subject, topic), ids in sorted(groups.items()):
        notes = "\n".join(ocr_text(i) for i in ids)
        kept, why = draft_quiz(notes, subject, level)
        refused += why
        drafts += [{**q, "class": level, "subject": subject, "topic": topic, "source": ", ".join(ids)} for q in kept]
    (DRAFTS / "lesson-quizzes.json").write_text(json.dumps(
        {"status": DRAFT, "approved": False, "questions": drafts}, ensure_ascii=False, indent=2))
    print(f"typed note groups: {len(groups)}; questions kept: {len(drafts)}; refused: {dict(refused)}")


# ---------- review: the spreadsheet for the teacher

def review(path: Path | None = None, data: dict | None = None) -> Path:
    from openpyxl import Workbook

    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
    from build_review_pack import CHECK, finish, sheet

    data = data or json.loads((DRAFTS / "lesson-quizzes.json").read_text())
    path = path or DRAFTS / "lesson-quiz-review.xlsx"
    wb = Workbook()
    ws = sheet(wb, "How to review", ["Practice quizzes from your lesson notes"], [100], first=True)
    for line in [DRAFT + ". None of these is in the Magana app until you approve it.",
                 "Each row is one question, made from your notes. Check the question, the four options and "
                 "the answer against the page named in Source.",
                 f"In '{CHECK}', choose yes if it is right as it is, or fix and write the correction in Fix.",
                 "Questions must suit pupils aged 9 to 11 and use only what your notes say."]:
        ws.append([line])
    finish(ws)
    for level in ("Basic 4", "Basic 5"):
        ws = sheet(wb, level, ["#", "Subject", "Topic", "Question", "A", "B", "C", "D", "Answer", "Source page",
                               "From the notes", "Status", CHECK, "Fix"],
                   [5, 16, 22, 40, 20, 20, 20, 20, 8, 12, 40, 18, 14, 30])
        for n, q in enumerate((q for q in data["questions"] if q["class"] == level), 1):
            ws.append([n, q["subject"], q["topic"], q["question"], q["A"], q["B"], q["C"], q["D"], q["answer"],
                       q["source"], q["quote"], q["status"], "", ""])
        finish(ws)
    wb.save(path)
    print(f"review sheet: {sum(q['class'] == 'Basic 4' for q in data['questions'])} Basic 4 and "
          f"{sum(q['class'] == 'Basic 5' for q in data['questions'])} Basic 5 questions")
    return path


if __name__ == "__main__":
    {"prepare": prepare, "label": label, "inventory": inventory, "accuracy": accuracy, "quiz": quiz,
     "review": review}[sys.argv[1]]()
