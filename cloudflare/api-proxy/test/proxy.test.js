// The Worker in front of the private Space (src/index.js), with a fake Space.
import assert from "node:assert/strict";
import { afterEach, test } from "node:test";

import worker from "../src/index.js";

const env = {
  UPSTREAM: "https://owner-magana-api.hf.space",
  HF_TOKEN: "hf_secret_token",
  ALLOWED_ORIGINS: "https://teachers.magana.ng,https://magana.ng",
};
const realFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = realFetch; });

function space(answer) {
  const seen = [];
  globalThis.fetch = async (url, init) => {
    seen.push({ url, init, headers: new Headers(init.headers) });
    if (answer instanceof Error) throw answer;
    return typeof answer === "function" ? answer() : answer;
  };
  return seen;
}

const req = (path, init = {}) => new Request(`https://api.magana.ng${path}`, init);

test("adds the token, passes the app key, sets the caller's address, never the caller's own", async () => {
  const seen = space(new Response('{"status":"ok"}', { headers: { "content-type": "application/json" } }));
  const r = await worker.fetch(req("/read?mode=school", {
    method: "POST", body: "photo-bytes",
    headers: { "x-magana-key": "app-key", "cf-connecting-ip": "102.89.1.2", "x-forwarded-for": "6.6.6.6",
               authorization: "Bearer client-made-this-up" },
  }), env);
  assert.equal(r.status, 200);
  const [{ url, headers }] = seen;
  assert.equal(url, "https://owner-magana-api.hf.space/read?mode=school");
  assert.equal(headers.get("authorization"), "Bearer hf_secret_token");
  assert.equal(headers.get("x-magana-key"), "app-key");
  assert.equal(headers.get("x-forwarded-for"), "102.89.1.2");
  assert.equal(await r.text(), '{"status":"ok"}');
});

test("the token never comes back to the caller", async () => {
  space(new Response('{"x":1}', { headers: { "content-type": "application/json" } }));
  const r = await worker.fetch(req("/health"), env);
  assert.ok(![...r.headers.values()].some((v) => v.includes("hf_secret_token")));
  assert.ok(!(await r.text()).includes("hf_secret_token"));
});

test("a sleeping or building Space: 503 server_waking, also when it can't be reached", async () => {
  for (const answer of [new Response("<html>Building</html>", { status: 503, headers: { "content-type": "text/html" } }),
                        new Response("bad gateway", { status: 502 }), new Error("connect failed")]) {
    space(answer);
    const r = await worker.fetch(req("/read", { method: "POST", body: "x" }), env);
    assert.equal(r.status, 503);
    assert.equal(r.headers.get("retry-after"), "5");
    assert.deepEqual(await r.json(), { detail: { code: "server_waking", retry_after: 5 } });
  }
});

test("Magana's own coded errors pass through untouched", async () => {
  space(new Response('{"detail":{"code":"not_set_up"}}', { status: 503, headers: { "content-type": "application/json" } }));
  const r = await worker.fetch(req("/portal/me"), env);
  assert.equal(r.status, 503);
  assert.deepEqual(await r.json(), { detail: { code: "not_set_up" } });
});

test("Hugging Face refusing the token is server_unavailable, never its page", async () => {
  space(new Response("<html>404 not found</html>", { status: 404, headers: { "content-type": "text/html" } }));
  const r = await worker.fetch(req("/health"), env);
  assert.equal(r.status, 502);
  assert.deepEqual(await r.json(), { detail: { code: "server_unavailable" } });
});

test("CORS: preflights are answered here for our sites only, with credentials", async () => {
  const seen = space(new Response("never"));
  const ok = await worker.fetch(req("/portal/me", { method: "OPTIONS", headers: {
    origin: "https://teachers.magana.ng", "access-control-request-headers": "content-type" } }), env);
  assert.equal(ok.status, 204);
  assert.equal(ok.headers.get("access-control-allow-origin"), "https://teachers.magana.ng");
  assert.equal(ok.headers.get("access-control-allow-credentials"), "true");
  const other = await worker.fetch(req("/portal/me", { method: "OPTIONS", headers: { origin: "https://evil.example" } }), env);
  assert.equal(other.headers.get("access-control-allow-origin"), null);
  assert.equal(seen.length, 0);  // the Space was never woken for a preflight
});

test("CORS headers on answers replace the server's own, and cookies pass through", async () => {
  space(new Response("{}", { headers: { "content-type": "application/json", "access-control-allow-origin": "*",
                                        "set-cookie": "magana_session=abc; HttpOnly; Secure; SameSite=Lax; Path=/" } }));
  const r = await worker.fetch(req("/portal/auth/verify", { method: "POST", body: "{}",
                                                             headers: { origin: "https://magana.ng" } }), env);
  assert.equal(r.headers.get("access-control-allow-origin"), "https://magana.ng");
  assert.match(r.headers.get("set-cookie"), /magana_session=abc/);
});

test("rate limits: heavy paths on their own limiter, /health never limited, 429 coded", async () => {
  space(new Response("{}", { headers: { "content-type": "application/json" } }));
  const used = [];
  const limiter = (name, ok) => ({ limit: async ({ key }) => { used.push([name, key]); return { success: ok }; } });
  const limitedEnv = { ...env, LIMIT: limiter("light", true), LIMIT_HEAVY: limiter("heavy", false) };
  const heavy = await worker.fetch(req("/read", { method: "POST", body: "x", headers: { "cf-connecting-ip": "1.2.3.4" } }), limitedEnv);
  assert.equal(heavy.status, 429);
  assert.deepEqual(await heavy.json(), { detail: { code: "too_many_requests" } });
  assert.equal((await worker.fetch(req("/curriculum"), limitedEnv)).status, 200);
  assert.equal((await worker.fetch(req("/health"), { ...env, LIMIT: limiter("light", false) })).status, 200);
  assert.deepEqual(used, [["heavy", "1.2.3.4"], ["light", "unknown"]]);
});

test("a big upload is streamed through", async () => {
  const seen = space(new Response("{}", { headers: { "content-type": "application/json" } }));
  const big = new Uint8Array(30 * 1024 * 1024);
  await worker.fetch(req("/read-pdf", { method: "POST", body: big }), env);
  assert.ok(seen[0].init.body);
});
