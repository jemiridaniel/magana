"""Critical numbers: per-word scoring, unreadable digits, and the two-pass cross-check.

The fixtures under fixtures/misreads are the pages where the dose "8 in 24 hours"
was really misread on the Android emulator and in development: as "6" (with 92%
and 64% word confidence) and as "@" or "&".
"""
import io
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import safety
from app.main import app

client = TestClient(app)
MISREADS = Path(__file__).parent / "fixtures" / "misreads"


def words(*pairs):
    return [{"text": t, "confidence": c} for t, c in pairs]


# ---------- unreadable numbers: non-digit characters where a number belongs

@pytest.mark.parametrize("text, index", [
    ("Do not lake more than @ in 24 hours", 5),   # real misread of 8
    ("Do not lake more than & in 24 hours", 5),   # real misread of 8
    ("Paracetamol 5O0 mg tablets", 1),
    ("Take 1l2 tablets", 1),
    ("Balance ₦38,75O", 1),
])
def test_non_digit_in_a_number_is_unreadable(text, index):
    assert safety.number_problem(text.split(), index) == "unreadable_number"


@pytest.mark.parametrize("text", [
    "COVID-19 vaccine card",
    "Vitamin B12 tablets",
    "Salt & sugar solution",
    "Questions & answers",
    "Discount 50 % today",
    "Expiry 08/2027",
])
def test_ordinary_words_and_numbers_are_not_flagged(text):
    tokens = text.split()
    assert all(safety.number_problem(tokens, i) is None for i in range(len(tokens)))


# ---------- per-word confidence: one shaky digit is not hidden by its line

def test_real_misread_6_at_64_percent_is_flagged_even_though_the_line_looks_fine():
    # Word confidences from the emulator photo (JPEG q88) that read 8 as 6.
    line = {"text": "Mo notiake more inan 6 in 24 hours", "confidence": 0.766, "label": "line 2",
            "words": words(("Mo", .87), ("notiake", .30), ("more", .93), ("inan", .76), ("6", .64),
                           ("in", .94), ("24", .95), ("hours", .74))}
    assert safety.confidence_warnings([line]) == []  # the old line-average rule missed it
    [w] = safety.number_warnings([line])
    assert (w.code, w.block_index, w.word_index) == ("low_confidence_number", 0, 4)


def test_real_misread_at_sign_is_flagged():
    line = {"text": "Do not lake more than @ in 24 hours", "confidence": 0.81,
            "words": words(("Do", .92), ("not", .88), ("lake", .87), ("more", .96), ("than", .70), ("@", .26),
                           ("in", .95), ("24", .95), ("hours", .83))}
    [w] = safety.number_warnings([line])
    assert (w.code, w.word_index) == ("unreadable_number", 5)


def test_confident_numbers_pass():
    line = {"text": "Take 2 tablets every 4 to 6 hours", "confidence": 0.95,
            "words": words(("Take", .95), ("2", .96), ("tablets", .95), ("every", .96), ("4", .93), ("to", .96),
                           ("6", .95), ("hours", .96))}
    assert safety.number_warnings([line]) == []


def test_threshold_is_090_per_word():
    line = {"text": "Take 2 tablets", "words": words(("Take", .99), ("2", .89), ("tablets", .99))}
    assert [w.code for w in safety.number_warnings([line])] == ["low_confidence_number"]
    line["words"][1]["confidence"] = 0.90
    assert safety.number_warnings([line]) == []


def test_table_cells_use_the_number_rules():
    tables = [{"label": "table 1", "rows": [[
        {"text": "Haemoglobin", "confidence": 0.80, "row": 1, "col": 0},
        {"text": "11.2 g/dL", "confidence": 0.85, "row": 1, "col": 1},
        {"text": "12.O - 16.0", "confidence": 0.99, "row": 1, "col": 2},
    ]]}]
    got = [(w.col, w.code) for w in safety.cell_number_warnings(tables)]
    assert got == [(1, "low_confidence_number"), (2, "unreadable_number")]


# ---------- second pass: the two readings must agree on every number

def test_real_misread_6_at_92_percent_is_caught_by_the_second_pass():
    # The original faint page: "6" at 92% passes the per-word threshold on its own.
    first = {"lines": [{"text": "Paracetamol 500 mg tablets", "top": 69, "label": "line 1"},
                       {"text": "o not take more inan 6 in 24 pours", "top": 216, "label": "line 2"}]}
    second = {"lines": [{"text": "Paracetamol 500 mg tablets", "top": 103},
                        {"text": "Do not take more than 8 in 24 hours", "top": 324}]}
    lines, cells = safety.number_mismatches(first, second, scale=1.5)
    assert [(w.block_index, w.code) for w in lines] == [(1, "number_mismatch")]
    assert cells == []


def test_matching_passes_raise_nothing():
    page = {"lines": [{"text": "Take 2 tablets every 4 to 6 hours", "top": 10}]}
    assert safety.number_mismatches(page, page) == ([], [])


def test_a_number_only_the_second_pass_saw_flags_the_nearest_line():
    first = {"lines": [{"text": "Balance", "top": 10}, {"text": "Amount due", "top": 100}]}
    second = {"lines": [{"text": "Amount due 6,450.00", "top": 150}]}
    lines, _ = safety.number_mismatches(first, second, scale=1.5)
    assert [w.block_index for w in lines] == [1]


def test_cells_are_cross_checked():
    first = {"lines": [], "tables": [{"top": 0, "rows": [[{"text": "11.2", "row": 1, "col": 1}]]}]}
    second = {"lines": [], "tables": [{"top": 0, "rows": [[{"text": "17.2", "row": 1, "col": 1}]]}]}
    _, cells = safety.number_mismatches(first, second)
    assert [(c.row, c.col, c.code) for c in cells] == [(1, 1, "number_mismatch")]


# ---------- regression: the real misread photos through /read

def _dose_line_flagged(body: dict) -> bool:
    flagged = {w["block_index"] for w in body["warnings"]}
    return any(i in flagged for i, l in enumerate(body["lines"]) if "24" in l["text"])


@pytest.mark.parametrize("name", ["dose_faint.png", "dose_faint_q88.jpg", "dose_broken_q88.jpg", "dose_broken_q85.jpg"])
def test_misread_dose_photos_never_pass_silently_in_health_mode(name):
    """Whatever this Tesseract build reads, the dose line is either exactly right or flagged."""
    data = (MISREADS / name).read_bytes()
    body = client.post("/read", files={"file": (name, data)}, data={"mode": "health"}).json()
    dose = next((l for l in body["lines"] if "24" in l["text"]), None)
    if dose is None:
        pytest.skip("this Tesseract build dropped the dose line entirely (covered by faint-text checks)")
    read_correctly = " 8 in 24 " in f" {dose['text']} " and all(
        w["confidence"] >= safety.CRITICAL_WORD_THRESHOLD for w in dose["words"] if any(ch.isdigit() for ch in w["text"]))
    assert read_correctly or _dose_line_flagged(body), dose


@pytest.mark.parametrize("name", ["dose_faint.png", "dose_faint_q88.jpg", "dose_broken_q88.jpg", "dose_broken_q85.jpg"])
def test_misread_dose_photos_are_flagged_in_school_mode_without_a_second_pass(name):
    # dose_faint.png ("6" at 92%) is caught by re-reading the number's crop, in every mode.
    data = (MISREADS / name).read_bytes()
    body = client.post("/read", files={"file": (name, data)}, data={"mode": "school"}).json()
    dose = next(l for l in body["lines"] if "24" in l["text"])
    assert " 8 in 24 " in f" {dose['text']} " or _dose_line_flagged(body), dose


def test_second_pass_only_runs_for_health_and_money(monkeypatch):
    calls = []
    import app.main as main

    class Engine:
        def read(self, image):
            from app.reader import Line, Page
            calls.append(image.size)
            return Page(lines=[Line("Take 2 tablets", 0.99, 0)])

    app.dependency_overrides[main.get_engine] = lambda: Engine()
    try:
        # A blank page: no ink bands, so the faint-text retry never calls the engine.
        buf = io.BytesIO(); Image.new("RGB", (400, 300), "white").save(buf, "PNG"); data = buf.getvalue()
        for mode, expected in [("school", 1), ("health", 2), ("money", 2)]:
            calls.clear()
            client.post("/read", files={"file": ("p.png", data)}, data={"mode": mode})
            assert len(calls) == expected, mode
    finally:
        app.dependency_overrides.clear()


# ---------- re-reading each number's crop, in every mode

def reread_line(*words):
    """words: (text, confidence, reread_text)"""
    return {"text": " ".join(w[0] for w in words), "confidence": 0.95,
            "words": [{"text": t, "confidence": c, "reread_text": r} for t, c, r in words]}


def test_two_readings_that_disagree_are_flagged():
    line = reread_line(("than", .96, None), ("6", .95, "8"), ("in", .96, None), ("24", .95, "24"))
    [w] = safety.number_warnings([line])
    assert (w.code, w.word_index) == ("number_mismatch", 1)


def test_a_number_the_second_reading_cannot_find_is_flagged():
    line = reread_line(("than", .96, None), ("6", .95, ""))
    assert [w.code for w in safety.number_warnings([line])] == ["number_mismatch"]


def test_agreeing_readings_pass():
    line = reread_line(("Balance", .96, None), ("N38,750.00", .93, "N38,750.00"))
    assert safety.number_warnings([line]) == []


def test_punctuation_differences_are_not_disagreements():
    line = reread_line(("Range", .96, None), ("12.0", .95, "12.0."), ("16.0", .95, "16.0"))
    assert safety.number_warnings([line]) == []


def _render(lines, size):
    from PIL import ImageDraw, ImageFont
    img = Image.new("RGB", (1500, 100 + 70 * len(lines)), "white")
    d = ImageDraw.Draw(img)
    for name in ("DejaVuSans.ttf", "Arial.ttf"):
        try:
            font = ImageFont.truetype(name, size)
            break
        except OSError:
            continue
    else:
        font = ImageFont.load_default(size=size)
    for i, t in enumerate(lines):
        d.text((50, 40 + 70 * i), t, fill="black", font=font)
    buf = io.BytesIO(); img.save(buf, "PNG"); return buf.getvalue()


LABEL = ["Paracetamol 500 mg tablets", "Take 2 tablets every 4 to 6 hours.",
         "Do not take more than 8 in 24 hours.", "Expiry 08/2027  Batch PCM2291"]


@pytest.mark.parametrize("size", [40, 28])
def test_a_clean_label_raises_no_number_warnings(size):
    body = client.post("/read", files={"file": ("p.png", _render(LABEL, size))}, data={"mode": "school"}).json()
    number = {"number_mismatch", "low_confidence_number", "unreadable_number"}
    assert [w for w in body["warnings"] if w["code"] in number] == []


def test_numbers_are_reread_in_every_mode():
    for mode in ("school", "health", "money"):
        body = client.post("/read", files={"file": ("p.png", _render(LABEL, 40))}, data={"mode": mode}).json()
        numbers = [w for l in body["lines"] for w in l["words"] if any(c.isdigit() for c in w["text"])]
        assert numbers and all(w["reread_text"] is not None for w in numbers), mode


# ---------- two agreeing readings at 0.80 (pending clinical sign-off)

def pair(conf, reread, reread_conf, text="N12,000.00"):
    return {"text": f"Transfer {text}", "confidence": 0.9,
            "words": [{"text": "Transfer", "confidence": .96},
                      {"text": text, "confidence": conf, "reread_text": reread, "reread_confidence": reread_conf}]}


def test_n12000_two_agreeing_readings_are_accepted():
    # Real readings of "N12,000.00" in 28 px print: 0.88 on the page, 0.90 re-read.
    assert safety.number_warnings([pair(.88, "N12,000.00", .90)]) == []


def test_n12000_a_single_088_reading_is_still_flagged():
    [w] = safety.number_warnings([pair(.88, None, None)])
    assert w.code == "low_confidence_number"


@pytest.mark.parametrize("conf, reread_conf, flagged", [
    (.80, .80, False),   # both at the floor: accepted
    (.79, .95, True),    # page reading too weak
    (.95, .79, False),   # page reading alone reaches 0.90
    (.85, .79, True),    # re-read too weak, page reading below 0.90
    (.89, .89, False),
])
def test_two_reading_thresholds(conf, reread_conf, flagged):
    warnings = safety.number_warnings([pair(conf, "N12,000.00", reread_conf)])
    assert bool(warnings) == flagged


def test_agreement_at_any_confidence_never_overrides_a_disagreement():
    [w] = safety.number_warnings([pair(.99, "N12,600.00", .99)])
    assert w.code == "number_mismatch"


def test_thresholds_are_the_documented_ones():
    assert (safety.CRITICAL_WORD_THRESHOLD, safety.TWO_READING_THRESHOLD) == (0.90, 0.80)


STATEMENT = ["POS purchase 14/10/2026  N6,450.00", "Transfer to Amina Bello  N12,000.00", "Balance N38,750.00"]


def test_n12000_in_small_print_is_not_flagged_end_to_end():
    """The real case: 28 px statement, where N12,000.00 reads 0.88 alone."""
    body = client.post("/read", files={"file": ("p.png", _render(STATEMENT, 28))}, data={"mode": "money"}).json()
    line = next(i for i, l in enumerate(body["lines"]) if "12,000" in l["text"])
    word = next(w for w in body["lines"][line]["words"] if "12,000" in w["text"])
    if word["confidence"] >= safety.CRITICAL_WORD_THRESHOLD:
        pytest.skip("this Tesseract build reads it at 0.90+ already")
    assert safety._digits(word["reread_text"]) == safety._digits(word["text"])
    assert not [w for w in body["warnings"] if w["block_index"] == line and w["code"] == "low_confidence_number"]
