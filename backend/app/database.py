"""The database: one SQLite file in development and tests, Postgres when DATABASE_URL is set
(the test phase: a free Supabase or Neon database in an EU region, docs/INFRA.md).

The rest of the code writes SQLite's SQL (`?` placeholders, INSERT OR REPLACE, its schema).
On Postgres, [PgConnection] translates it, so both run the same statements:
- `?` → `%s`, LIKE → ILIKE (SQLite's LIKE ignores case);
- INSERT OR REPLACE / OR IGNORE → ON CONFLICT on the table's primary key;
- the schema: INTEGER → BIGINT, BLOB → BYTEA, AUTOINCREMENT → an identity column;
- booleans are stored as 0/1, as SQLite does; numbers come back as int or float, never Decimal;
  BYTEA comes back as bytes.

Tests can run on Postgres too (MAGANA_TEST_DATABASE_URL, conftest.py): each MAGANA_DATA_DIR then
gets its own schema, as each gets its own SQLite file.
"""
from __future__ import annotations

import hashlib
import os
import re
import sqlite3
from decimal import Decimal
from pathlib import Path


def url() -> str:
    return os.environ.get("DATABASE_URL", "").strip()


def is_postgres() -> bool:
    return url().startswith(("postgres://", "postgresql://"))


def data_dir() -> Path:
    d = Path(os.environ.get("MAGANA_DATA_DIR", "data"))
    d.mkdir(parents=True, exist_ok=True)
    return d


def key() -> str:
    """Which database a connection goes to (schemas are made once per key)."""
    return f"{url()}#{_schema()}" if is_postgres() else str(data_dir() / "magana.db")


def _schema() -> str | None:
    if os.environ.get("MAGANA_DB_SCHEMA_PER_DATA_DIR") != "1":
        return None
    return "t_" + hashlib.sha1(str(Path(os.environ.get("MAGANA_DATA_DIR", "data")).resolve()).encode()).hexdigest()[:16]


def connect():
    """A connection; the caller commits or rolls back and closes it."""
    if not is_postgres():
        con = sqlite3.connect(key())
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA foreign_keys = ON")
        return con
    pool = _pool()
    raw = pool.getconn()
    try:
        schema = _schema()
        if schema:
            raw.execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')
            raw.execute(f'SET search_path TO "{schema}"')
            raw.commit()
    except Exception:
        pool.putconn(raw)
        raise
    return PgConnection(raw, pool)


_pools: dict = {}


def _pool():
    """A few open connections, reused: the database is an ocean away from the server (London and
    the US), so a new TLS connection per request would add about 0.3 s. Prepared statements are
    off, for the providers' poolers (PgBouncer, Supavisor) in transaction mode."""
    from psycopg_pool import ConnectionPool

    u = url()
    if u not in _pools:
        _pools[u] = ConnectionPool(u, min_size=1, max_size=int(os.environ.get("DATABASE_POOL_SIZE", "4")),
                                   kwargs={"autocommit": False, "prepare_threshold": None},
                                   check=ConnectionPool.check_connection, open=True)
    return _pools[u]


def columns(con, table: str) -> set[str]:
    """The table's column names, on either database."""
    if isinstance(con, PgConnection):
        rows = con.execute("SELECT column_name FROM information_schema.columns"
                           " WHERE table_schema = current_schema() AND table_name = ?", (table,)).fetchall()
        return {r[0] for r in rows}
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})")}


def tables(con) -> list[str]:
    """Every table's name, on either database."""
    if isinstance(con, PgConnection):
        rows = con.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema()"
                           " ORDER BY table_name").fetchall()
    else:
        rows = con.execute("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").fetchall()
    return [r[0] for r in rows]


# ---------- Postgres

class Row(tuple):
    """Like sqlite3.Row: by position, by column name, and dict(row)."""

    def __new__(cls, values, names):
        row = super().__new__(cls, values)
        row._names = names
        return row

    def keys(self):
        return list(self._names)

    def __getitem__(self, k):
        if isinstance(k, str):
            return tuple.__getitem__(self, self._names.index(k))
        return tuple.__getitem__(self, k)


def _value(v):
    if isinstance(v, Decimal):
        return int(v) if v == v.to_integral_value() else float(v)
    if isinstance(v, memoryview):
        return bytes(v)
    return v


def _param(v):
    return int(v) if isinstance(v, bool) else v


class Cursor:
    def __init__(self, cur):
        self._cur = cur
        self.rowcount = cur.rowcount

    def _names(self):
        return [d.name for d in self._cur.description or []]

    def fetchone(self):
        r = self._cur.fetchone() if self._cur.description else None
        return None if r is None else Row([_value(v) for v in r], self._names())

    def fetchall(self):
        if not self._cur.description:
            return []
        names = self._names()
        return [Row([_value(v) for v in r], names) for r in self._cur.fetchall()]

    def __iter__(self):
        return iter(self.fetchall())


_PLACEHOLDER = re.compile(r"'(?:[^']|'')*'|\?")
_INSERT_OR = re.compile(r"^\s*INSERT\s+OR\s+(REPLACE|IGNORE)\s+INTO\s+(\w+)\s*\(([^)]*)\)", re.I | re.S)


def translate(sql: str, params: bool = True) -> str:
    """One SQLite statement as Postgres runs it (placeholders, LIKE). INSERT OR … needs the
    table's key: PgConnection.execute adds it. With parameters, a literal % is doubled."""
    if params:
        sql = sql.replace("%", "%%")
    sql = _PLACEHOLDER.sub(lambda m: "%s" if m.group(0) == "?" else m.group(0), sql)
    return re.sub(r"\bLIKE\b", "ILIKE", sql)


def translate_schema(sql: str) -> str:
    sql = re.sub(r"\bINTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT\b", "BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY",
                 sql, flags=re.I)
    sql = re.sub(r"\bINTEGER\b", "BIGINT", sql)
    return re.sub(r"\bBLOB\b", "BYTEA", sql)


class PgConnection:
    """The few sqlite3.Connection methods Magana uses, on a psycopg connection."""

    def __init__(self, raw, pool=None):
        self._raw = raw
        self._pool = pool
        self._keys: dict[str, list[str]] = {}

    def _primary_key(self, table: str) -> list[str]:
        if table not in self._keys:
            rows = self._raw.execute(
                "SELECT a.attname FROM pg_index i JOIN pg_attribute a ON a.attrelid = i.indrelid"
                " AND a.attnum = ANY(i.indkey) WHERE i.indrelid = %s::regclass AND i.indisprimary",
                (table,)).fetchall()
            self._keys[table] = [r[0] for r in rows]
        return self._keys[table]

    def execute(self, sql: str, params=()):
        m = _INSERT_OR.match(sql)
        if m:
            how, table, cols = m.group(1).upper(), m.group(2), [c.strip() for c in m.group(3).split(",")]
            keys = self._primary_key(table)
            rest = sql[m.end():]
            sql = f"INSERT INTO {table}({', '.join(cols)}){rest}"
            update = [c for c in cols if c not in keys]
            sql += (f" ON CONFLICT ({', '.join(keys)}) DO "
                    + ("NOTHING" if how == "IGNORE" or not update
                       else "UPDATE SET " + ", ".join(f"{c} = EXCLUDED.{c}" for c in update)))
        if sql.strip().upper().startswith("PRAGMA"):
            return Cursor(self._raw.execute("SELECT 1 WHERE false"))
        if params:
            cur = self._raw.execute(translate(sql), [_param(p) for p in params])
        else:
            cur = self._raw.execute(translate(sql, params=False))
        return Cursor(cur)

    def executescript(self, script: str) -> None:
        for statement in translate_schema(script).split(";"):
            if statement.strip():
                self._raw.execute(statement)

    def commit(self):
        self._raw.commit()

    def rollback(self):
        self._raw.rollback()

    def close(self):
        if self._pool is not None:
            self._pool.putconn(self._raw)  # rolled back if a transaction was left open
        else:
            self._raw.close()
