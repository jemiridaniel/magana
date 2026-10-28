"""Teacher-made quizzes: drafts, the "Before you assign" checks, assigning, and what the
learner app gets for its class level."""
import re

import pytest
from fastapi.testclient import TestClient

from app import blobs, quizzes
from app.main import app, get_quiz_store
from tests.test_accounts import approved_school, fresh, invite  # noqa: F401  (fixture)

client = TestClient(app)
LEARNER = {"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"}
T: TestClient = client  # the signed-in teacher (a school admin), set per test


@pytest.fixture(autouse=True)
def store(fresh, monkeypatch):
    global T
    s = quizzes.QuizStore()
    app.dependency_overrides[get_quiz_store] = lambda: s
    _, T = approved_school(fresh)
    yield s
    app.dependency_overrides.pop(get_quiz_store, None)


def plant_quiz(**over):
    q = {
        "title": "Parts of a plant",
        "class_id": "pri5",
        "level": "p5",
        "subject": "basic_science",
        "languages": ["en", "yo"],
        "questions": [
            {
                "question": "Which part of a plant makes food for the plant?",
                "options": ["The leaf", "The root", "The flower"],
                "answer": 0,
                "praise": "Well done! Leaves make food using sunlight.",
                "translations": {"yo": {"question": "Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?"}},
            }
        ],
    }
    q.update(over)
    return q


def create(body=None):
    r = T.post("/quizzes", json=body or plant_quiz())
    assert r.status_code == 201, r.text
    return r.json()


def codes(result):
    return [(p["code"], p["question"], p["blocking"]) for p in result["problems"]]


def test_a_draft_saves_and_lists_its_checks():
    made = create()
    assert made["quiz"]["status"] == "draft"
    assert codes(made) == [("quiz_translation_unchecked", 1, False)]
    listed = T.get("/quizzes", params={"class_id": "pri5"}).json()
    assert [q["quiz"]["title"] for q in listed] == ["Parts of a plant"]


def test_writes_need_a_signed_in_teacher_because_the_app_key_is_public():
    assert client.post("/quizzes", json=plant_quiz()).status_code == 401
    assert client.get("/quizzes").json()["detail"] == {"code": "not_signed_in"}


def test_teachers_see_only_their_own_quizzes_and_admins_the_schools(fresh):
    grace = invite(T, fresh, "grace.eze@gmail.com")
    musa = invite(T, fresh, "musa@gmail.com")
    g = grace.post("/quizzes", json=plant_quiz(title="Grace's")).json()["quiz"]
    musa.post("/quizzes", json=plant_quiz(title="Musa's"))
    assert [q["quiz"]["title"] for q in grace.get("/quizzes").json()] == ["Grace's"]
    assert musa.get(f"/quizzes/{g['id']}").status_code == 404
    assert musa.put(f"/quizzes/{g['id']}", json=plant_quiz()).status_code == 404
    assert sorted(q["quiz"]["title"] for q in T.get("/quizzes").json()) == ["Grace's", "Musa's"]


def test_session_codes_are_digits_stored_hashed_and_can_be_rotated(store, fresh):
    quiz = assign(create()["quiz"]["id"])
    code = quiz["session_code"]
    assert re.fullmatch(r"\d{6}", code)
    stored = "".join(blobs.get_text(kind, n) for kind in ("quiz", "quiz_codes") for n in blobs.names(kind))
    assert stored and code not in stored
    new = T.post(f"/quizzes/{quiz['id']}/rotate-session-code").json()["quiz"]["session_code"]
    assert new != code and in_session(code) == [] and len(in_session(new)) == 1


def test_no_right_answer_or_an_undescribed_picture_blocks_assigning():
    q = plant_quiz()
    q["questions"][0]["answer"] = None
    q["questions"].append({"question": "What is this?", "options": ["A seed", "A stone"], "answer": 0,
                           "picture": {"name": "seed.jpg", "description": ""}})
    made = create(q)
    assert ("quiz_no_right_answer", 1, True) in codes(made)
    assert ("quiz_picture_needs_description", 2, True) in codes(made)
    r = T.post(f"/quizzes/{made['quiz']['id']}/assign", json={"session": "Thu 30 Oct 10:00"})
    assert r.status_code == 422
    assert r.json()["detail"]["code"] == "quiz_not_ready"


def test_primary_1_to_3_get_at_most_three_options_primary_4_to_6_four_and_a_word_hint():
    q = plant_quiz(level="p2", class_id="pri2")
    q["questions"][0]["options"].append("The stem")
    q["questions"][0]["question"] = "In a green plant growing in the school garden, which part of the plant makes food?"
    made = create(q)
    assert ("quiz_too_many_options", 1, True) in codes(made)
    assert ("quiz_question_long", 1, False) in codes(made)
    # A–D from Primary 4 (Basic 4), as in JSS and SSS; five is too many anywhere.
    for level, class_id in (("p5", "pri5"), ("jss1", "jss1")):
        four = plant_quiz(level=level, class_id=class_id)
        four["questions"][0]["options"].append("The stem")
        assert all(p["code"] != "quiz_too_many_options" for p in create(four)["problems"])
        four["questions"][0]["options"].append("The seed")
        assert ("quiz_too_many_options", 1, True) in codes(create(four))


def test_the_class_level_and_subject_follow_the_curriculum():
    assert T.post("/quizzes", json=plant_quiz(level="p7")).status_code == 422
    # Biology is an SSS subject; Basic Science is not.
    assert T.post("/quizzes", json=plant_quiz(subject="biology")).status_code == 422
    assert T.post("/quizzes", json=plant_quiz(level="sss1", subject="basic_science")).status_code == 422


def in_session(code, tier="guided"):
    """The learner app inside a class session the teacher opened with [code]."""
    headers = {"X-Magana-Tier": tier, "X-Magana-Teacher-Session": "yes"}
    if tier == "guided":
        headers["X-Magana-Guardian-Consent"] = "yes"
    r = client.get("/learner/quizzes", params={"session_code": code}, headers=headers)
    assert r.status_code == 200, r.text
    return r.json()["quizzes"]


def assign(qid, session="Thu 30 Oct 10:00"):
    r = T.post(f"/quizzes/{qid}/assign", json={"session": session})
    assert r.status_code == 200, r.text
    return r.json()["quiz"]


def test_an_assigned_quiz_reaches_its_session_with_checked_translations_only():
    made = create()
    qid = made["quiz"]["id"]
    assert made["quiz"]["session_code"] is None  # a draft has no session
    quiz = assign(qid)
    assert quiz["status"] == "assigned"
    code = quiz["session_code"]
    assert re.fullmatch(r"\d{6}", code)
    got = in_session(code, tier="classroom")
    assert [q["title"] for q in got] == ["Parts of a plant"]
    assert got[0]["questions"][0]["translations"] == {}  # not yet checked
    assert got[0]["questions"][0]["explanation"] == "Well done! Leaves make food using sunlight."
    # Spaces as read out and typed on a phone.
    assert in_session(f" {code[:3]} {code[3:]} ", tier="classroom") == got

    body = plant_quiz()
    body["questions"][0]["translations"]["yo"]["checked"] = True
    T.put(f"/quizzes/{qid}", json=body)
    got = in_session(code, tier="classroom")
    assert got[0]["questions"][0]["translations"] == {"yo": "Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?"}


def test_teacher_a_quiz_never_reaches_a_learner_outside_a_class_or_session():
    # Teacher A: Primary 5, Thursday's session.
    a = assign(create(plant_quiz(title="A: plants", class_id="pri5"))["quiz"]["id"], "Thu 30 Oct 10:00")
    # Teacher B: another Primary 5 class, same level, same session name.
    b = assign(create(plant_quiz(title="B: plants", class_id="pri5-b"))["quiz"]["id"], "Thu 30 Oct 10:00")
    # Teacher A's next session.
    a2 = assign(create(plant_quiz(title="A: next week", class_id="pri5"))["quiz"]["id"], "Thu 6 Nov 10:00")
    assert len({a["session_code"], b["session_code"], a2["session_code"]}) == 3

    # Only A's session code opens A's quiz; the same level or session name is not enough.
    assert [q["title"] for q in in_session(a["session_code"])] == ["A: plants"]
    assert [q["title"] for q in in_session(b["session_code"])] == ["B: plants"]
    assert [q["title"] for q in in_session(a2["session_code"])] == ["A: next week"]
    assert in_session("730913") == []
    for tier in ("standard", "guided", "classroom"):
        assert "A: plants" not in [q["title"] for q in in_session(b["session_code"], tier=tier)]

    # A learner on their own (no teacher-opened session) gets nothing, for any age group.
    for headers in ({"X-Magana-Tier": "standard"},
                    {"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"}):
        r = client.get("/learner/quizzes", params={"session_code": a["session_code"]}, headers=headers)
        assert (r.status_code, r.json()["detail"]) == (403, {"code": "teacher_session_required"})
    # Nor by level, as before: that query no longer exists.
    r = client.get("/learner/quizzes", params={"level": "p5"}, headers=LEARNER)
    assert r.status_code == 422


def test_quizzes_in_the_same_class_session_share_one_code():
    one = assign(create()["quiz"]["id"], "Thu 30 Oct 10:00")
    two = assign(create(plant_quiz(title="Seeds"))["quiz"]["id"], "Thu 30 Oct 10:00")
    assert one["session_code"] == two["session_code"]
    assert sorted(q["title"] for q in in_session(one["session_code"])) == ["Parts of a plant", "Seeds"]


def test_editing_an_assigned_quiz_into_a_broken_one_takes_it_out_of_the_session():
    quiz = assign(create()["quiz"]["id"])
    body = plant_quiz()
    body["questions"][0]["answer"] = None
    edited = T.put(f"/quizzes/{quiz['id']}", json=body).json()["quiz"]
    assert (edited["status"], edited["session_code"]) == ("draft", None)
    assert in_session(quiz["session_code"]) == []


def test_a_malformed_code_and_an_unknown_quiz():
    assert T.get("/quizzes/abcdef123456").json()["detail"] == {"code": "quiz_not_found"}
    assert T.get("/quizzes/../../etc").status_code == 404
    r = client.get("/learner/quizzes", params={"session_code": "../x"},
                   headers={**LEARNER, "X-Magana-Teacher-Session": "yes"})
    assert r.json()["detail"] == {"code": "session_code_invalid"}


def test_a_browser_may_save_changes_to_a_quiz_from_the_portal():
    r = client.options("/quizzes/abcdef123456", headers={
        "Origin": "http://localhost:3000", "Access-Control-Request-Method": "PUT",
        "Access-Control-Request-Headers": "content-type,x-magana-teacher-key"})
    assert r.status_code == 200
    assert "PUT" in r.headers["access-control-allow-methods"]
