"""Client for the Ibà triage API (iba-natlas, /v1, self-report mode).

Configured by environment variables:
  IBA_API_URL  e.g. http://iba:8000 (unset: Ibà is not used, Magana's fallback answers)
  IBA_API_KEY  sent as X-API-Key

Every call has a hard 3-second deadline for the whole request, not per network step,
so a slow Ibà can never keep a frightened user waiting.
"""
from __future__ import annotations

import asyncio
import os

import httpx

DEADLINE_S = 3.0


class IbaUnavailable(Exception):
    """Ibà failed, timed out, refused us, or answered in a shape we don't trust."""


class IbaClient:
    def __init__(self, base_url: str, api_key: str, deadline_s: float = DEADLINE_S,
                 transport: httpx.AsyncBaseTransport | None = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.deadline_s = deadline_s
        self._transport = transport  # tests inject httpx.MockTransport

    @classmethod
    def from_env(cls) -> IbaClient | None:
        url = os.environ.get("IBA_API_URL", "").strip()
        return cls(url, os.environ.get("IBA_API_KEY", "")) if url else None

    async def _call(self, method: str, path: str, **kwargs) -> dict:
        async def go() -> dict:
            async with httpx.AsyncClient(base_url=self.base_url, transport=self._transport,
                                         headers={"X-API-Key": self.api_key},
                                         timeout=self.deadline_s) as client:
                r = await client.request(method, path, **kwargs)
                r.raise_for_status()
                return r.json()

        try:
            return await asyncio.wait_for(go(), timeout=self.deadline_s)
        except (asyncio.TimeoutError, httpx.HTTPError, ValueError) as e:
            raise IbaUnavailable(type(e).__name__) from e

    async def questions(self, lang: str) -> list[dict]:
        body = await self._call("GET", "/v1/questions", params={"mode": "self_report", "lang": lang})
        qs = body.get("questions") if isinstance(body, dict) else None
        if not isinstance(qs, list) or not all(isinstance(q, dict) and "id" in q for q in qs):
            raise IbaUnavailable("bad_questions")
        return qs

    async def assess(self, answers: dict) -> dict:
        body = await self._call("POST", "/v1/assess", json={"mode": "self_report", "answers": answers})
        if not isinstance(body, dict) or not {"priority", "message", "rule_version"} <= set(body):
            raise IbaUnavailable("bad_assessment")
        return body
