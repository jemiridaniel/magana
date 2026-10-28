"use client";

// Shown whenever a call finds Magana's server asleep or waking up (the free test-phase server
// sleeps; a call waits up to 60 s for it). role="alert": screen readers hear it once, as soon as
// it appears.
import { useEffect, useState } from "react";
import { checkServer, lastServerState, SERVER_EVENT, type ServerState } from "@/lib/server";

export const SLEEPING = "Magana’s server is sleeping. Please try again later.";
export const OFFLINE = "You’re offline. Check the internet connection, then try again.";
export const WAKING = "Magana is waking up, one moment…";

export default function ServerBanner() {
  const [state, setState] = useState<ServerState>(lastServerState);
  const [checking, setChecking] = useState(false);

  useEffect(() => {
    const on = (e: Event) => setState((e as CustomEvent<ServerState>).detail);
    window.addEventListener(SERVER_EVENT, on);
    return () => window.removeEventListener(SERVER_EVENT, on);
  }, []);

  if (state === "ok") return null;
  if (state === "waking") {
    return (
      <div className="server-banner" role="alert">
        <p>{WAKING}</p>
      </div>
    );
  }
  return (
    <div className="server-banner" role="alert">
      <p>{state === "offline" ? OFFLINE : SLEEPING}</p>
      <button
        type="button" className="btn btn-secondary" disabled={checking}
        onClick={async () => { setChecking(true); await checkServer(); setChecking(false); }}
      >
        {checking ? "Checking…" : "Try again"}
      </button>
    </div>
  );
}
