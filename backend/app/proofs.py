"""Proof of school (optional, on "Register your school"): a photo or PDF of the letterhead, the
Ministry approval letter or a staff ID. Kept private: encrypted at rest (AES-GCM, a key derived
from MAGANA_CODE_KEY), in the database (blobs.py, kind "proof"), never on disk or in a web folder, readable only by
the Magana team (portal_api: GET /portal/admin/schools/{id}/proof), and deleted as soon as the
school is approved or not approved (docs/PRIVACY.md)."""
from __future__ import annotations

import base64
import secrets

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from . import blobs, codes

MAX_BYTES = 5 * 1024 * 1024
# What a real file of each type starts with: the browser's claim isn't trusted.
_MAGIC = {"image/jpeg": [b"\xff\xd8\xff"], "image/png": [b"\x89PNG\r\n\x1a\n"], "application/pdf": [b"%PDF-"],
          "image/webp": [b"RIFF"]}


class ProofError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def kind_of(data: bytes) -> str:
    for kind, heads in _MAGIC.items():
        if any(data.startswith(h) for h in heads) and (kind != "image/webp" or data[8:12] == b"WEBP"):
            return kind
    raise ProofError("proof_wrong_type")


def decode(b64: str) -> bytes:
    try:
        data = base64.b64decode(b64.split(",", 1)[-1], validate=True)
    except Exception:
        raise ProofError("proof_wrong_type") from None
    if len(data) > MAX_BYTES:
        raise ProofError("proof_too_big")
    return data


def save(school_id: str, data: bytes) -> str:
    """Encrypts and stores it; returns the file's type."""
    kind = kind_of(data)
    nonce = secrets.token_bytes(12)
    sealed = nonce + AESGCM(codes._derived("proof-file")).encrypt(nonce, data, school_id.encode())
    blobs.put("proof", school_id, sealed)
    return kind


def load(school_id: str) -> bytes | None:
    raw = blobs.get("proof", school_id)
    if raw is None:
        return None
    return AESGCM(codes._derived("proof-file")).decrypt(raw[:12], raw[12:], school_id.encode())


def delete(school_id: str) -> bool:
    return blobs.delete("proof", school_id)
