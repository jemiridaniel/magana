// Shared by the portal's end-to-end tests: a fresh, approved school with its principal signed
// in through the real sign-in page (the code read from the backend's development outbox).
import AxeBuilder from "@axe-core/playwright";
import { expect, request as pwRequest, type APIRequestContext, type Page } from "@playwright/test";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { apiUrl, dataDir, TOTP_SECRET } from "../playwright.config";

// ---------- authenticator codes (RFC 6238), as the team's phones make them

function base32(s: string): Buffer {
  const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const ch of s.replace(/[\s=]/g, "").toUpperCase()) bits += abc.indexOf(ch).toString(2).padStart(5, "0");
  return Buffer.from(bits.match(/.{8}/g)!.map((b) => parseInt(b, 2)));
}

export function totpAt(secret: string, counter: number): string {
  const msg = Buffer.alloc(8);
  msg.writeBigUInt64BE(BigInt(counter));
  const d = crypto.createHmac("sha1", base32(secret)).update(msg).digest();
  const o = d[d.length - 1] & 0xf;
  return String((d.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, "0");
}

const lastCounter = new Map<string, number>();
/** The next authenticator code for [email] that hasn't been used (the server refuses a reused one). */
export async function nextTotp(email: string, secret = TOTP_SECRET): Promise<string> {
  for (;;) {
    const now = Math.floor(Date.now() / 30_000);
    // From the current step, never the previous one: at a step boundary it could already be too old.
    const c = Math.max(now, (lastCounter.get(email) ?? -Infinity) + 1);
    if (c <= now + 1) { lastCounter.set(email, c); return totpAt(secret, c); }
    await new Promise((r) => setTimeout(r, 1000));
  }
}

let n = 0;
export const uniqueEmail = (who: string) => `${who}.${Date.now()}.${process.pid}.${n++}@gmail.com`;

/** The last sign-in code emailed to [email] (backend MAGANA_MAIL=outbox), sent at or after [after] (ms). */
export async function emailedCode(email: string, after = 0): Promise<string> {
  const dir = path.join(dataDir!, "outbox");
  for (let i = 0; i < 50; i++) {
    const mails = fs.existsSync(dir)
      ? fs.readdirSync(dir).map((f) => ({ f, t: fs.statSync(path.join(dir, f)).mtimeMs }))
          .filter(({ t }) => t >= after - 50)
          .sort((a, b) => a.t - b.t).map(({ f }) => JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")))
          .filter((m) => m.to === email && /sign-in code/.test(m.subject))
      : [];
    if (mails.length) return mails.at(-1).subject.match(/^(\d{3}) (\d{3})/).slice(1).join("");
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`no code emailed to ${email}`);
}

export async function lagosIkeja() {
  const api = await pwRequest.newContext();
  const places = await (await api.get(`${apiUrl}/portal/places`)).json();
  const lagos = places.states.find((s: { name: string }) => s.name === "Lagos");
  return { state: lagos.code as string, lga: lagos.lgas.find((l: { name: string }) => l.name === "Ikeja").code as string };
}

export async function registerSchool(email: string, school = "Ikeja Community School"): Promise<string> {
  const api = await pwRequest.newContext();
  const r = await api.post(`${apiUrl}/portal/schools/register`, { data: {
    email, name: "Mrs Folake Adebayo", role: "Principal", phone: "0803 000 0001", school, ...(await lagosIkeja()), agree: true } });
  expect(r.status(), await r.text()).toBe(201);
  return (await r.json()).school_id;
}

let approver: APIRequestContext | null = null;
/** Approves a school as the test School reviewer: signed in once (email code and authenticator), then kept. */
export async function approve(schoolId: string) {
  const decide = () => approver!.post(`${apiUrl}/portal/admin/schools/${schoolId}`,
    { data: { decision: "approve", checks: ["person_confirmed", "school_exists", "details_correct"] } });
  if (approver) {
    const r = await decide();
    if (r.ok()) return;
  }
  const email = "approver@magana.test";
  approver = await pwRequest.newContext();
  const asked = Date.now();
  await approver.post(`${apiUrl}/portal/auth/request-code`, { data: { email } });
  await approver.post(`${apiUrl}/portal/auth/verify`, { data: { email, code: await emailedCode(email, asked) } });
  // A new worker process doesn't know which codes the last one used; the server refuses a reused
  // code, so one retry with the next code (3 wrong tries would lock the account).
  let t = await approver.post(`${apiUrl}/portal/auth/totp`, { data: { code: await nextTotp(email) } });
  if (!t.ok()) t = await approver.post(`${apiUrl}/portal/auth/totp`, { data: { code: await nextTotp(email) } });
  expect(t.ok(), await t.text()).toBeTruthy();
  const r = await decide();
  expect(r.ok(), await r.text()).toBeTruthy();
}

/** Signs a Magana team member in through the real pages: email code, then authenticator code. */
export async function signInTeam(page: Page, email: string) {
  await page.goto("/sign-in/");
  await page.getByLabel("Email address").fill(email);
  const asked = Date.now();
  await page.getByRole("button", { name: "Send me a code" }).click();
  await page.getByRole("textbox", { name: /^Sign-in code/ }).fill(await emailedCode(email, asked));
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: "Enter your authenticator code" })).toBeFocused();
  await page.getByLabel("Authenticator code").fill(await nextTotp(email));
  await page.getByRole("button", { name: "Sign in" }).click();
  // As in approve(): a code an earlier worker already used is refused; one retry with the next.
  if (await page.locator(".form-error").filter({ hasText: "isn’t right" }).isVisible({ timeout: 1500 }).catch(() => false)) {
    await page.getByLabel("Authenticator code").fill(await nextTotp(email));
    await page.getByRole("button", { name: "Sign in" }).click();
  }
  await expect(page).toHaveURL(/\/admin\/?$/);
}

/** Signs [email] in through the real page and waits for Home. */
export async function signIn(page: Page, email: string) {
  await page.goto("/sign-in/");
  await page.getByLabel("Email address").fill(email);
  const asked = Date.now();
  await page.getByRole("button", { name: "Send me a code" }).click();
  await expect(page.getByRole("heading", { name: "Check your email" })).toBeFocused();
  await page.getByRole("textbox", { name: /^Sign-in code/ }).fill(await emailedCode(email, asked));
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { level: 1 })).toContainText(/Good (morning|afternoon|evening)/);
}

/** A new approved school with its principal (a school admin) signed in on [page]. */
export async function newSchool(page: Page): Promise<{ email: string; schoolId: string }> {
  const email = uniqueEmail("principal");
  const schoolId = await registerSchool(email);
  await approve(schoolId);
  await signIn(page, email);
  return { email, schoolId };
}

export async function addClass(page: Page, name: string, level: string, mode: "guided" | "classroom" | "standard") {
  const r = await page.request.post(`${apiUrl}/portal/classes`, { data: { name, level, mode } });
  expect(r.status(), await r.text()).toBe(201);
  return (await r.json()) as { id: string; code: string; name: string };
}

/** A learner's phone joins with the class code (the app's call). */
export async function joinOnPhone(page: Page, code: string, tier = "guided") {
  const r = await page.request.post(`${apiUrl}/learner/join`, {
    data: { class_code: code }, headers: { "X-Magana-Tier": tier, "X-Magana-Device": `e2e-${Date.now()}-${n++}` } });
  expect(r.ok(), await r.text()).toBeTruthy();
  return (await r.json()) as { token: string; status: string };
}

export async function designChecks(page: Page) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow, "no sideways scrolling").toBeLessThanOrEqual(0);
  const small = await page.evaluate(() =>
    [...document.querySelectorAll("a[href], button, select, input:not([type=hidden]), textarea, label.check")]
      .filter((e) => {
        const s = getComputedStyle(e);
        if (s.display === "none" || s.visibility === "hidden" || e.closest(".visually-hidden, dialog:not([open])")) return false;
        if (e.matches("input[type=checkbox], input[type=radio]") && e.closest("label")) return false;
        if (e.matches("a.skip-link")) return false;
        if (e.matches("a") && (e.parentElement?.textContent ?? "").trim().length > (e.textContent ?? "").trim().length + 10) return false;
        const r = e.getBoundingClientRect();
        if (r.width === 0 && r.height === 0) return false;
        return r.height < 48 || (e.matches("button, select, input, .btn") && r.height < 64);
      })
      .map((e) => `${e.tagName} "${(e.getAttribute("aria-label") || e.textContent || "").trim().slice(0, 40)}"`),
  );
  expect(small, "targets: 64 px for buttons and fields, 48 px for links").toEqual([]);
  const axe = await new AxeBuilder({ page: page as never })
    .withTags(["wcag2a", "wcag2aa", "wcag2aaa", "wcag21aa", "wcag22aa", "best-practice"])
    .analyze();
  expect(axe.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`)).toEqual([]);
}
