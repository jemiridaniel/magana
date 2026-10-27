"""Per-IP and per-device rate limits (the web app's API key is public, so it can't stop abuse).

Token buckets in memory, one process (the backend runs one worker). Limits per minute, from
the environment:
  RATE_IP_PER_MIN (120) and RATE_DEVICE_PER_MIN (60) for every call;
  RATE_HEAVY_IP_PER_MIN (30) and RATE_HEAVY_DEVICE_PER_MIN (12) for /read, /asr and /explain.
Daily caps on the same heavy calls, counted per Lagos calendar day: RATE_HEAVY_DEVICE_PER_DAY
(300) per device and RATE_HEAVY_IP_PER_DAY (3000) per IP (a school's learners often share one
connection). Over a cap: 429 "daily_limit" until midnight in Lagos.
The device is the app's random install ID (X-Magana-Device); without one, only the IP limits
apply. Behind Caddy the IP comes from X-Forwarded-For (uvicorn --proxy-headers).
The app key (X-Magana-Key) is an app identifier, not a secret: it ships in the APK, the IPA and
the PWA. These limits, not the key, are what protect the server (docs/DEPLOY_AWS.md, "API key").

The signed-in teacher portal is limited per session instead (RATE_PORTAL_SESSION_PER_MIN,
300): a school's teachers often share one internet connection, and one portal page makes
several calls. Sign-in and registration keep the IP limits, plus their own (portal_api.py).
"""
from __future__ import annotations

import hashlib
import os
import re
import time
from dataclasses import dataclass, field

HEAVY_PATHS = ("/read", "/asr", "/asr/choose", "/explain")
EXEMPT_PATHS = ("/health", "/whatsapp/webhook")  # Meta signs its calls; usage is capped instead
PORTAL_PUBLIC = ("/portal/auth/", "/portal/schools/register", "/portal/places")
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


LAGOS_OFFSET_S = 3600  # Africa/Lagos is UTC+1 all year (no daylight saving)


def exempt(device: str | None) -> bool:
    """Pilot testers' phones, by install ID (RATE_EXEMPT_DEVICES, comma-separated; each app's
    hidden diagnostics shows its ID): no daily cap, so a day of testing never ends in "come back
    tomorrow". Not by key: the key is in every copy of the app. The per-minute limits still apply."""
    if not device:
        return False
    listed = {d.strip() for d in os.environ.get("RATE_EXEMPT_DEVICES", "").split(",") if d.strip()}
    return device in listed


@dataclass
class RateLimiter:
    clock: callable = time.monotonic
    buckets: dict[str, Bucket] = field(default_factory=dict)
    wall: callable = time.time
    days: dict[str, tuple[int, int]] = field(default_factory=dict)  # key -> (Lagos day number, count)

    def check_daily(self, path: str, ip: str, device: str | None) -> float:
        """0 if this heavy call is within today's caps (and counts it), else the seconds until
        midnight in Lagos. Light calls are never capped per day."""
        if path not in HEAVY_PATHS or exempt(device):
            return 0.0
        local = self.wall() + LAGOS_OFFSET_S
        today = int(local // 86400)
        caps = [(f"ip-day:{ip}", _limit("RATE_HEAVY_IP_PER_DAY", 3000))]
        if device and _DEVICE.match(device):
            caps.append((f"dev-day:{device}", _limit("RATE_HEAVY_DEVICE_PER_DAY", 300)))
        counts = [(k, cap, self.days.get(k, (today, 0))) for k, cap in caps]
        if any(day == today and n >= cap for _, cap, (day, n) in counts):
            return 86400 - local % 86400
        for k, _, (day, n) in counts:
            self.days[k] = (today, (n if day == today else 0) + 1)
        if len(self.days) > 100_000:
            self.days = {k: v for k, v in self.days.items() if v[0] == today}
        return 0.0

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

    def check(self, path: str, ip: str, device: str | None, session: str | None = None) -> float:
        """0 if this call may go ahead, else seconds to wait. Every applicable bucket is
        charged only when all allow it."""
        if path in EXEMPT_PATHS:
            return 0.0
        if session and path.startswith("/portal/") and not path.startswith(PORTAL_PUBLIC):
            key = "portal:" + hashlib.sha256(session.encode()).hexdigest()[:16]
            return self.take(key, _limit("RATE_PORTAL_SESSION_PER_MIN", 300))
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
