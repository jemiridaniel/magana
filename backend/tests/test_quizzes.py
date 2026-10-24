"""Teacher-made quizzes: drafts, the "Before you assign" checks, assigning, and what the
learner app gets for its class level."""
import pytest
from fastapi.testclient import TestClient

from app import quizzes
from app.main import app, get_quiz_store

client = TestClient(app)
TEACHER = {"X-Magana-Teacher-Key": "t-secret"}
LEARNER = {"X-Magana-Tier": "guided", "X-Magana-Guardian-Consent": "yes"}


@pytest.fixture(autouse=True)
def store(tmp_path, monkeypatch):
    monkeypatch.setenv("MAGANA_TEACHER_KEY", "t-secret")
    s = quizzes.QuizStore(tmp_path / "quizzes")
    app.dependency_overrides[get_quiz_store] = lambda: s
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
    r = client.post("/quizzes", json=body or plant_quiz(), headers=TEACHER)
    assert r.status_code == 201, r.text
    return r.json()


def codes(result):
    return [(p["code"], p["question"], p["blocking"]) for p in result["problems"]]


def test_a_draft_saves_and_lists_its_checks():
    made = create()
    assert made["quiz"]["status"] == "draft"
    assert codes(made) == [("quiz_translation_unchecked", 1, False)]
    listed = client.get("/quizzes", params={"class_id": "pri5"}, headers=TEACHER).json()
    assert [q["quiz"]["title"] for q in listed] == ["Parts of a plant"]


def test_writes_need_the_teacher_key_because_the_app_key_is_public():
    assert client.post("/quizzes", json=plant_quiz()).status_code == 401
    assert client.get("/quizzes").json()["detail"] == {"code": "teacher_key_required"}


def test_without_a_teacher_key_only_development_servers_accept_quizzes(monkeypatch):
    monkeypatch.delenv("MAGANA_TEACHER_KEY")
    monkeypatch.setenv("MAGANA_ENV", "production")
    r = client.post("/quizzes", json=plant_quiz())
    assert (r.status_code, r.json()["detail"]) == (503, {"code": "teacher_portal_off"})
    monkeypatch.setenv("MAGANA_ENV", "development")
    assert client.post("/quizzes", json=plant_quiz()).status_code == 201


def test_no_right_answer_or_an_undescribed_picture_blocks_assigning():
    q = plant_quiz()
    q["questions"][0]["answer"] = None
    q["questions"].append({"question": "What is this?", "options": ["A seed", "A stone"], "answer": 0,
                           "picture": {"name": "seed.jpg", "description": ""}})
    made = create(q)
    assert ("quiz_no_right_answer", 1, True) in codes(made)
    assert ("quiz_picture_needs_description", 2, True) in codes(made)
    r = client.post(f"/quizzes/{made['quiz']['id']}/assign", json={"session": "Thu 30 Oct 10:00"}, headers=TEACHER)
    assert r.status_code == 422
    assert r.json()["detail"]["code"] == "quiz_not_ready"


def test_primary_classes_get_at_most_three_options_and_a_word_hint():
    q = plant_quiz()
    q["questions"][0]["options"].append("The stem")
    q["questions"][0]["question"] = "In a green plant growing in the school garden, which part of the plant makes food?"
    made = create(q)
    assert ("quiz_too_many_options", 1, True) in codes(made)
    assert ("quiz_question_long", 1, False) in codes(made)
    # Four options are fine from JSS up.
    jss = plant_quiz(level="jss1", class_id="jss1", subject="basic_science")
    jss["questions"][0]["options"].append("The stem")
    assert all(p["code"] != "quiz_too_many_options" for p in create(jss)["problems"])


def test_the_class_level_and_subject_follow_the_curriculum():
    assert client.post("/quizzes", json=plant_quiz(level="p7"), headers=TEACHER).status_code == 422
    # Biology is an SSS subject; Basic Science is not.
    assert client.post("/quizzes", json=plant_quiz(subject="biology"), headers=TEACHER).status_code == 422
    assert client.post("/quizzes", json=plant_quiz(level="sss1", subject="basic_science"),
                       headers=TEACHER).status_code == 422


def test_assigned_quizzes_reach_learners_at_that_level_with_checked_translations_only(store):
    made = create()
    qid = made["quiz"]["id"]
    assert client.get("/learner/quizzes", params={"level": "p5"}, headers=LEARNER).json()["quizzes"] == []  # a draft
    assert client.post(f"/quizzes/{qid}/assign", json={"session": "Thu 30 Oct 10:00"},
                       headers=TEACHER).json()["quiz"]["status"] == "assigned"
    got = client.get("/learner/quizzes", params={"level": "p5"}, headers=LEARNER).json()["quizzes"]
    assert [q["title"] for q in got] == ["Parts of a plant"]
    assert got[0]["questions"][0]["translations"] == {}  # not yet checked
    assert got[0]["questions"][0]["explanation"] == "Well done! Leaves make food using sunlight."
    assert client.get("/learner/quizzes", params={"level": "p4"}, headers=LEARNER).json()["quizzes"] == []

    body = plant_quiz()
    body["questions"][0]["translations"]["yo"]["checked"] = True
    client.put(f"/quizzes/{qid}", json=body, headers=TEACHER)
    got = client.get("/learner/quizzes", params={"level": "p5"}, headers=LEARNER).json()["quizzes"]
    assert got[0]["questions"][0]["translations"] == {"yo": "Apá wo nínú ewéko ló ń ṣe oúnjẹ fún ewéko náà?"}


def test_editing_an_assigned_quiz_into_a_broken_one_unassigns_it():
    qid = create()["quiz"]["id"]
    client.post(f"/quizzes/{qid}/assign", json={"session": "s1"}, headers=TEACHER)
    body = plant_quiz()
    body["questions"][0]["answer"] = None
    assert client.put(f"/quizzes/{qid}", json=body, headers=TEACHER).json()["quiz"]["status"] == "draft"
    assert client.get("/learner/quizzes", params={"level": "p5"}, headers=LEARNER).json()["quizzes"] == []


def test_under_13_quizzes_only_in_a_teacher_run_session():
    r = client.get("/learner/quizzes", params={"level": "p3"}, headers={"X-Magana-Tier": "classroom"})
    assert (r.status_code, r.json()["detail"]) == (403, {"code": "teacher_session_required"})
    r = client.get("/learner/quizzes", params={"level": "p3"},
                   headers={"X-Magana-Tier": "classroom", "X-Magana-Teacher-Session": "yes"})
    assert r.status_code == 200


def test_unknown_quiz_and_level():
    assert client.get("/quizzes/abcdef123456", headers=TEACHER).json()["detail"] == {"code": "quiz_not_found"}
    assert client.get("/quizzes/../../etc", headers=TEACHER).status_code == 404
    assert client.get("/learner/quizzes", params={"level": "p9"}, headers=LEARNER).json()["detail"] == {
        "code": "unknown_level"}


def test_a_browser_may_save_changes_to_a_quiz_from_the_portal():
    r = client.options("/quizzes/abcdef123456", headers={
        "Origin": "http://localhost:3000", "Access-Control-Request-Method": "PUT",
        "Access-Control-Request-Headers": "content-type,x-magana-teacher-key"})
    assert r.status_code == 200
    assert "PUT" in r.headers["access-control-allow-methods"]
