"""Board 8 "Did you need help?": the daily totals a learner in a class shares (POST
/learner/progress) and the portal's "Done without sighted help" made from them."""
from datetime import timedelta

from fastapi.testclient import TestClient

from app import accounts
from app.main import app
from test_accounts import approved_school, fresh, new_class, phone  # noqa: F401


def joined(admin, tier="standard", device="d1"):
    cls = new_class(admin, mode="standard" if tier == "standard" else "guided")
    r = TestClient(app).post("/learner/join", json={"class_code": cls["code"]}, headers=phone(tier, device))
    [l] = admin.get(f"/portal/classes/{cls['id']}/learners").json()
    return r.json()["token"], l, cls


def share(token, days, tier="standard"):
    return TestClient(app).post("/learner/progress", json={"days": days},
                                headers={**phone(tier), "X-Magana-Learner": token})


def today(offset=0):
    return (accounts.now() + timedelta(days=offset)).date().isoformat()


def test_totals_make_the_done_without_help_figure(fresh):
    _, admin = approved_school(fresh)
    token, l, _ = joined(admin)
    assert admin.get(f"/portal/learners/{l['id']}").json()["term"]["unaided"] is None  # No answers yet
    assert share(token, {today(): {"pages": 4, "own": 3, "helped": 1}}).json() == {"code": "progress_shared", "days": 1}
    term = admin.get(f"/portal/learners/{l['id']}").json()["term"]
    assert (term["pages"], term["unaided"], term["answered"]) == (4, 75, 4)
    week = admin.get("/portal/home").json()["week"]
    assert (week["pages"], week["unaided"], week["answered"]) == (4, 75, 4)
    # Sent again (the phone sends its last 28 days each time): replaced, never counted twice.
    share(token, {today(): {"pages": 5, "own": 3, "helped": 2}})
    term = admin.get(f"/portal/learners/{l['id']}").json()["term"]
    assert (term["pages"], term["unaided"], term["answered"]) == (5, 60, 5)


def test_pages_without_answers_say_no_answers_yet(fresh):
    _, admin = approved_school(fresh)
    token, l, _ = joined(admin)
    share(token, {today(): {"pages": 6, "own": 0, "helped": 0}})
    term = admin.get(f"/portal/learners/{l['id']}").json()["term"]
    assert term["pages"] == 6 and term["unaided"] is None and term["answered"] == 0
    assert admin.get("/portal/home").json()["week"]["unaided"] is None


def test_only_an_active_class_link_may_share(fresh):
    _, admin = approved_school(fresh)
    # An under-18 waiting for consent: nothing is taken.
    token, l, _ = joined(admin, tier="guided", device="g1")
    r = share(token, {today(): {"pages": 1, "own": 1, "helped": 0}}, tier="guided")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "not_linked"
    admin.post(f"/portal/learners/{l['id']}/consent", json={"how": "in_person"})
    assert share(token, {today(): {"pages": 1, "own": 1, "helped": 0}}, tier="guided").status_code == 200
    # No link, or a Classroom session: refused.
    assert share("not-a-token", {today(): {"pages": 1}}).status_code == 403
    assert share(token, {today(): {"pages": 1}}, tier="classroom").status_code == 403


def test_only_totals_for_real_days(fresh):
    _, admin = approved_school(fresh)
    token, _, _ = joined(admin)
    for bad in ({"yesterday": {"pages": 1}}, {today(3): {"pages": 1}}, {today(-90): {"pages": 1}},
                {today(): {"pages": 1, "own": 999}}, {today(): {"pages": 1, "page_text": "Amoxicillin"}},
                {today(-i): {"pages": 1} for i in range(40)}):
        assert share(token, bad).status_code == 422, bad


def test_removing_a_learner_removes_their_days(fresh):
    _, admin = approved_school(fresh)
    token, l, _ = joined(admin)
    share(token, {today(): {"pages": 2, "own": 1, "helped": 1}})
    admin.post(f"/portal/learners/{l['id']}/remove", json={"reason": "deletion"})
    [d] = admin.get("/portal/deletions").json()
    admin.post(f"/portal/deletions/{d['id']}/confirm")
    with accounts.db() as con:
        assert con.execute("SELECT COUNT(*) FROM learner_days").fetchone()[0] == 0
