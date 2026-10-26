"""White paper reading fixes (boards 5c and 5d): two-column pages read column by column,
headings, words cut off at the photo's edge, and the Hausa / Yorùbá / Igbo letter check."""
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parents[1] / "scripts"))
import column_order_test as columns  # noqa: E402
import pagefont  # noqa: E402

from app import letters, reader  # noqa: E402
from app.reader import TesseractEngine, read_page  # noqa: E402

PAGE = columns.json.load(open(columns.PAGES))[0]


def page_text(page: dict) -> list[str]:
    return [l["text"] for l in page["lines"]]


def one_column(text: str, x: int = 100) -> Image.Image:
    lines = textwrap.wrap(text, 50)
    img = Image.new("RGB", (2000, 160 + 70 * len(lines)), "white")
    d = ImageDraw.Draw(img)
    for i, line in enumerate(lines):
        d.text((x, 80 + i * 70), line, fill="black", font=pagefont.font(40))
    return img


# ---------- columns and headings

def test_a_two_column_page_is_read_left_column_then_right_with_its_headings():
    img, truth, heads = columns.draw(PAGE)
    r = read_page(img, TesseractEngine())
    assert r["columns"] == 2
    assert columns.in_order(truth, r["lines"]) == 1.0
    text = page_text(r)
    assert text[0] == PAGE["title"]
    left_end = max(i for i, l in enumerate(r["lines"]) if l["column"] == 1)
    right_start = min(i for i, l in enumerate(r["lines"]) if l["column"] == 2)
    assert left_end < right_start  # every left-column line before any right-column line
    assert [l["text"] for l in r["lines"] if l["heading"]] == heads
    assert r["lines"][0]["column"] == 0  # the title runs across both columns


def test_before_the_fix_the_same_page_was_read_across_the_columns():
    img, truth, _ = columns.draw(PAGE)
    assert columns.in_order(truth, columns.read(img, with_layout=False)["lines"]) < 0.8


def test_a_one_column_page_keeps_exactly_its_order_and_has_no_headings():
    img = one_column("Take 1 to 2 tablets every 4 to 6 hours. Do not take more than 8 tablets in 24 hours. "
                     "Store below 30 degrees. Keep out of reach of children. Ask your pharmacist if you are not sure.")
    before = columns.read(img, with_layout=False)
    after = read_page(img, TesseractEngine())
    assert page_text(after) == page_text(before)
    assert after["columns"] == 1 and not any(l["heading"] for l in after["lines"])


def test_a_table_like_page_is_not_split_into_columns():
    """Short cells (dates, amounts) in wide columns are a table, not two columns of text."""
    rows = [("01/10/2026", "Transfer from Ada", "5,000.00", "12,400.00"),
            ("03/10/2026", "POS purchase", "2,350.00", "10,050.00"),
            ("05/10/2026", "Airtime", "500.00", "9,550.00"),
            ("08/10/2026", "Salary", "80,000.00", "89,550.00"),
            ("10/10/2026", "School fees", "45,000.00", "44,550.00"),
            ("12/10/2026", "Transfer to Musa", "3,000.00", "41,550.00"),
            ("15/10/2026", "Electricity", "6,200.00", "35,350.00")]
    img = Image.new("RGB", (2400, 700), "white")
    d = ImageDraw.Draw(img)
    for i, row in enumerate(rows):
        for x, cell in zip((100, 600, 1500, 1950), row):
            d.text((x, 80 + i * 75), cell, fill="black", font=pagefont.font(36))
    r = read_page(img, TesseractEngine())
    assert r["columns"] == 1
    assert page_text(r) == page_text(columns.read(img, with_layout=False))


# ---------- part of the page outside the photo

def test_text_cut_off_at_the_photos_edge_is_reported_and_a_framed_page_is_not():
    framed = one_column("Plants make their own food in their leaves. This is called photosynthesis.")
    assert not [t for t in read_page(framed, TesseractEngine())["tips"] if t.startswith("cut_off")]
    cut = one_column("Plants make their own food in their leaves. This is called photosynthesis.", x=100)
    cut = cut.crop((0, 0, 900, cut.height))  # the right of every line is outside the photo
    assert "cut_off_right" in read_page(cut, TesseractEngine())["tips"]


def test_cut_off_sides_from_word_boxes():
    page = reader.Page(lines=[reader.Line("ab", 0.9, 0, words=[reader.Word("ab", 0.9, 0, 50, 40, 20)]),
                              reader.Line("cd", 0.9, 0, words=[reader.Word("cd", 0.9, 500, 980, 60, 20)]),
                              reader.Line("e", 0.9, 0, words=[reader.Word("e", 0.9, 990, 500, 10, 20)])])
    img = Image.new("RGB", (1000, 1000), "white")
    assert reader.cut_off(img, page) == ["cut_off_bottom", "cut_off_left"]  # "e" is one character: ignored


# ---------- Hausa, Yorùbá and Igbo letters

HAUSA = ("Kasar Najeriya tana da dalibai da yawa a makaranta. Wannan kasa tana da jihohi talatin da shida. "
         "Yara suna zuwa makaranta kowace rana kuma suna koyon karatu da rubutu.")


def test_the_page_language_is_found_without_accents_and_english_is_not_taken_for_it():
    assert letters.page_language(HAUSA) == "ha"
    assert letters.page_language("Omo naa n sere ninu ogba. Awon omo ile iwe ati olukoni won wa nibe.") == "yo"
    assert letters.page_language("Umuaka na-agu akwukwo n'ulo akwukwo. Ndi nkuzi bu ndi oma, ha na-akuzi nke oma.") == "ig"
    assert letters.page_language("Plants make their own food in the leaves. This is called photosynthesis.") is None


def test_words_that_may_have_lost_a_letter_are_marked_and_never_changed():
    assert letters.may_miss_letter("kasar", "ha")  # ƙasar
    assert letters.may_miss_letter("dalibai,", "ha")  # ɗalibai, punctuation ignored
    assert not letters.may_miss_letter("ƙasar", "ha")  # read with its letter
    assert not letters.may_miss_letter("da", "ha")  # "da" (and) is nearly always written so: not marked
    assert not letters.may_miss_letter("makaranta", "ha")
    assert not letters.may_miss_letter("2026", "ha")
    assert letters.may_miss_letter("omo", "yo") and letters.may_miss_letter("umu", "ig")
    lines = [{"text": "Kasar tana da dalibai", "words": [{"text": w} for w in "Kasar tana da dalibai".split()]}]
    assert letters.marks(lines, "ha") == [{"block_index": 0, "word_index": 0, "kind": "special_letter"},
                                          {"block_index": 0, "word_index": 3, "kind": "special_letter"}]
    assert lines[0]["text"] == "Kasar tana da dalibai"


def test_a_hausa_page_gets_one_warning_and_marks_and_its_words_stay_as_read():
    img = one_column(HAUSA)
    engine = TesseractEngine()
    plain = [l.text for l in engine.read(img).lines]
    r = read_page(img, engine)
    assert r["page_language"] == "ha"
    assert r["tips"].count("letters_ha") == 1
    assert r["letter_marks"]
    assert page_text(r) == plain  # nothing "corrected"
    english = read_page(one_column("Plants make their own food in the leaves. This is called photosynthesis."), engine)
    assert english["page_language"] is None and "letter_marks" not in english
    assert not [t for t in english["tips"] if t.startswith("letters_")]


def test_yoruba_and_igbo_pages_are_read_again_with_the_better_model_when_installed(monkeypatch):
    eng = TesseractEngine()
    monkeypatch.setattr(reader, "_models", {"eng", "yor", "Latin"})
    assert reader._language_engine(eng, "yo").lang == "yor"
    assert reader._language_engine(eng, "ig").lang == "Latin"
    assert reader._language_engine(eng, "ha") is None  # no model keeps ɓ ɗ ƙ ƴ (measured)
    assert reader._language_engine(eng, None) is None
    monkeypatch.setattr(reader, "_models", {"eng"})
    assert reader._language_engine(eng, "yo") is None  # not installed: the first reading stays


def test_numbers_are_still_re_read_by_the_first_engine_on_a_language_page(monkeypatch):
    """The independent number re-read (CLAUDE.md rule 2) keeps the English engine."""
    used = []
    real = reader.reread_numbers
    monkeypatch.setattr(reader, "_models", {"eng", "yor", "Latin"})
    monkeypatch.setattr(reader, "reread_numbers", lambda image, page, engine: (used.append(engine.lang), real(image, page, engine)))
    calls = []
    real_read = TesseractEngine.read
    # The models may not be installed here: every reading uses eng, and the model asked for is logged.
    monkeypatch.setattr(TesseractEngine, "read", lambda self, image: (calls.append(self.lang), real_read(TesseractEngine(psm=self.psm), image))[1])
    img = one_column("Omo naa n sere ninu ogba ni ojo 12. Awon omo ile iwe ati olukoni won wa nibe ni ago 9.")
    read_page(img, TesseractEngine())
    assert calls[:2] == ["eng", "yor"]
    assert used == ["eng"]
