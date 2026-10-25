"""Per-IP and per-device rate limits (the web app's API key is public, so it can't stop abuse).

Token buckets in memory, one process (the backend runs one worker). Limits per minute, from
the environment:
  RATE_IP_PER_MIN (120) and RATE_DEVICE_PER_MIN (60) for every call;
  RATE_HEAVY_IP_PER_MIN (30) and RATE_HEAVY_DEVICE_PER_MIN (12) for /read, /asr and /explain.
The device is the app's random install ID (X-Magana-Device); without one, only the IP limits
apply. Behind Caddy the IP comes from X-Forwarded-For (uvicorn --proxy-headers).
"""
from __future__ import annotations

import os
import re
import time
from dataclasses import dataclass, field

HEAVY_PATHS = ("/read", "/asr", "/asr/choose", "/explain")
EXEMPT_PATHS = ("/health",)
_DEVICE = re.compile(r"^[A-Za-z0-9-]{8,64}$")


def _limit(name: str, default: int) -> int:
    try:
        return max(1, int(os.environ.get(name, default)))
    except ValueError:
        return default


@dataclass
class Bucket:
    tokens: float
    updated: float


@dataclass
class RateLimiter:
    clock: callable = time.monotonic
    buckets: dict[str, Bucket] = field(default_factory=dict)

    def take(self, key: str, per_minute: int) -> float:
        """Spend one token; 0 if allowed, else the seconds until one is free."""
        now = self.clock()
        b = self.buckets.get(key)
        if b is None:
            b = self.buckets[key] = Bucket(per_minute, now)
        b.tokens = min(per_minute, b.tokens + (now - b.updated) * per_minute / 60)
        b.updated = now
        if b.tokens >= 1:
            b.tokens -= 1
            return 0.0
        return (1 - b.tokens) * 60 / per_minute

    def check(self, path: str, ip: str, device: str | None) -> float:
        """0 if this call may go ahead, else seconds to wait. Every applicable bucket is
        charged only when all allow it."""
        if path in EXEMPT_PATHS:
            return 0.0
        heavy = path in HEAVY_PATHS  # exact: /explain/check is a cheap check
        rules = [(f"ip:{ip}", _limit("RATE_IP_PER_MIN", 120))]
        if heavy:
            rules.append((f"ip-heavy:{ip}", _limit("RATE_HEAVY_IP_PER_MIN", 30)))
        if device and _DEVICE.match(device):
            rules.append((f"dev:{device}", _limit("RATE_DEVICE_PER_MIN", 60)))
            if heavy:
                rules.append((f"dev-heavy:{device}", _limit("RATE_HEAVY_DEVICE_PER_MIN", 12)))
        waits = []
        for key, per_minute in rules:
            waits.append(self.take(key, per_minute))
        if any(waits):
            # Refund the buckets that did allow it, so a refusal costs nothing elsewhere.
            for (key, _), w in zip(rules, waits):
                if not w:
                    self.buckets[key].tokens += 1
            return max(waits)
        self._prune()
        return 0.0

    def _prune(self) -> None:
        if len(self.buckets) > 50_000:
            cutoff = self.clock() - 600
            self.buckets = {k: b for k, b in self.buckets.items() if b.updated > cutoff}


limiter = RateLimiter()
