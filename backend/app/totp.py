"""Authenticator codes for Magana team accounts (RFC 6238: SHA-1, 30 s, 6 digits), the same as
Google Authenticator, Microsoft Authenticator, Authy or 2FAS. A few lines of the standard library:
no extra package. The secret is stored sealed (AES-GCM, a key from MAGANA_CODE_KEY)."""
from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote

STEP = 30
DIGITS = 6
WINDOW = 1  # one step either side: a phone clock a little off still works


def new_secret() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def _key(secret: str) -> bytes:
    s = secret.strip().replace(" ", "").upper()
    return base64.b32decode(s + "=" * (-len(s) % 8))


def code_at(secret: str, counter: int) -> str:
    digest = hmac.new(_key(secret), struct.pack(">Q", counter), hashlib.sha1).digest()
    o = digest[-1] & 0x0F
    n = (struct.unpack(">I", digest[o:o + 4])[0] & 0x7FFFFFFF) % 10 ** DIGITS
    return str(n).zfill(DIGITS)


def counter_now(t: float | None = None) -> int:
    return int((time.time() if t is None else t) // STEP)


def check(secret: str, code: str, last_counter: int | None = None, t: float | None = None) -> int | None:
    """The counter the code matches (to store, so it can't be used twice), or None."""
    code = "".join(ch for ch in str(code) if ch.isdigit())
    if len(code) != DIGITS:
        return None
    now = counter_now(t)
    for c in range(now - WINDOW, now + WINDOW + 1):
        if (last_counter is None or c > last_counter) and hmac.compare_digest(code_at(secret, c), code):
            return c
    return None


def uri(secret: str, email: str) -> str:
    """otpauth:// link: opens the authenticator app on a phone, or paste the key by hand."""
    return f"otpauth://totp/Magana:{quote(email)}?secret={secret}&issuer=Magana&digits={DIGITS}&period={STEP}"


def grouped(secret: str) -> str:
    """"JBSW Y3DP EHPK 3PXP": easier to type into an app."""
    return " ".join(secret[i:i + 4] for i in range(0, len(secret), 4))
