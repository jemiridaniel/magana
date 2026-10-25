// Every call to the Magana API goes through apiFetch, so "the server isn't answering" is
// told the same way everywhere: the portal is on Cloudflare Pages and stays up when the
// EC2 server is stopped (docs/DEPLOY_PAGES.md).
export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "";

export const SERVER_EVENT = "magana:server";
export type ServerState = "ok" | "sleeping" | "offline";

/** "sleeping": the browser is online but the API didn't answer, or answered 502–504 from its proxy. */
export class ServerDown extends Error {
  constructor(public state: Exclude<ServerState, "ok">) {
    super(state);
  }
}

function announce(state: ServerState) {
  if (typeof window !== "undefined") window.dispatchEvent(new CustomEvent<ServerState>(SERVER_EVENT, { detail: state }));
}

export async function apiFetch(path: string, init: RequestInit = {}): Promise<Response> {
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
    if (!json?.detail?.code) {  // a coded 503 (e.g. "not set up") is the backend speaking
      announce("sleeping");
      throw new ServerDown("sleeping");
    }
  }
  announce("ok");
  return r;
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
