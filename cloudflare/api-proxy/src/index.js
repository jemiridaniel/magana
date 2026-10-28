// api.magana.ng: every request goes on to Magana's private Hugging Face Space (docs/INFRA.md).
// - The Space only answers with an access token. It is added here from the Worker secret HF_TOKEN
//   and never sent to a client. Magana's own app key (X-Magana-Key) passes through unchanged.
// - Simple per-address limits (300 a minute; 30 a minute for reading and speech).
// - CORS for the portal, the website and the PWA, answered here (preflights never wake the Space).
// - A sleeping or building Space answers 503 with {"detail": {"code": "server_waking"}}: the app
//   and the portal say "Magana is waking up, one moment…" and try again for up to 60 s.
// - Large photo and PDF uploads are streamed through, never held here.

const HEAVY = /^\/(read|read-pdf|asr|explain|portal\/uploads)(\/|$)/;
const OPEN = new Set(["/health"]);  // uptime checks: never limited
const ALLOW_METHODS = "GET, POST, PUT, PATCH, DELETE, OPTIONS";
const DROP_REQUEST = ["host", "authorization", "x-forwarded-for", "x-real-ip", "forwarded", "cf-connecting-ip"];

export function corsHeaders(origin, env) {
  const allowed = (env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!origin || !allowed.includes(origin)) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Credentials": "true",
    Vary: "Origin",
  };
}

function json(status, body, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store", ...extra },
  });
}

export function waking(cors) {
  return json(503, { detail: { code: "server_waking", retry_after: 5 } }, { "Retry-After": "5", ...cors });
}

async function limited(env, path, ip) {
  if (OPEN.has(path)) return false;
  const limiter = HEAVY.test(path) ? env.LIMIT_HEAVY : env.LIMIT;
  if (!limiter) return false;  // no binding (tests, local): the server's own limits still apply
  try {
    const { success } = await limiter.limit({ key: ip });
    return !success;
  } catch {
    return false;  // a limiter problem never takes the API down
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get("origin");
    const cors = corsHeaders(origin, env);

    if (request.method === "OPTIONS") {
      const asked = request.headers.get("access-control-request-headers");
      return new Response(null, {
        status: 204,
        headers: Object.keys(cors).length
          ? { ...cors, "Access-Control-Allow-Methods": ALLOW_METHODS,
              "Access-Control-Allow-Headers": asked || "content-type, x-magana-key, x-magana-device",
              "Access-Control-Max-Age": "600" }
          : {},
      });
    }

    const ip = request.headers.get("cf-connecting-ip") || "unknown";
    if (await limited(env, url.pathname, ip)) {
      return json(429, { detail: { code: "too_many_requests" } }, { "Retry-After": "60", ...cors });
    }

    const headers = new Headers(request.headers);
    for (const h of DROP_REQUEST) headers.delete(h);
    headers.set("authorization", `Bearer ${env.HF_TOKEN}`);
    // The caller's address, set here (never the caller's own header): the server's rate limits.
    headers.set("x-forwarded-for", ip);
    headers.set("x-forwarded-proto", "https");
    headers.set("x-forwarded-host", url.host);

    let upstream;
    try {
      upstream = await fetch(env.UPSTREAM.replace(/\/$/, "") + url.pathname + url.search, {
        method: request.method,
        headers,
        body: ["GET", "HEAD"].includes(request.method) ? undefined : request.body,
        redirect: "manual",
      });
    } catch {
      return waking(cors);
    }

    const type = upstream.headers.get("content-type") || "";
    // Magana's server always answers errors in JSON. A 5xx page that isn't JSON is Hugging Face's
    // own: the Space is asleep, starting or building.
    if (upstream.status >= 500 && !type.includes("application/json")) return waking(cors);
    // Hugging Face's own refusal (a wrong or expired token): not the caller's fault, and never
    // shown as is.
    if ((upstream.status === 401 || upstream.status === 403 || upstream.status === 404) &&
        !type.includes("application/json")) {
      return json(502, { detail: { code: "server_unavailable" } }, cors);
    }

    const out = new Headers(upstream.headers);
    for (const h of [...out.keys()]) if (h.startsWith("access-control-")) out.delete(h);
    for (const [k, v] of Object.entries(cors)) out.set(k, v);
    return new Response(upstream.body, { status: upstream.status, statusText: upstream.statusText, headers: out });
  },
};
