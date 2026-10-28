"""The school's address (board "Register your school (principal, with address)"): asked for at
registration, stored on the school, shown to the team and in their email, and edited by the
school's admins on School details, with each change in the audit log."""
import pytest
from fastapi.testclient import TestClient

from app import accounts, database
from app.main import app
from test_accounts import (APPROVE, PRINCIPAL, TEAM, approved_school, fresh, invite, lagos_ikeja,  # noqa: F401
                           outbox, sign_in)


def body(**extra) -> dict:
    state, lga = lagos_ikeja()
    return {"email": PRINCIPAL, "name": "Mrs Folake Adebayo", "role": "Principal", "phone": "0803 000 0001",
            "school": "Ikeja Community School", "state": state, "lga": lga, "agree": True,
            "address": "14 Allen Avenue", "town": "Ikeja", "landmark": "Opposite Ikeja City Mall", **extra}


def code(r) -> str:
    return r.json()["detail"]["code"]


@pytest.mark.parametrize("extra, expected", [
    ({"address": ""}, "address_required"),
    ({"address": "   "}, "address_required"),  # spaces only is empty
    ({"address": None}, None),
    ({"town": ""}, "town_required"),
    ({"address": "x" * 201}, "address_too_long"),
    ({"town": "x" * 101}, "town_too_long"),
    ({"landmark": "x" * 121}, "landmark_too_long"),
])
def test_registration_needs_the_address_and_town_within_their_lengths(fresh, extra, expected):
    b = body(**extra)
    if extra.get("address", "") is None:  # an older page that doesn't send it at all
        del b["address"]
        expected = "address_required"
    r = TestClient(app).post("/portal/schools/register", json=b)
    assert r.status_code == 400 and code(r) == expected
    with accounts.db() as con:
        assert con.execute("SELECT COUNT(*) FROM schools").fetchone()[0] == 0


def test_the_limits_themselves_are_allowed_the_landmark_is_optional_and_spaces_are_trimmed(fresh):
    r = TestClient(app).post("/portal/schools/register", json=body(
        address="  " + "a" * 200 + "  ", town=" " + "t" * 100 + " ", landmark=""))
    assert r.status_code == 201, r.text
    team = sign_in(fresh, TEAM)
    [s] = team.get("/portal/admin/schools").json()
    assert (s["address"], s["town"], s["landmark"]) == ("a" * 200, "t" * 100, "")


def test_the_team_sees_the_address_and_their_email_has_it_escaped(fresh):
    r = TestClient(app).post("/portal/schools/register", json=body(
        address=" 5 <b>Allen</b> & Co Road ", town="Ikeja GRA", landmark="Behind \"Mega\" Plaza"))
    assert r.status_code == 201, r.text
    team = sign_in(fresh, TEAM)
    [s] = team.get("/portal/admin/schools").json()
    assert (s["address"], s["town"], s["landmark"]) == ("5 <b>Allen</b> & Co Road", "Ikeja GRA", "Behind \"Mega\" Plaza")
    [mail] = [m for m in outbox(fresh, TEAM) if m["kind"] == "new_school_request"]
    assert "Address: 5 <b>Allen</b> & Co Road\nTown or area: Ikeja GRA\nNearest landmark: Behind \"Mega\" Plaza" in mail["text"]
    assert "5 &lt;b&gt;Allen&lt;/b&gt; &amp; Co Road" in mail["html"] and "<b>Allen</b>" not in mail["html"]
    assert "Behind &quot;Mega&quot; Plaza" in mail["html"] and ">Ikeja GRA<" in mail["html"]
    # Approved: still there for the approved list.
    team.post(f"/portal/admin/schools/{s['id']}", json=APPROVE)
    [a] = team.get("/portal/admin/schools?status=approved").json()
    assert a["address"] == "5 <b>Allen</b> & Co Road"


def test_the_team_email_says_not_given_when_there_is_no_landmark(fresh):
    TestClient(app).post("/portal/schools/register", json=body(landmark=""))
    [mail] = [m for m in outbox(fresh, TEAM) if m["kind"] == "new_school_request"]
    assert "Address: 14 Allen Avenue\nTown or area: Ikeja\nNearest landmark: Not given" in mail["text"]


def test_a_database_from_before_the_address_gets_empty_values(tmp_path, monkeypatch):
    """On SQLite and on Postgres (MAGANA_TEST_DATABASE_URL): the columns are added on first use."""
    monkeypatch.setenv("MAGANA_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("MAGANA_ENV", "development")
    accounts.reset_for_tests()
    con = database.connect()
    try:  # the schools table as the first release made it, with one school in it
        con.executescript("""
CREATE TABLE IF NOT EXISTS schools(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, state TEXT NOT NULL, lga TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending','approved','rejected')),
  contact_name TEXT, contact_role TEXT, contact_email TEXT, contact_phone TEXT,
  created_at TEXT NOT NULL, decided_at TEXT, decided_by TEXT);""")
        con.execute("INSERT INTO schools(id, name, state, lga, status, created_at) VALUES (?,?,?,?,?,?)",
                    ("sch_old", "Old School", "NG-LA", "NG-LA-IKEJA", "approved", "2026-01-05T09:00:00+00:00"))
        con.commit()
    finally:
        con.close()
    with accounts.db() as con:
        assert {"address", "town", "landmark"} <= database.columns(con, "schools")
        r = con.execute("SELECT address, town, landmark FROM schools WHERE id = 'sch_old'").fetchone()
        assert tuple(r) == ("", "", "")
        con.execute("INSERT INTO schools(id, name, state, lga, status, created_at) VALUES (?,?,?,?,?,?)",
                    ("sch_new", "New School", "NG-LA", "NG-LA-IKEJA", "pending", "2026-10-28T09:00:00+00:00"))
        assert tuple(con.execute("SELECT address, town, landmark FROM schools WHERE id = 'sch_new'").fetchone()) == ("", "", "")


def test_an_existing_school_without_an_address_shows_empty_values(fresh):
    sid, admin = approved_school(fresh)
    with accounts.db() as con:  # registered before the address was asked for
        con.execute("UPDATE schools SET address = '', town = '', landmark = '' WHERE id = ?", (sid,))
    s = admin.get("/portal/me").json()["school"]
    assert (s["address"], s["town"], s["landmark"]) == ("", "", "")
    [a] = sign_in(fresh, TEAM).get("/portal/admin/schools?status=approved").json()
    assert (a["address"], a["town"], a["landmark"]) == ("", "", "")


def test_school_admins_edit_the_address_with_the_same_checks_and_each_change_is_logged(fresh):
    sid, admin = approved_school(fresh)
    me = admin.get("/portal/me").json()["school"]
    assert (me["address"], me["town"], me["landmark"]) == ("14 Allen Avenue", "Ikeja", "Opposite Ikeja City Mall")
    for b, expected in [({"address": "", "town": "Ikeja"}, "address_required"),
                        ({"address": "1 Road", "town": "  "}, "town_required"),
                        ({"address": "x" * 201, "town": "Ikeja"}, "address_too_long"),
                        ({"address": "1 Road", "town": "x" * 101}, "town_too_long"),
                        ({"address": "1 Road", "town": "Ikeja", "landmark": "x" * 121}, "landmark_too_long")]:
        r = admin.patch("/portal/school", json=b)
        assert r.status_code == 400 and code(r) == expected
    r = admin.patch("/portal/school", json={"address": "  16 Allen Avenue ", "town": "Ikeja", "landmark": ""})
    assert r.json() == {"code": "school_details_saved",
                        "address": {"address": "16 Allen Avenue", "town": "Ikeja", "landmark": ""}}
    me = admin.get("/portal/me").json()["school"]
    assert (me["address"], me["town"], me["landmark"]) == ("16 Allen Avenue", "Ikeja", "")
    [entry] = [a for a in admin.get("/portal/audit").json() if a["action"] == "school_details_changed"]
    assert entry["target"] == sid and entry["actor_name"] == "Mrs Folake Adebayo"
    assert entry["detail"]["changes"] == [  # only what changed
        {"field": "School address", "before": "14 Allen Avenue", "after": "16 Allen Avenue"},
        {"field": "Nearest landmark", "before": "Opposite Ikeja City Mall", "after": ""}]
    # Saving the same again changes nothing and logs nothing.
    admin.patch("/portal/school", json={"address": "16 Allen Avenue", "town": "Ikeja"})
    assert len([a for a in admin.get("/portal/audit").json() if a["action"] == "school_details_changed"]) == 1
    # The team's activity log shows it too, with its label.
    items = sign_in(fresh, TEAM).get("/portal/admin/activity?action=school_details_changed").json()["items"]
    assert [(e["label"], e["about"].split(" · ")[0]) for e in items] == [("School details changed", "Ikeja Community School")]


def test_only_school_admins_edit_the_address(fresh):
    _, admin = approved_school(fresh)
    teacher = invite(admin, fresh, "teacher@gmail.com")
    r = teacher.patch("/portal/school", json={"address": "1 Road", "town": "Ikeja"})
    assert r.status_code == 403 and code(r) == "not_admin"
    assert TestClient(app).patch("/portal/school", json={"address": "1 Road", "town": "Ikeja"}).status_code == 401
