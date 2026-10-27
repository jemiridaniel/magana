"""Handwriting (handwriting.py): which lines are handwritten, what that changes for numbers
and health papers, and the optional second reader. DRAFT: synthetic lines only until real
handwritten pages are measured (docs/FINDINGS.md)."""
import io
import json

import httpx
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

from app import handwriting, main, policy, safety
from app.main import app, get_engine
from app.reader import Line, Page, TesseractEngine, Word, read_page
from pagefont import font

client = TestClient(app)
ADULT = {"X-Magana-Tier": "standard"}


def printed_line(top=100, text="Take 2 tablets"):
    words = [Word(t, 0.95, 100 + i * 160, top, 140, 40) for i, t in enumerate(text.split())]
    return Line(text, 0.95, top, height=40, words=words, left=100, width=160 * len(words))


def handwritten_line(top=300, text="take 2 tabs daily", conf=0.6):
    # Heights and baselines wander, as handwriting does.
    sizes = [(0, 40), (12, 30), (-6, 52), (8, 36)]
    words = [Word(t, conf, 100 + i * 160, top + dy, 140, h) for i, (t, (dy, h)) in enumerate(zip(text.split(), sizes))]
    return Line(text, conf, top, height=50, words=words, left=100, width=640)


def test_printed_and_handwritten_lines_and_the_page():
    assert handwriting.classify(Page(lines=[printed_line(), printed_line(200)])) == "printed"
    page = Page(lines=[printed_line(), handwritten_line()])
    assert handwriting.classify(page) == "mixed"
    assert [l.script for l in page.lines] == ["printed", "handwritten"]
    assert handwriting.classify(Page(lines=[handwritten_line(), handwritten_line(400)])) == "handwritten"
    # Very unsure on its own counts too; a printed line read with some doubt doesn't.
    assert handwriting.is_handwritten(Line("x y", 0.4, 0, words=[Word("x", 0.4), Word("y", 0.4)]))
    regular_unsure = printed_line()
    for w in regular_unsure.words:
        w.confidence = 0.65
    assert not handwriting.is_handwritten(regular_unsure)


def test_a_real_printed_page_is_not_called_handwritten():
    img = Image.new("RGB", (1400, 500), "white")
    d = ImageDraw.Draw(img)
    for i, t in enumerate(["Take 2 tablets every 6 hours", "Do not take more than 8 in 24 hours",
                           "Store below 25 C"]):
        d.text((60, 60 + i * 120), t, fill="black", font=font(48))
    r = read_page(img, TesseractEngine())
    assert r["script"] == "printed" and not any(t.endswith("_page") for t in r["tips"])


def _dicts(*lines):
    from dataclasses import asdict
    return [asdict(l) for l in lines]


def test_a_handwritten_number_needs_two_agreeing_readings():
    line = handwritten_line(text="take 2 tabs daily", conf=0.6)
    line.script = "handwritten"
    line.words[1].confidence = 0.97  # one confident reading is not enough on handwriting
    warned = safety.number_warnings(_dicts(line))
    assert [(w.code, w.word_index) for w in warned] == [("low_confidence_number", 1)]
    line.words[1].reread_text, line.words[1].reread_confidence = "2", 0.85
    assert safety.number_warnings(_dicts(line)) == []
    line.words[1].reread_text = "7"
    assert [w.code for w in safety.number_warnings(_dicts(line))] == ["number_mismatch"]


class HandwrittenEngine:
    """Every read: a printed heading and a handwritten dose line."""

    def read(self, image):
        return Page(lines=[printed_line(40, "Prescription"), handwritten_line(200, "take 2 tabs 3x")])


def _post(mode):
    buf = io.BytesIO()
    Image.new("RGB", (900, 400), "white").save(buf, "PNG")
    app.dependency_overrides[get_engine] = HandwrittenEngine
    try:
        return client.post("/read", files={"file": ("p.png", buf.getvalue())}, data={"mode": mode}, headers=ADULT)
    finally:
        app.dependency_overrides.clear()


def test_on_a_health_paper_handwritten_numbers_are_never_read():
    body = _post("health").json()
    # A few handwritten-looking lines on a printed page: no "looks handwritten" page claim (it
    # fired on printed thermal slips and cards), but the prescription rule always holds.
    assert "mixed_page" not in body["tips"] and "handwritten_prescription" in body["tips"]
    hand = [i for i, l in enumerate(body["lines"]) if l["script"] == "handwritten"]
    flagged = {(w["block_index"], w["word_index"]) for w in body["warnings"] if w["code"] == "handwritten_number"}
    digits = {(i, j) for i in hand for j, w in enumerate(body["lines"][i]["words"]) if any(c.isdigit() for c in w["text"])}
    assert digits and digits <= flagged


def test_schoolwork_keeps_the_handwriting_number_rules_without_a_page_claim():
    body = _post("school").json()
    assert "mixed_page" not in body["tips"] and "handwritten_prescription" not in body["tips"]
    assert body["script"] == "mixed"
    assert any(l["script"] == "handwritten" for l in body["lines"])  # its numbers need two readings


class FakeReader:
    name = "fake"

    def __init__(self, text):
        self.text = text

    def read_line(self, crop):
        return self.text, 0.9


def test_a_second_reader_reads_handwritten_lines_and_tesseract_checks_its_numbers():
    page = Page(lines=[printed_line(), handwritten_line(text="tke 2 tbs dly")])
    handwriting.classify(page)
    page.lines[1].words[1].confidence = 0.85  # Tesseract was fairly sure of the 2 itself
    img = Image.new("RGB", (900, 500), "white")
    assert handwriting.reread_handwritten(img, page, FakeReader("take 2 tabs daily")) == 1
    hand = page.lines[1]
    assert (hand.text, hand.reader) == ("take 2 tabs daily", "fake")
    assert hand.words[1].reread_text == "2"  # Tesseract's own reading of that number
    assert page.lines[0].text == "Take 2 tablets"  # printed lines untouched
    assert safety.number_warnings(_dicts(hand)) == []  # both readings 2, both ≥ 0.80
    page = Page(lines=[handwritten_line(text="tke 2 tbs dly")])
    handwriting.classify(page)
    handwriting.reread_handwritten(img, page, FakeReader("take 7 tabs daily"))
    assert [w.code for w in safety.number_warnings(_dicts(page.lines[0]))] == ["number_mismatch"]


def test_the_optional_engine_is_schoolwork_only_and_azure_is_adults_only(monkeypatch):
    class Azure:
        name = "azure"
    main._handwriting_engine.cache_clear()
    monkeypatch.setattr(main, "_handwriting_engine", lambda: Azure())
    assert main.handwriting_reader("school", policy.Tier.STANDARD).name == "azure"
    assert main.handwriting_reader("school", policy.Tier.GUIDED) is None
    assert main.handwriting_reader("health", policy.Tier.STANDARD) is None
    monkeypatch.setattr(main, "_handwriting_engine", lambda: FakeReader("x"))
    assert main.handwriting_reader("school", policy.Tier.GUIDED).name == "fake"


def test_off_by_default(monkeypatch):
    monkeypatch.delenv("MAGANA_HANDWRITING", raising=False)
    assert handwriting.reader_from_env() is None
    monkeypatch.setenv("MAGANA_HANDWRITING", "azure")  # without its endpoint and key: still off
    monkeypatch.delenv("AZURE_VISION_KEY", raising=False)
    assert handwriting.reader_from_env() is None


def test_azure_read_response_is_parsed():
    def handler(request):
        assert request.headers["Ocp-Apim-Subscription-Key"] == "k"
        return httpx.Response(200, content=json.dumps({"readResult": {"blocks": [{"lines": [
            {"text": "take 2 tabs", "words": [{"text": "take", "confidence": 0.9}, {"text": "2", "confidence": 0.7},
                                              {"text": "tabs", "confidence": 0.95}]}]}]}}))
    reader = handwriting.AzureReadReader("https://x.cognitiveservices.azure.com", "k",
                                         client=httpx.Client(transport=httpx.MockTransport(handler)))
    assert reader.read_line(Image.new("RGB", (100, 30), "white")) == ("take 2 tabs", 0.7)
