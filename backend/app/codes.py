"""Class, session and teacher codes: 6 digits, easy to say and type with TalkBack.

- Digits only, and never an easy pattern: no digit three times or more, no two doubles
  (112233), no run of 4 (1234, 9876), no repeated unit (121212, 123123), and not a mirror
  image (123321).
- Stored as a keyed hash (HMAC-SHA256 with MAGANA_CODE_KEY), so the server can check a code
  without keeping it readable, plus an AES-GCM encrypted copy, so the class's own teacher (and
  the school's admins) can see it again in the portal. Nobody else ever gets it back.
- Teachers can rotate any code; the old one stops working at once.
- Guessing: 3 wrong tries and the device (or sign-in) waits 5 minutes (`Attempts`).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import os
import secrets
import threading
import time

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

LENGTH = 6
MAX_WRONG = 3
LOCKOUT_S = 5 * 60


def _master() -> bytes:
    key = os.environ.get("MAGANA_CODE_KEY", "")
    if not key:
        if os.environ.get("MAGANA_ENV", "production") == "production" and os.environ.get("MAGANA_API_KEY"):
            raise RuntimeError("set MAGANA_CODE_KEY in the server .env (openssl rand -hex 32)")
        key = "magana-development-code-key"
    return key.encode()


def _derived(purpose: str) -> bytes:
    return hmac.new(_master(), purpose.encode(), hashlib.sha256).digest()


def is_simple(code: str) -> bool:
    """True for codes that are easy to guess or mistype into another valid one."""
    if len(code) != LENGTH or not code.isdigit():
        return True
    if any(code.count(d) >= 3 for d in set(code)):
        return True
    if sum(a == b for a, b in zip(code, code[1:])) >= 2:  # 112233, 445590
        return True
    steps = [int(b) - int(a) for a, b in zip(code, code[1:])]
    for i in range(len(steps) - 2):  # a run of 4: 1234, 9876, 3456
        if steps[i] == steps[i + 1] == steps[i + 2] and abs(steps[i]) == 1:
            return True
    for unit in (1, 2, 3):
        if code == (code[:unit] * (LENGTH // unit + 1))[:LENGTH]:
            return True
    if code == code[::-1] or code[:3] == code[3:][::-1]:
        return True
    return False


def new_code(taken=lambda lookup: False) -> str:
    """A fresh code that isn't simple and isn't already in use (taken(lookup) says)."""
    while True:
        code = f"{secrets.randbelow(10 ** LENGTH):0{LENGTH}d}"
        if not is_simple(code) and not taken(lookup(code)):
            return code


def normalise(typed: str) -> str:
    """"482 915" or "482-915" → "482915"."""
    return "".join(ch for ch in str(typed) if ch.isdigit())


def lookup(code: str) -> str:
    """The keyed hash the server stores and searches by."""
    return hmac.new(_derived("lookup"), normalise(code).encode(), hashlib.sha256).hexdigest()


def seal(code: str) -> str:
    nonce = secrets.token_bytes(12)
    return base64.b64encode(nonce + AESGCM(_derived("encrypt")).encrypt(nonce, code.encode(), b"magana-code")).decode()


def unseal(sealed: str) -> str:
    raw = base64.b64decode(sealed)
    return AESGCM(_derived("encrypt")).decrypt(raw[:12], raw[12:], b"magana-code").decode()


def seal_with(purpose: str, text: str) -> str:
    """Encrypt any short secret (an authenticator key) with its own derived key."""
    nonce = secrets.token_bytes(12)
    return base64.b64encode(nonce + AESGCM(_derived(f"encrypt-{purpose}")).encrypt(nonce, text.encode(), purpose.encode())).decode()


def unseal_with(purpose: str, sealed: str) -> str:
    raw = base64.b64decode(sealed)
    return AESGCM(_derived(f"encrypt-{purpose}")).decrypt(raw[:12], raw[12:], purpose.encode()).decode()


def spaced(code: str) -> str:
    """"482915" → "482 915", as the portal shows it."""
    return f"{code[:3]} {code[3:]}"


class Attempts:
    """MAX_WRONG wrong tries per key, then LOCKOUT_S seconds of nothing (in memory; a restart
    forgets, which only ever helps the person locked out)."""

    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self._wrong: dict[str, list[float]] = {}
        self._until: dict[str, float] = {}
        self._lock = threading.Lock()

    def locked_for(self, key: str) -> float:
        with self._lock:
            left = self._until.get(key, 0) - self.clock()
            return max(0.0, left)

    def failed(self, key: str) -> float:
        """Record a wrong try; the seconds to wait now (0 if not locked yet)."""
        with self._lock:
            now = self.clock()
            tries = [t for t in self._wrong.get(key, []) if now - t < LOCKOUT_S] + [now]
            if len(tries) >= MAX_WRONG:
                self._wrong.pop(key, None)
                self._until[key] = now + LOCKOUT_S
                return float(LOCKOUT_S)
            self._wrong[key] = tries
            return 0.0

    def succeeded(self, key: str) -> None:
        with self._lock:
            self._wrong.pop(key, None)
            self._until.pop(key, None)


attempts = Attempts()
