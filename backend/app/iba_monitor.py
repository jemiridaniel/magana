"""Watches the Ibà service and raises one alert when it has been unreachable too long.

Every Ibà call (and a background probe every IBA_PROBE_S seconds) reports success or
failure here. After ALERT_AFTER_S of continuous failure, one alert goes out: a CRITICAL log
line, plus a POST to MAGANA_ALERT_WEBHOOK_URL if set (Slack-style {"text": ...}). When Ibà
answers again a recovery message goes out and the clock resets.

Only service health is recorded here, never anything a user answered.
"""
from __future__ import annotations

import logging
import os
import threading
import time
from collections.abc import Callable

import httpx

log = logging.getLogger("magana.iba")

ALERT_AFTER_S = 10 * 60


def _post_webhook(text: str) -> None:
    url = os.environ.get("MAGANA_ALERT_WEBHOOK_URL", "").strip()
    if not url:
        return

    def send() -> None:
        try:
            httpx.post(url, json={"text": text}, timeout=5)
        except httpx.HTTPError as e:
            log.error("alert webhook failed: %s", type(e).__name__)

    # Never make a user's request wait on the alert.
    threading.Thread(target=send, daemon=True).start()


class IbaMonitor:
    def __init__(self, alert_after_s: float = ALERT_AFTER_S, clock: Callable[[], float] = time.monotonic,
                 notify: Callable[[str], None] = _post_webhook):
        self.alert_after_s = alert_after_s
        self._clock = clock
        self._notify = notify
        self._down_since: float | None = None
        self._last_reason = ""
        self._alerted = False
        self._lock = threading.Lock()

    def failure(self, reason: str) -> None:
        with self._lock:
            now = self._clock()
            if self._down_since is None:
                self._down_since = now
            self._last_reason = reason
            down_for = now - self._down_since
            if self._alerted or down_for < self.alert_after_s:
                return
            self._alerted = True
        text = (f"ALERT: Ibà triage service unreachable for {down_for / 60:.0f} minutes "
                f"(last error: {reason}). Magana is answering with its built-in danger-sign rules.")
        log.critical(text)
        self._notify(text)

    def success(self) -> None:
        with self._lock:
            if self._down_since is None:
                return
            down_for, alerted = self._clock() - self._down_since, self._alerted
            self._down_since, self._alerted, self._last_reason = None, False, ""
        text = f"Ibà triage service reachable again after {down_for / 60:.1f} minutes."
        if alerted:
            log.warning("RESOLVED: %s", text)
            self._notify(f"RESOLVED: {text}")
        else:
            log.info(text)

    def status(self) -> dict:
        with self._lock:
            if self._down_since is None:
                return {"reachable": True, "alerting": False}
            return {"reachable": False, "down_for_s": round(self._clock() - self._down_since),
                    "last_error": self._last_reason, "alerting": self._alerted}


monitor = IbaMonitor()
