"""Schools, staff, classes and learners for the teacher portal and the learner app.

One SQLite file, MAGANA_DATA_DIR/magana.db (docs/PRIVACY.md, "Teachers and schools"):
- schools     name, state and LGA codes, the principal's contact, status pending/approved
- staff       teachers and school admins: name, email, role, status, their teacher code
- login_codes the 6-digit sign-in code, hashed, for 10 minutes
- sessions    signed-in portal sessions (hashed token), ended after 30 minutes idle
- classes     name, level, mode, teacher, class code (hashed + sealed: codes.py)
- learners    the name a teacher gives, formats, language, under 18 or not, guardian consent,
              the linked phone (a hashed random token, never a phone number), term records
- attendance, uploads, learner_stats: the portal's figures
- audit       who invited, removed or changed whom, and when
- deletions   a guardian's deletion request, until a school admin confirms it
"""
from __future__ import annotations

import json
import os
import secrets
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path

from . import codes

_lock = threading.RLock()

SCHEMA = """
CREATE TABLE IF NOT EXISTS schools(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, state TEXT NOT NULL, lga TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending','approved','rejected')),
  contact_name TEXT, contact_role TEXT, contact_email TEXT, contact_phone TEXT,
  created_at TEXT NOT NULL, decided_at TEXT, decided_by TEXT);
CREATE TABLE IF NOT EXISTS staff(
  id TEXT PRIMARY KEY, school_id TEXT NOT NULL REFERENCES schools(id), name TEXT NOT NULL,
  email TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('admin','teacher')), title TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK(status IN ('invited','active','removed')),
  invited_by TEXT, invited_at TEXT, invite_expires TEXT,
  code_lookup TEXT UNIQUE, code_sealed TEXT, created_at TEXT NOT NULL, removed_at TEXT);
CREATE UNIQUE INDEX IF NOT EXISTS staff_email_live ON staff(email) WHERE status != 'removed';
CREATE TABLE IF NOT EXISTS login_codes(
  email TEXT PRIMARY KEY, code_lookup TEXT NOT NULL, expires TEXT NOT NULL, wrong INTEGER NOT NULL DEFAULT 0,
  sent_at TEXT NOT NULL, sent_count INTEGER NOT NULL DEFAULT 1, count_since TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sessions(
  token_lookup TEXT PRIMARY KEY, who TEXT NOT NULL, created_at TEXT NOT NULL, last_seen TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS classes(
  id TEXT PRIMARY KEY, school_id TEXT NOT NULL REFERENCES schools(id), teacher_id TEXT REFERENCES staff(id),
  name TEXT NOT NULL, level TEXT NOT NULL, mode TEXT NOT NULL CHECK(mode IN ('guided','classroom','standard')),
  code_lookup TEXT UNIQUE NOT NULL, code_sealed TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS learners(
  id TEXT PRIMARY KEY, school_id TEXT NOT NULL REFERENCES schools(id), class_id TEXT REFERENCES classes(id),
  name TEXT NOT NULL, formats TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'en',
  under_18 INTEGER NOT NULL, consent TEXT NOT NULL CHECK(consent IN ('pending','received','not_needed')),
  consent_at TEXT, consent_note TEXT, reminder_at TEXT,
  token_lookup TEXT UNIQUE, linked_at TEXT, status TEXT NOT NULL CHECK(status IN ('active','removed')),
  removed_at TEXT, removed_reason TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS attendance(
  class_id TEXT NOT NULL, learner_id TEXT NOT NULL, day TEXT NOT NULL,
  mark TEXT NOT NULL CHECK(mark IN ('present','absent','late')), PRIMARY KEY(class_id, learner_id, day));
CREATE TABLE IF NOT EXISTS learner_stats(
  learner_id TEXT NOT NULL, week TEXT NOT NULL, pages INTEGER NOT NULL DEFAULT 0, unaided INTEGER NOT NULL DEFAULT 0,
  quiz_avg REAL, PRIMARY KEY(learner_id, week));
CREATE TABLE IF NOT EXISTS uploads(
  id TEXT PRIMARY KEY, school_id TEXT NOT NULL, class_id TEXT, teacher_id TEXT, title TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('processing','check','ready','shared')), note TEXT NOT NULL DEFAULT '',
  handwriting TEXT, text TEXT, created_at TEXT NOT NULL, approved_by TEXT, approved_at TEXT);
CREATE TABLE IF NOT EXISTS audit(
  id INTEGER PRIMARY KEY AUTOINCREMENT, school_id TEXT, actor TEXT, action TEXT NOT NULL,
  target TEXT, detail TEXT NOT NULL DEFAULT '{}', at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS deletions(
  id TEXT PRIMARY KEY, school_id TEXT NOT NULL, learner_id TEXT NOT NULL, requested_by TEXT NOT NULL,
  requested_at TEXT NOT NULL, due TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','done')),
  confirmed_by TEXT, done_at TEXT);
"""

INVITE_DAYS = 7
LOGIN_CODE_MINUTES = 10
IDLE_MINUTES = 30
SESSION_MAX_HOURS = 12
DELETE_WITHIN_DAYS = 7


def now() -> datetime:
    return datetime.now(timezone.utc)


def iso(t: datetime) -> str:
    return t.isoformat(timespec="seconds")


def parse(s: str | None) -> datetime | None:
    return datetime.fromisoformat(s) if s else None


def new_id(prefix: str) -> str:
    return f"{prefix}_{secrets.token_hex(6)}"


def db_path() -> Path:
    d = Path(os.environ.get("MAGANA_DATA_DIR", "data"))
    d.mkdir(parents=True, exist_ok=True)
    return d / "magana.db"


_ready: set[str] = set()


@contextmanager
def db():
    """One transaction: committed on success, rolled back on any error."""
    path = str(db_path())
    with _lock:
        con = sqlite3.connect(path)
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA foreign_keys = ON")
        try:
            if path not in _ready:
                con.executescript(SCHEMA)
                from . import team  # the Magana team's own accounts (team.py)
                con.executescript(team.SCHEMA)
                from . import ses_events  # addresses that bounced or complained
                con.executescript(ses_events.SCHEMA)
                _migrate(con)
                _ready.add(path)
            yield con
            con.commit()
        except Exception:
            con.rollback()
            raise
        finally:
            con.close()


# Columns added after the first release: added to an existing database on first use.
COLUMNS = {
    "sessions": {"browser": "TEXT", "place": "TEXT"},
    # Who did it, as they were when it happened (actor_snapshot): the log is append-only, so a
    # removed account still shows its name and email.
    "audit": {"actor_name": "TEXT", "actor_email": "TEXT", "actor_role": "TEXT"},
    "schools": {"ref": "INTEGER", "call_notes": "TEXT NOT NULL DEFAULT ''", "checks": "TEXT NOT NULL DEFAULT ''",
                "reason": "TEXT", "proof_type": "TEXT", "ministry_no": "TEXT NOT NULL DEFAULT ''"},
}


def _migrate(con) -> None:
    for table, cols in COLUMNS.items():
        have = {r[1] for r in con.execute(f"PRAGMA table_info({table})")}
        for name, kind in cols.items():
            if name not in have:
                con.execute(f"ALTER TABLE {table} ADD COLUMN {name} {kind}")
    # Schools registered before references existed get one, in order.
    for i, r in enumerate(con.execute("SELECT id FROM schools WHERE ref IS NULL ORDER BY created_at").fetchall()):
        top = con.execute("SELECT COALESCE(MAX(ref), 1046) FROM schools").fetchone()[0]
        con.execute("UPDATE schools SET ref = ? WHERE id = ?", (top + 1, r[0]))
    # Entries written before the snapshot existed get one from the accounts as they are now.
    for (actor,) in con.execute("SELECT DISTINCT actor FROM audit WHERE actor_name IS NULL AND actor IS NOT NULL").fetchall():
        snap = actor_snapshot(con, actor)
        if snap[0] is not None:
            con.execute("UPDATE audit SET actor_name = ?, actor_email = ?, actor_role = ? WHERE actor = ? AND actor_name IS NULL",
                        (*snap, actor))


def reset_for_tests() -> None:
    _ready.clear()


def actor_snapshot(con, actor: str | None) -> tuple[str | None, str | None, str | None]:
    """(name, email, role) of a Magana team member, a school's staff member or the server, as
    they are now. Learners get none: their names never go in the log."""
    from . import team
    if actor in ("server", "system"):
        return ("Magana server", "", "Server command") if actor == "server" else ("Magana", "", "Automatic")
    if actor and actor.startswith("team:"):
        email = actor[5:]
        m = con.execute("SELECT name, role FROM team_members WHERE email = ? ORDER BY status = 'removed', created_at DESC",
                        (email,)).fetchone()
        return (m["name"], email, team.ROLE_LABEL[m["role"]]) if m else (email, email, "Magana team")
    if actor and not actor.startswith(("learner:", "deleted-")):
        s = con.execute("SELECT name, email, role FROM staff WHERE id = ?", (actor,)).fetchone()
        if s:
            return s["name"], s["email"], "School admin" if s["role"] == "admin" else "Teacher"
    return None, None, None


def audit(con, school_id: str | None, actor: str | None, action: str, target: str | None = None, **detail) -> None:
    con.execute("INSERT INTO audit(school_id, actor, action, target, detail, at, actor_name, actor_email, actor_role)"
                " VALUES (?,?,?,?,?,?,?,?,?)",
                (school_id, actor, action, target, json.dumps(detail, ensure_ascii=False), iso(now()),
                 *actor_snapshot(con, actor)))


def row(r) -> dict | None:
    return dict(r) if r is not None else None


def _code_taken(con, table: str):
    return lambda lk: con.execute(f"SELECT 1 FROM {table} WHERE code_lookup = ?", (lk,)).fetchone() is not None


def fresh_code(con, table: str) -> tuple[str, str, str]:
    """(code, lookup, sealed) unique in [table] (classes or staff)."""
    code = codes.new_code(_code_taken(con, table))
    return code, codes.lookup(code), codes.seal(code)
