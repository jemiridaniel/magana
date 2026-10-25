"""WhatsApp Cloud API (Meta Graph API): send text, buttons, lists and voice notes; fetch photos.

Settings (server .env only; docs/WHATSAPP_SETUP.md):
  WHATSAPP_TOKEN            the access token (the test number's, or a system user's)
  WHATSAPP_PHONE_NUMBER_ID  the sending number's ID
  WHATSAPP_GRAPH_VERSION    Graph API version, v21.0 by default
Nothing here logs a phone number or message text.
"""
from __future__ import annotations

import os

import httpx

GRAPH = "https://graph.facebook.com"
# Meta's limits: a reply button title 20 characters, a list row title 24, a body 1,024 (4,096
# for plain text). Titles are checked by backend/tests/test_whatsapp.py for every language.
BUTTON_TITLE_MAX = 20
ROW_TITLE_MAX = 24
TEXT_MAX = 4096
INTERACTIVE_BODY_MAX = 1024
PHOTO_MAX_BYTES = 10 * 1024 * 1024


class WhatsAppError(Exception):
    pass


class WhatsAppClient:
    def __init__(self, token: str, phone_number_id: str, version: str = "v21.0",
                 transport: httpx.AsyncBaseTransport | None = None):
        self.token = token
        self.base = f"{GRAPH}/{version}"
        self.phone_number_id = phone_number_id
        self.transport = transport

    @classmethod
    def from_env(cls) -> "WhatsAppClient | None":
        token = os.environ.get("WHATSAPP_TOKEN", "").strip()
        number = os.environ.get("WHATSAPP_PHONE_NUMBER_ID", "").strip()
        if not token or not number:
            return None
        return cls(token, number, os.environ.get("WHATSAPP_GRAPH_VERSION", "v21.0"))

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(timeout=20, transport=self.transport,
                                 headers={"Authorization": f"Bearer {self.token}"})

    async def _send(self, to: str, payload: dict) -> None:
        body = {"messaging_product": "whatsapp", "recipient_type": "individual", "to": to, **payload}
        try:
            async with self._client() as c:
                r = await c.post(f"{self.base}/{self.phone_number_id}/messages", json=body)
                r.raise_for_status()
        except httpx.HTTPError as e:
            raise WhatsAppError(type(e).__name__) from e

    async def text(self, to: str, body: str) -> None:
        await self._send(to, {"type": "text", "text": {"body": body[:TEXT_MAX], "preview_url": False}})

    async def buttons(self, to: str, body: str, buttons: list[tuple[str, str]]) -> None:
        """Up to 3 reply buttons: (id, title)."""
        await self._send(to, {"type": "interactive", "interactive": {
            "type": "button",
            "body": {"text": body[:INTERACTIVE_BODY_MAX]},
            "action": {"buttons": [{"type": "reply", "reply": {"id": i, "title": t[:BUTTON_TITLE_MAX]}}
                                   for i, t in buttons[:3]]},
        }})

    async def list(self, to: str, body: str, button: str, section: str, rows: list[tuple[str, str]]) -> None:
        """A list message: one section of up to 10 rows (id, title)."""
        await self._send(to, {"type": "interactive", "interactive": {
            "type": "list",
            "body": {"text": body[:INTERACTIVE_BODY_MAX]},
            "action": {"button": button[:BUTTON_TITLE_MAX], "sections": [
                {"title": section[:ROW_TITLE_MAX], "rows": [{"id": i, "title": t[:ROW_TITLE_MAX]} for i, t in rows[:10]]},
            ]},
        }})

    async def upload_voice(self, ogg: bytes) -> str:
        """Upload an OGG/Opus file; returns its media id (valid for 30 days)."""
        try:
            async with self._client() as c:
                r = await c.post(f"{self.base}/{self.phone_number_id}/media",
                                 data={"messaging_product": "whatsapp", "type": "audio/ogg"},
                                 files={"file": ("reading.ogg", ogg, "audio/ogg")})
                r.raise_for_status()
                return r.json()["id"]
        except (httpx.HTTPError, KeyError, ValueError) as e:
            raise WhatsAppError(type(e).__name__) from e

    async def voice(self, to: str, media_id: str) -> None:
        await self._send(to, {"type": "audio", "audio": {"id": media_id}})

    async def download(self, media_id: str) -> bytes:
        """A photo the user sent, into memory only (never written to disk)."""
        try:
            async with self._client() as c:
                meta = await c.get(f"{self.base}/{media_id}")
                meta.raise_for_status()
                info = meta.json()
                if int(info.get("file_size") or 0) > PHOTO_MAX_BYTES:
                    raise WhatsAppError("too_big")
                r = await c.get(info["url"])
                r.raise_for_status()
                if len(r.content) > PHOTO_MAX_BYTES:
                    raise WhatsAppError("too_big")
                return r.content
        except (httpx.HTTPError, KeyError, ValueError) as e:
            raise WhatsAppError(type(e).__name__) from e
