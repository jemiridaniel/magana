"""Teachers' uploads (uploads_api.py): only the text is kept; handwriting or doubt means
"check" until the teacher corrects and approves it; teachers see only their own."""
import io
import json

from PIL import Image, ImageDraw

from app.reader import Page
from pagefont import font
from test_accounts import approved_school, everything_in_db, fresh, invite, new_class  # noqa: F401
from test_handwriting import handwritten_line, printed_line


def page_png(lines):
    img = Image.new("RGB", (1400, 140 + 110 * len(lines)), "white")
    d = ImageDraw.Draw(img)
    for i, t in enumerate(lines):
        d.text((60, 60 + i * 110), t, fill="black", font=font(48))
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def test_a_printed_upload_is_ready_and_keeps_only_text(fresh):
    _, admin = approved_school(fresh)
    cls = new_class(admin)
    png = page_png(["Photosynthesis", "Plants make food from light"])
    r = admin.post("/portal/uploads", files={"file": ("notes.png", png, "image/png")},
                   data={"class_id": cls["id"], "title": "Biology notes"})
    assert r.status_code == 201, r.text
    up = r.json()["upload"]
    assert (r.json()["code"], up["status"], up["script"]) == ("upload_saved", "ready", "printed")
    got = admin.get(f"/portal/uploads/{up['id']}").json()
    assert [l["text"] for l in got["lines"]] == ["Photosynthesis", "Plants make food from light"]
    assert [u["title"] for u in admin.get("/portal/uploads").json()] == ["Biology notes"]
    # The file itself is nowhere: not in the database, not on disk.
    assert png[:64].hex() not in everything_in_db(fresh)
    assert not [p for p in fresh.rglob("*") if p.suffix.lower() in {".png", ".jpg", ".pdf"}]


class MixedEngine:
    """The whole page: a printed heading and a handwritten line. Crops (re-reads): nothing."""

    calls = 0

    def read(self, image):
        MixedEngine.calls += 1
        if MixedEngine.calls > 1:
            return Page()
        return Page(lines=[printed_line(40, "Homework"), handwritten_line(200, "Ansa 4 qestions")])


def test_handwriting_stays_at_check_until_the_teacher_corrects_and_approves(fresh, monkeypatch):
    from app import main

    _, admin = approved_school(fresh)
    MixedEngine.calls = 0
    monkeypatch.setattr(main, "get_engine", MixedEngine)
    r = admin.post("/portal/uploads", files={"file": ("hw.png", page_png(["x"]), "image/png")})
    up = r.json()["upload"]
    assert (up["status"], up["note"], up["script"]) == ("check", "handwriting", "mixed")
    got = admin.get(f"/portal/uploads/{up['id']}").json()
    assert [l["handwritten"] for l in got["lines"]] == [False, True]
    assert {"low_confidence_number", "number_mismatch"} & set(got["lines"][1]["flags"])
    home = admin.get("/portal/home").json()
    assert any(a["kind"] == "upload_check" and a["upload"]["id"] == up["id"] for a in home["attention"])

    r = admin.put(f"/portal/uploads/{up['id']}", json={"lines": ["Homework", "Answer 4 questions"]})
    assert (r.json()["code"], r.json()["upload"]["status"]) == ("upload_corrections_saved", "check")
    assert admin.put(f"/portal/uploads/{up['id']}", json={"lines": ["one"]}).json()["detail"]["code"] == \
        "upload_lines_changed"
    r = admin.put(f"/portal/uploads/{up['id']}", json={"lines": ["Homework", "Answer 4 questions"], "approve": True})
    done = r.json()["upload"]
    assert (r.json()["code"], done["status"]) == ("upload_approved", "ready")
    assert done["lines"][1] | {} == {**done["lines"][1], "text": "Answer 4 questions", "corrected": True}
    audit = [a["action"] for a in admin.get("/portal/audit").json()]
    assert {"upload_added", "upload_corrected", "upload_approved"} <= set(audit)


def test_a_teacher_sees_only_their_own_uploads(fresh):
    _, admin = approved_school(fresh)
    teacher = invite(admin, fresh, "grace.eze@yahoo.com")
    up = teacher.post("/portal/uploads", files={"file": ("a.png", page_png(["Read page 4"]), "image/png")}).json()["upload"]
    other = invite(admin, fresh, "musa.bello@gmail.com")
    assert other.get(f"/portal/uploads/{up['id']}").status_code == 404
    assert other.get("/portal/uploads").json() == []
    assert admin.get(f"/portal/uploads/{up['id']}").status_code == 200  # a school admin sees the school's


def test_unreadable_and_empty_files(fresh):
    _, admin = approved_school(fresh)
    r = admin.post("/portal/uploads", files={"file": ("x.png", b"not an image", "image/png")})
    assert r.json()["detail"]["code"] == "upload_unreadable"
    buf = io.BytesIO()
    Image.new("RGB", (600, 400), "white").save(buf, "PNG")
    r = admin.post("/portal/uploads", files={"file": ("blank.png", buf.getvalue(), "image/png")})
    assert r.json()["detail"]["code"] == "upload_no_text"
