"""Small named files kept in the database, not on the server's disk: the server is disposable
(docs/INFRA.md), and everything that matters is in the database, which is backed up daily. Used for teachers' quizzes
(quizzes.py), proof-of-school files, encrypted (proofs.py), and WhatsApp's profiles, call-back
requests and monthly count (wa_store.py). Never photos or page text."""
from __future__ import annotations

SCHEMA = """
CREATE TABLE IF NOT EXISTS blobs(
  kind TEXT NOT NULL, name TEXT NOT NULL, data BLOB NOT NULL, updated_at TEXT NOT NULL,
  PRIMARY KEY(kind, name));
"""


def get(kind: str, name: str) -> bytes | None:
    from .accounts import db

    with db() as con:
        r = con.execute("SELECT data FROM blobs WHERE kind = ? AND name = ?", (kind, name)).fetchone()
    return None if r is None else bytes(r[0])


def put(kind: str, name: str, data: bytes) -> None:
    from .accounts import db, iso, now

    with db() as con:
        con.execute("INSERT OR REPLACE INTO blobs(kind, name, data, updated_at) VALUES (?,?,?,?)",
                    (kind, name, data, iso(now())))


def delete(kind: str, name: str) -> bool:
    from .accounts import db

    with db() as con:
        return con.execute("DELETE FROM blobs WHERE kind = ? AND name = ?", (kind, name)).rowcount > 0


def names(kind: str) -> list[str]:
    from .accounts import db

    with db() as con:
        return [r[0] for r in con.execute("SELECT name FROM blobs WHERE kind = ? ORDER BY name", (kind,)).fetchall()]


def get_text(kind: str, name: str) -> str | None:
    data = get(kind, name)
    return None if data is None else data.decode("utf-8")


def put_text(kind: str, name: str, text: str) -> None:
    put(kind, name, text.encode("utf-8"))
