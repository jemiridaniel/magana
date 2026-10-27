"""Small items and torn, faint slips (the iPhone test of 27 Oct 2026; docs/FINDINGS.md), on
synthetic stand-ins (capture_fixtures.py): no real photo is in the repository."""
import io

from fastapi.testclient import TestClient

import capture_fixtures as cf
from app import safety
from app.main import app, checked
from app.reader import TesseractEngine, edge_cuts, flatten_contrast, read_page

client = TestClient(app)


def jpeg(img) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=90)
    return buf.getvalue()


def test_a_small_card_on_a_wall_is_read_whole_without_false_warnings():
    r = checked(read_page(cf.small_card()))
    assert [l["text"] for l in r["lines"]] == cf.CARD_LINES
    assert r["warnings"] == []
    # Normal-size print: never "move closer"; the wall is not a cut or torn edge.
    assert not {"small_print", "edge_cut_left", "edge_cut_right", "faint_print"} & set(r["tips"])


def test_plain_ocr_reads_nothing_on_the_faint_slip_and_flattening_finds_it():
    """What failed on the phone: grey thermal print on grey-white paper on a dark table."""
    engine = TesseractEngine()
    plain = [w for l in engine.read(cf.thermal_slip()).lines for w in l.words]
    flat = [w for l in engine.read(flatten_contrast(cf.thermal_slip())).lines for w in l.words]
    assert len(plain) == 0 and len(flat) >= 15


def test_the_torn_faint_slip_is_read_and_says_the_left_edge_is_cut():
    body = client.post("/read", files={"file": ("slip.jpg", jpeg(cf.thermal_slip()))}).json()
    assert body["tips"][:2] == ["edge_cut_left", "faint_print"] or {"edge_cut_left", "faint_print"} <= set(body["tips"])
    text = " ".join(l["text"] for l in body["lines"])
    for part in ("ABUJA ABV", "TEST/ADA", "06:45", "7123"):
        assert part in text
    # What the tear cut is read as it is, never repaired: no "BOARDING" made up.
    assert "BOARDING" not in text
    # The number rules still hold: every number is either sure (two agreeing readings) or flagged.
    flagged = {(w["block_index"], w["word_index"]) for w in body["warnings"] if w["code"] in safety.NUMBER_CODES}
    for i, line in enumerate(body["lines"]):
        for j, w in enumerate(line["words"]):
            if any(ch.isdigit() for ch in w["text"]) and (i, j) not in flagged:
                assert safety.number_accepted({**w, "reread_confidence": w.get("reread_confidence")}), w


def test_the_message_codes_are_words_in_every_language():
    from app import messages
    for code in ("edge_cut_left", "edge_cut_right", "faint_print"):
        assert code in messages.ENGLISH


def test_ordinary_pages_are_not_called_torn():
    from PIL import Image, ImageDraw

    import pagefont
    img = Image.new("RGB", (1400, 600), "white")
    d = ImageDraw.Draw(img)
    for i, t in enumerate(["Take 2 tablets every 6 hours", "Do not take more than 8 in 24 hours", "Keep out of reach"]):
        d.text((140, 80 + 120 * i), t, fill="black", font=pagefont.font(40))
    page = TesseractEngine().read(img)
    assert edge_cuts(img, page) == []


def test_a_phone_photo_saved_sideways_with_its_orientation_tag_is_read_upright():
    """Phone cameras often store the pixels sideways and an EXIF orientation tag (6: turn 90°
    clockwise to view). The server used to read the sideways pixels."""
    from PIL import Image, ImageDraw

    import pagefont
    page = Image.new("RGB", (1200, 500), "white")
    d = ImageDraw.Draw(page)
    for i, t in enumerate(["Take 2 tablets every 6 hours", "Do not take more than 8 in 24 hours"]):
        d.text((60, 80 + 140 * i), t, fill="black", font=pagefont.font(44))
    sideways = page.rotate(90, expand=True)  # what the camera stored
    exif = Image.Exif()
    exif[0x0112] = 6
    body = client.post("/read", files={"file": ("p.jpg", jpeg_with_exif(sideways, exif))}).json()
    assert [l["text"] for l in body["lines"]] == ["Take 2 tablets every 6 hours", "Do not take more than 8 in 24 hours"]


def jpeg_with_exif(img, exif) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=92, exif=exif)
    return buf.getvalue()
