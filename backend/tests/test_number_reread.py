"""Every OCR engine must give every number its independent second reading from a crop
(CLAUDE.md rule 2). Fails if any engine in app.reader skips it, and the server refuses to
start with an engine that does."""
import inspect

import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

from app import reader
from app.main import app, get_engine
from app.reader import Line, Page, PaddleStructureEngine, TesseractEngine, Word

from tests.test_line_ends import page as rendered_page  # the label renderer the line-end tests use

LABEL = ["Paracetamol 500 mg tablets", "Take 2 tablets every 4 to 6 hours", "Do not take more than 8 in 24 hours"]


class PPOCRLike:
    """Stands in for PP-StructureV3 without paddle installed: one box and one score per text
    line, no word boxes, as PP-OCR returns them. Lines are located with Tesseract."""

    def predict(self, bgr):
        img = Image.fromarray(bgr[:, :, ::-1].copy())
        page = TesseractEngine().read(img)
        return [{"res": {
            "overall_ocr_res": {
                "rec_texts": [l.text for l in page.lines],
                "rec_scores": [0.95 for _ in page.lines],
                "rec_boxes": [[l.left, l.top, l.left + l.width, l.top + l.height] for l in page.lines],
            },
            "parsing_res_list": [], "table_res_list": [],
        }}]


# Every engine class in app.reader, and how to build it for the test.
ENGINES = {
    TesseractEngine: lambda: TesseractEngine(),
    PaddleStructureEngine: lambda: PaddleStructureEngine(pipeline=PPOCRLike()),
}


def test_every_engine_in_the_reader_is_covered_here():
    engines = {c for _, c in inspect.getmembers(reader, inspect.isclass)
               if c.__module__ == reader.__name__ and callable(getattr(c, "read", None))
               and c.__name__.endswith("Engine") and not getattr(c, "_is_protocol", False)}
    assert engines == set(ENGINES), "add every new OCR engine to ENGINES in this test"


@pytest.mark.parametrize("cls", list(ENGINES), ids=lambda c: c.__name__)
def test_every_number_is_reread_from_a_crop(cls):
    engine = ENGINES[cls]()
    img = rendered_page(LABEL)
    result = reader.read_page(img, engine)
    numbers = [w for line in result["lines"] for w in line["words"] if any(ch.isdigit() for ch in w["text"])]
    assert len(numbers) >= 6, numbers  # 500, 2, 4, 6, 8, 24
    assert all(w["reread_text"] is not None for w in numbers), [w for w in numbers if w["reread_text"] is None]
    agreeing = [w for w in numbers if w["reread_text"] == w["text"]]
    assert len(agreeing) >= len(numbers) - 1, numbers  # clean print: the readings agree


@pytest.mark.parametrize("cls", list(ENGINES), ids=lambda c: c.__name__)
def test_every_engine_passes_the_start_up_self_test(cls):
    reader.check_number_reread(ENGINES[cls]())


class Boxless:
    """An engine that reads numbers but gives no word boxes: it must be refused."""

    def read(self, image):
        return Page(lines=[Line("Take 2 tablets", 0.99, 50, words=[Word("Take", .99), Word("2", .99),
                                                                    Word("tablets", .99)])])


def test_an_engine_that_skips_the_reread_is_refused():
    with pytest.raises(reader.NumberRereadMissing):
        reader.check_number_reread(Boxless())


def test_the_server_refuses_to_start_with_such_an_engine():
    app.dependency_overrides.clear()
    get_engine.cache_clear()
    import app.main as main
    original = main.get_engine
    main.get_engine = lambda: Boxless()
    try:
        with pytest.raises(reader.NumberRereadMissing):
            with TestClient(app):
                pass
    finally:
        main.get_engine = original


def test_the_server_starts_with_tesseract():
    with TestClient(app) as c:
        assert c.get("/health").status_code == 200


def test_paddle_word_boxes_split_the_line_box_by_characters():
    words = reader._split_line_box("Take 2 tablets", 0.9, [100, 10, 240, 40])
    assert [w.text for w in words] == ["Take", "2", "tablets"]
    assert [(w.left, w.width) for w in words] == [(100, 40), (150, 10), (170, 70)]
    assert all((w.top, w.height) == (10, 30) for w in words)
