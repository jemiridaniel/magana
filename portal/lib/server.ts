// Every call to the Magana API goes through apiFetch, so "the server isn't answering" is
// told the same way everywhere: the portal is on Cloudflare Pages and stays up when the API
// is down (docs/DEPLOY_PAGES.md). The test-phase API is a free Hugging Face Space that sleeps
// (docs/INFRA.md): while it wakes, the Worker on api.magana.ng answers 503 "server_waking", and
// apiFetch shows "Magana is waking up, one moment…" and tries again for up to 60 s.
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "";

export const SERVER_EVENT = "magana:server";
export type ServerState = "ok" | "waking" | "sleeping" | "offline";

/** How long a call waits for the server to wake up before it says "sleeping". */
export const WAKE_WAIT_MS = 60_000;

/** "sleeping": the browser is online but the API didn't answer, or answered 502–504 from its proxy. */
export class ServerDown extends Error {
  constructor(public state: Exclude<ServerState, "ok" | "waking">) {
    super(state);
  }
}

let last: ServerState = "ok";
/** The last state seen, for a banner that appears after the failed call. */
export const lastServerState = () => last;

function announce(state: ServerState) {
  last = state;
  if (typeof window !== "undefined") window.dispatchEvent(new CustomEvent<ServerState>(SERVER_EVENT, { detail: state }));
}

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));

export async function apiFetch(path: string, init: RequestInit = {}, wakeWaitMs = WAKE_WAIT_MS): Promise<Response> {
  const started = Date.now();
  for (;;) {
    let r: Response;
    try {
      r = await fetch(`${API_URL}${path}`, { credentials: "include", ...init });
    } catch {
      const state = typeof navigator !== "undefined" && navigator.onLine === false ? "offline" : "sleeping";
      announce(state);
      throw new ServerDown(state);
    }
    if (r.status === 502 || r.status === 503 || r.status === 504) {
      const json = await r.clone().json().catch(() => null);
      const code = json?.detail?.code;
      if (code === "server_waking" && Date.now() - started < wakeWaitMs) {
        announce("waking");
        const after = Math.min(10, Math.max(1, Number(json.detail.retry_after) || 5)) * 1000;
        await pause(Math.min(after, wakeWaitMs - (Date.now() - started)));
        continue;
      }
      if (!code || code === "server_waking") {  // a coded 503 (e.g. "not set up") is the backend speaking
        announce("sleeping");
        throw new ServerDown("sleeping");
      }
    }
    announce("ok");
    return r;
  }
}

/** Ask /health directly ("Try again" on the banner). */
export async function checkServer(): Promise<boolean> {
  try {
    await apiFetch("/health");
    return true;
  } catch {
    return false;
  }
}
