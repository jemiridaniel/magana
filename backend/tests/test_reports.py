"""Report a problem (board 9, reports_api.py): what a report may hold, voice notes for adults
only, page text only when switched on and never from a Classroom session, the email to support,
and the team's Reports list (Support can view)."""
import base64

import pytest
from fastapi.testclient import TestClient

from app.main import app
from test_accounts import TEAM, fresh, make_team, outbox, sign_in  # noqa: F401

client = TestClient(app)
VOICE = base64.b64encode(b"\x00\x00\x00\x18ftypM4A " + b"\x00" * 2000).decode()


def report(tier="standard", **extra):
    body = {"kind": "read_wrong", "screen": "reader", "app_version": "0.1.0+6", "phone_model": "TECNO KI5q",
            "language": "ha", **extra}
    return client.post("/reports", json=body, headers={"X-Magana-Tier": tier, "X-Magana-Device": "dev-r1"})


def test_a_report_reaches_support_and_the_reports_list(fresh):
    r = report(page_text="Paracetamol 500 mg", voice_note=VOICE, voice_type="audio/mp4", voice_seconds=12)
    assert r.status_code == 201 and r.json()["code"] == "report_sent"
    [mail] = outbox(fresh, "support@magana.ng")
    assert mail["kind"] == "problem_report" and mail["subject"] == "Problem report: It read something wrong"
    assert "TECNO KI5q" in mail["text"] and "12 s, in the portal" in mail["text"] and "Included, in the portal" in mail["text"]
    assert "Paracetamol" not in mail["text"] + mail["html"]  # the page text stays in the portal
    for role, email in (("support", "support.person@magana.test"), ("owner", TEAM)):
        if role == "support":
            make_team(email, "support", name="Support Person")
        team = sign_in(fresh, email)
        [row] = team.get("/portal/admin/reports").json()
        assert (row["kind_label"], row["screen"], row["app_version"], row["phone_model"], row["language"],
                row["age_group"], row["page_text"], row["voice_seconds"]) == (
            "It read something wrong", "reader", "0.1.0+6", "TECNO KI5q", "ha", "18+", "Paracetamol 500 mg", 12)
        voice = team.get(f"/portal/admin/reports/{row['id']}/voice")
        assert voice.status_code == 200 and voice.headers["content-type"] == "audio/mp4"
        assert voice.headers["cache-control"] == "no-store"
    entries = team.get("/portal/admin/activity", params={"action": "team_report_voice_played"}).json()["items"]
    assert len(entries) == 2 and entries[0]["label"] == "Played a voice note"


def test_page_text_is_off_unless_sent_and_photos_are_refused():
    assert report().status_code == 201
    assert report(photo="iVBORw0KGgo=").status_code == 422  # no photo field, ever
    assert report(name="Amina").status_code == 422


@pytest.mark.parametrize("tier", ["guided", "classroom"])
def test_under_18s_send_no_voice_note(tier):
    r = report(tier=tier, voice_note=VOICE, voice_type="audio/mp4", voice_seconds=5)
    assert r.status_code == 403 and r.json()["detail"]["code"] == "voice_note_adults_only"
    assert report(tier=tier).status_code == 201  # a choice from the list is fine


def test_no_page_text_from_a_classroom_session():
    assert report(tier="classroom", page_text="Food tests").status_code == 403
    assert report(tier="guided", page_text="Food tests").status_code == 201


def test_voice_notes_are_60_seconds_at_most():
    assert report(voice_note=VOICE, voice_type="audio/mp4", voice_seconds=61).status_code == 422
    big = base64.b64encode(b"\x00" * 1_000_001).decode()
    assert report(voice_note=big, voice_type="audio/mp4", voice_seconds=60).status_code in (413, 422)
    assert report(voice_note="not base64!", voice_type="audio/mp4", voice_seconds=5).status_code == 400
    assert report(voice_note=VOICE, voice_type="video/mp4", voice_seconds=5).status_code == 400


def test_only_the_team_sees_reports(fresh):
    assert client.get("/portal/admin/reports").status_code == 401


def test_ten_reports_an_hour_per_phone(monkeypatch):
    for _ in range(10):
        assert report().status_code == 201
    assert report().status_code == 429
