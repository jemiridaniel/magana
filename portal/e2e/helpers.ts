// Shared by the portal's end-to-end tests: a fresh, approved school with its principal signed
// in through the real sign-in page (the code read from the backend's development outbox).
import AxeBuilder from "@axe-core/playwright";
import { expect, request as pwRequest, type Page } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";
import { apiUrl, dataDir } from "../playwright.config";

let n = 0;
export const uniqueEmail = (who: string) => `${who}.${Date.now()}.${process.pid}.${n++}@gmail.com`;

/** The last sign-in code emailed to [email] (backend MAGANA_MAIL=outbox). */
export async function emailedCode(email: string): Promise<string> {
  const dir = path.join(dataDir!, "outbox");
  for (let i = 0; i < 50; i++) {
    const mails = fs.existsSync(dir)
      ? fs.readdirSync(dir).map((f) => ({ f, t: fs.statSync(path.join(dir, f)).mtimeMs }))
          .sort((a, b) => a.t - b.t).map(({ f }) => JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")))
          .filter((m) => m.to === email && /sign-in code/.test(m.subject))
      : [];
    if (mails.length) return mails.at(-1).text.match(/(\d{3}) (\d{3})/).slice(1).join("");
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

export async function approve(schoolId: string) {
  const team = await pwRequest.newContext();
  const email = `approver-${process.env.TEST_PARALLEL_INDEX ?? 0}@magana.test`;  // this worker's own
  await team.post(`${apiUrl}/portal/auth/request-code`, { data: { email } });
  await team.post(`${apiUrl}/portal/auth/verify`, { data: { email, code: await emailedCode(email) } });
  expect((await team.post(`${apiUrl}/portal/admin/schools/${schoolId}`, { data: { decision: "approve", checks: ["person_confirmed", "school_exists", "details_correct"] } })).ok()).toBeTruthy();
}

/** Signs [email] in through the real page and waits for Home. */
export async function signIn(page: Page, email: string) {
  await page.goto("/sign-in/");
  await page.getByLabel("Email address").fill(email);
  await page.getByRole("button", { name: "Send me a code" }).click();
  await expect(page.getByRole("heading", { name: "Check your email" })).toBeFocused();
  await page.getByLabel("Sign-in code").fill(await emailedCode(email));
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
