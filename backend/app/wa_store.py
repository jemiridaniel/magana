"""What Magana keeps for WhatsApp, and for how long (docs/PRIVACY.md, "WhatsApp").

On disk, under MAGANA_DATA_DIR/whatsapp/:
- profiles.json   per user, keyed by a keyed hash of the phone number (never the number):
                  the chosen language, and "adult" or "under_18". Nothing else.
- callbacks.jsonl call-back requests for the nurse desk: reference, phone number (the nurse
                  must call it), language, priority, time, status. Never the triage answers.
                  Deleted after CALLBACK_DAYS.
- usage.json      messages sent per month, for the free-tier limit.

In memory only, for SESSION_MINUTES: the conversation step, the quick-check answers so far
(never written anywhere, never logged), and the last reading's text, for "Read again".
Photos are never kept: they exist in memory only while being read.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

SESSION_MINUTES = 30
CALLBACK_DAYS = 30
# Meta's free tier, as the team plans it: 1,000 messages a month per number. Warn at 800;
# at the limit, stop sending (except the emergency message). WHATSAPP_MONTHLY_LIMIT overrides.
MONTHLY_FREE = 1000
WARN_AT = 800
_lock = threading.Lock()


def data_dir() -> Path:
    d = Path(os.environ.get("MAGANA_DATA_DIR", "data")) / "whatsapp"
    d.mkdir(parents=True, exist_ok=True)
    return d


def user_key(wa_id: str) -> str:
    """A stable, keyed hash of the phone number: the number itself is never stored as a key."""
    secret = (os.environ.get("WHATSAPP_APP_SECRET", "") or "magana-dev").encode()
    return hmac.new(secret, wa_id.encode(), hashlib.sha256).hexdigest()[:32]


# ---------- profiles: language and age group

def _read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def _write_json(path: Path, value) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    tmp.replace(path)


def get_profile(wa_id: str) -> dict:
    with _lock:
        return dict(_read_json(data_dir() / "profiles.json", {}).get(user_key(wa_id), {}))


def set_profile(wa_id: str, **changes) -> dict:
    allowed = {"lang", "age", "goodbye_sent"}
    assert set(changes) <= allowed, changes
    with _lock:
        path = data_dir() / "profiles.json"
        all_ = _read_json(path, {})
        p = {**all_.get(user_key(wa_id), {}), **changes}
        all_[user_key(wa_id)] = p
        _write_json(path, all_)
        return dict(p)


# ---------- sessions: memory only

@dataclass
class Session:
    step: str | None = None          # None | "language" | "age" | "triage" | "phone"
    triage: dict = field(default_factory=dict)       # questions, index, answers: memory only
    last_reading: dict | None = None  # {"messages": [...], "voice_id": str | None}
    callback_ref: str | None = None
    voice_told: bool = False          # "voice notes aren't ready" said once per session
    touched: float = field(default_factory=time.monotonic)


_sessions: dict[str, Session] = {}


def session(wa_id: str) -> Session:
    key = user_key(wa_id)
    now = time.monotonic()
    with _lock:
        for k in [k for k, s in _sessions.items() if now - s.touched > SESSION_MINUTES * 60]:
            del _sessions[k]  # expired: the answers and the last reading are gone
        s = _sessions.setdefault(key, Session())
        s.touched = now
        return s


def clear_session(wa_id: str) -> None:
    with _lock:
        _sessions.pop(user_key(wa_id), None)


def clear_sessions() -> None:
    with _lock:
        _sessions.clear()


# ---------- call-back requests

def _now() -> datetime:
    return datetime.now(timezone.utc)


def new_reference() -> str:
    """MG- and 4 random digits (never derived from the phone number)."""
    return f"MG-{secrets.randbelow(9000) + 1000}"


def _callbacks() -> list[dict]:
    path = data_dir() / "callbacks.jsonl"
    try:
        rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    except OSError:
        return []
    cutoff = _now() - timedelta(days=CALLBACK_DAYS)
    return [r for r in rows if datetime.fromisoformat(r["created"]) >= cutoff]


def _save_callbacks(rows: list[dict]) -> None:
    path = data_dir() / "callbacks.jsonl"
    tmp = path.with_suffix(".tmp")
    tmp.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    tmp.replace(path)


def add_callback(phone: str, lang: str, priority: str) -> str:
    with _lock:
        rows = _callbacks()
        ref = new_reference()
        while any(r["ref"] == ref for r in rows):
            ref = new_reference()
        rows.append({"ref": ref, "phone": phone, "language": lang, "priority": priority, "channel": "whatsapp",
                     "created": _now().isoformat(timespec="seconds"), "status": "open"})
        _save_callbacks(rows)
        return ref


def update_callback(ref: str, **changes) -> bool:
    """Change the number or cancel an open request; False if it isn't open any more."""
    assert set(changes) <= {"phone", "status"}, changes
    with _lock:
        rows = _callbacks()
        for r in rows:
            if r["ref"] == ref and r["status"] == "open":
                r.update(changes)
                _save_callbacks(rows)
                return True
        _save_callbacks(rows)
        return False


def callbacks() -> list[dict]:
    with _lock:
        return _callbacks()


# ---------- messages sent this month (free tier)

def month() -> str:
    return _now().strftime("%Y-%m")


def monthly_limit() -> int:
    return int(os.environ.get("WHATSAPP_MONTHLY_LIMIT", MONTHLY_FREE))


def sent_this_month() -> int:
    with _lock:
        return int(_read_json(data_dir() / "usage.json", {}).get(month(), 0))


def count_sent(n: int = 1) -> tuple[int, bool]:
    """Add n sent messages; (the month's total, whether this is the first time it reached
    WARN_AT): the caller then warns once."""
    with _lock:
        path = data_dir() / "usage.json"
        u = _read_json(path, {})
        before = int(u.get(month(), 0))
        u[month()] = before + n
        warned = set(u.get("warned", []))
        first = before + n >= WARN_AT and month() not in warned
        if first:
            u["warned"] = sorted(warned | {month()})
        _write_json(path, u)
        return before + n, first
