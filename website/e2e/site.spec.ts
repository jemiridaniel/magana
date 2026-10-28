import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import samples from "../data/samples.json";

const PAGES = ["/", "/privacy/", "/accessibility/", "/android/", "/test/"];
// Real phone sizes: iPhone 16/17 Pro, iPhone Pro Max, and a common low-cost Android.
const PHONES = [
  { name: "iPhone Pro", width: 402, height: 874 },
  { name: "iPhone Pro Max", width: 440, height: 956 },
  { name: "Android", width: 360, height: 800 },
];
const WIDTHS = [{ name: "desktop", width: 1280, height: 900 }, ...PHONES];

// Anything sticking out past the left or right edge (body has overflow-x: hidden, so scrollWidth
// alone would not show it), outside the hero demo's screen, which clips its own drawing.
const outside = (page: Page) => page.evaluate(() =>
  [...document.querySelectorAll<HTMLElement>("body *")]
    .filter((el) => el.getClientRects().length > 0 && !el.closest("#mg-loader, .pd-screen, .table-wrap, .visually-hidden"))
    .map((el) => ({ el: el.outerHTML.slice(0, 80), r: el.getBoundingClientRect() }))
    .filter((x) => x.r.width > 0 && (x.r.right > window.innerWidth + 0.5 || x.r.left < -0.5))
    .map((x) => `${x.el} (${Math.round(x.r.left)}..${Math.round(x.r.right)})`));

async function ready(page: Page, path: string) {
  await page.goto(path);
  await expect(page.locator("#mg-loader")).toBeHidden({ timeout: 25_000 });
}

for (const size of WIDTHS) {
  for (const path of PAGES) {
    test(`${path} at ${size.width} px: axe (WCAG 2.2 A/AA + 7:1 contrast), 64 px controls, no sideways scroll`, async ({ page }) => {
      await page.setViewportSize(size);
      await ready(page, path);
      if (size.width < 900) await page.locator(".nav-narrow summary").click(); // check the open menu too
      const axe = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"])
        .options({ rules: { "color-contrast-enhanced": { enabled: true } } })
        .analyze();
      expect(axe.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`)).toEqual([]);

      const small = await page.evaluate(() =>
        [...document.querySelectorAll<HTMLElement>("button, summary, input, select, textarea, a.btn")]
          .filter((el) => el.offsetParent !== null && !el.closest("#mg-loader"))
          .map((el) => ({ el: el.outerHTML.slice(0, 80), h: el.getBoundingClientRect().height }))
          .filter((x) => x.h < 64),
      );
      expect(small).toEqual([]);
      expect(await outside(page)).toEqual([]);
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      expect(overflow).toBeLessThanOrEqual(0);
    });
  }
}

// ---------- phone sizes (design canvas, "Website · magana.ng home", phone board 402 wide)

for (const size of PHONES) {
  test(`home at ${size.width}×${size.height} (${size.name}): top bar, language dropdown, full-size icons, key content`, async ({ page }) => {
    await page.setViewportSize(size);
    await ready(page, "/");
    const vw = size.width;
    const shots = process.env.SCREENS_DIR;  // e.g. SCREENS_DIR=~/magana-website-screens npx playwright test

    // The top bar fits: the bar and the header row stay inside the screen, logo and Menu on one row.
    for (const sel of [".access-bar", ".site-header", ".lang-menu summary", ".home-link", ".nav-narrow summary"]) {
      const b = (await page.locator(sel).boundingBox())!;
      expect(b.x, sel).toBeGreaterThanOrEqual(0);
      expect(b.x + b.width, sel).toBeLessThanOrEqual(vw);
    }
    const logo = (await page.locator(".home-link").boundingBox())!;
    const menu = (await page.locator(".nav-narrow summary").boundingBox())!;
    expect(Math.abs(logo.y + logo.height / 2 - (menu.y + menu.height / 2))).toBeLessThan(4);
    expect(menu.height).toBeGreaterThanOrEqual(64);

    // The language dropdown: visible, 64 px, opens by tap and by keyboard, lists all four, closes with Escape.
    const summary = page.locator(".lang-menu summary");
    await expect(summary).toBeVisible();
    await expect(summary).toHaveAccessibleName("Website language: English");
    expect((await summary.boundingBox())!.height).toBeGreaterThanOrEqual(64);
    const list = page.locator(".lang-list");
    await expect(list).toBeHidden();
    await summary.click();
    await expect(list).toBeVisible();
    await expect(list.locator("li")).toHaveCount(4);
    await expect(list.locator("[aria-current=true]")).toHaveText("English");
    await expect(list.getByText("translation coming")).toHaveCount(3);
    const lb = (await list.boundingBox())!;
    expect(lb.x).toBeGreaterThanOrEqual(0);
    expect(lb.x + lb.width).toBeLessThanOrEqual(vw);
    for (const opt of await list.locator(".lang-option").all()) expect((await opt.boundingBox())!.height).toBeGreaterThanOrEqual(64);
    if (shots) await page.screenshot({ path: `${shots}/home-${size.width}x${size.height}-language-open.png` });
    expect(await outside(page)).toEqual([]);
    await page.keyboard.press("Escape");
    await expect(list).toBeHidden();
    await expect(summary).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(list).toBeVisible();
    await page.locator(".hero .lead").click();  // a tap outside (on the opening paragraph, below the open list) closes it
    await expect(list).toBeHidden();

    // The iPhone and WhatsApp lines: icons at their full 24 × 24, text beside them, inside the screen.
    const soon = page.locator(".soon li");
    await expect(soon).toHaveCount(2);
    await expect(soon.nth(0)).toContainText("iPhone app coming soon.");
    await expect(soon.nth(1)).toContainText("WhatsApp coming soon.");
    for (const li of await soon.all()) {
      await li.scrollIntoViewIfNeeded();
      await expect(li).toBeVisible();
      const icon = (await li.locator("svg").boundingBox())!;
      expect(Math.round(icon.width)).toBe(24);
      expect(Math.round(icon.height)).toBe(24);
      const text = (await li.locator("> span").boundingBox())!;
      expect(text.x).toBeGreaterThanOrEqual(icon.x + icon.width);
      expect(text.x + text.width).toBeLessThanOrEqual(vw);
    }

    // Key content is there, 64 px buttons inside the screen.
    for (const name of ["Get the Android app", "Use it in your browser"]) {
      const b = page.locator(".hero").getByRole("link", { name, exact: true });
      await expect(b).toBeVisible();
      const bb = (await b.boundingBox())!;
      expect(bb.height).toBeGreaterThanOrEqual(64);
      expect(bb.x + bb.width).toBeLessThanOrEqual(vw);
    }
    await page.evaluate(() => window.scrollTo(0, 0));
    await expect(page.getByRole("heading", { level: 1, name: "Hear any printed page. In your language." })).toBeInViewport();
    for (const h of ["How it works", "Hear a sample", "One reading engine. Three parts of life.", "Built to be trusted with what matters",
                     "Your name in Braille", "For teachers and schools", "Made in Nigeria, with the people it serves"]) {
      await expect(page.getByRole("heading", { level: 2, name: h })).toBeVisible();
    }

    // No text clipped: no box that hides its overflow is smaller than its content (the demo phone aside).
    const clipped = await page.evaluate(() =>
      [...document.querySelectorAll<HTMLElement>("body *")]
        .filter((el) => el.getClientRects().length > 0 && !el.closest("#mg-loader, .pd, .visually-hidden, .table-wrap"))
        .filter((el) => { const cs = getComputedStyle(el); return cs.overflowX !== "visible" || cs.overflowY !== "visible" || cs.textOverflow === "ellipsis"; })
        .filter((el) => el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 1)
        .map((el) => el.outerHTML.slice(0, 80)));
    expect(clipped).toEqual([]);
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(vw);
    expect(await outside(page)).toEqual([]);

    if (shots) {
      await page.screenshot({ path: `${shots}/home-${size.width}x${size.height}.png` });
      await page.screenshot({ path: `${shots}/home-${size.width}x${size.height}-full.png`, fullPage: true });
      await page.locator(".nav-narrow summary").click();
      await page.screenshot({ path: `${shots}/home-${size.width}x${size.height}-menu-open.png` });
    }
  });
}

type Timeline = { firstVisit: boolean; frames: [number, number, number][]; shownMs: number; fullAt: number; slow: boolean };
const timeline = (page: Page) => page.evaluate(() => (window as unknown as { __mgLoader: Timeline }).__mgLoader);

function smooth(t: Timeline) {
  // Every dot, in order, never more than about 10% per 100 ms (a dot is 1/14 ≈ 7.1%).
  expect(t.frames.map((f) => f[1])).toEqual(Array.from({ length: 14 }, (_, i) => i + 1));
  for (let i = 1; i < t.frames.length; i++) {
    const [ms, , pct] = t.frames[i];
    const [ms0, , pct0] = t.frames[i - 1];
    expect(pct - pct0, `dot ${i + 1}`).toBeLessThanOrEqual(Math.max(8, ((ms - ms0) / 100) * 10 + 2));
  }
}

test("loader: a progressbar in the first HTML, fills smoothly over at least 1.6 s, holds, then goes", async ({ page, request }) => {
  const html = await (await request.get("/")).text();
  expect(html).toContain('role="progressbar"');
  expect(html).toContain('aria-label="Loading Magana"');
  await ready(page, "/");
  const t = await timeline(page);
  expect(t.firstVisit).toBe(true);
  smooth(t);
  expect(t.fullAt).toBeGreaterThanOrEqual(1600);
  expect(t.shownMs - t.fullAt).toBeGreaterThanOrEqual(300);  // "magana" held complete
  expect(t.shownMs).toBeLessThan(8000);                      // finished on real progress
  expect(t.slow).toBe(false);
  expect(await page.locator("[data-letter][data-on]").count()).toBe(6);
  expect(await page.locator("[data-progress]").getAttribute("aria-valuenow")).toBe("100");

  await page.reload();
  await expect(page.locator("#mg-loader")).toBeHidden({ timeout: 25_000 });
  const again = await timeline(page);
  expect(again.firstVisit).toBe(false);
  smooth(again);
  expect(again.fullAt).toBeGreaterThanOrEqual(1000);
  expect(again.fullAt).toBeLessThan(1600);
});

test("loader: with reduced motion, no pop and no fade", async ({ browser }) => {
  const page = await browser.newPage({ reducedMotion: "reduce" });
  await page.goto("/");
  const transitions = await page.evaluate(() => {
    const dot = document.querySelector("[data-dot]")!;
    return [getComputedStyle(dot).transitionDuration, getComputedStyle(document.getElementById("mg-loader")!).transitionDuration];
  });
  expect(transitions).toEqual(["0s", "0s"]);
  await expect(page.locator("#mg-loader")).toBeHidden({ timeout: 25_000 });
  // The fill stays (only pop and fade go): still in order, still at least 1.6 s.
  const t = await page.evaluate(() => (window as unknown as { __mgLoader: Timeline }).__mgLoader);
  smooth(t);
  expect(t.fullAt).toBeGreaterThanOrEqual(1600);
  await page.close();
});

test("Your name in Braille: cells, unsupported characters, and one spoken result", async ({ page }) => {
  await ready(page, "/");
  await page.getByLabel("Type your name").fill("Ada 7");
  await expect(page.locator(".cells .cell svg")).toHaveCount(4);
  await expect(page.locator(".cell-unsupported")).toHaveText(["not yet supported"]);
  await expect(page.locator(".braille-box [role=status]")).toHaveText(
    "Ada 7 in Braille: a: dot 1. d: dots 1, 4, 5. a: dot 1. space. 7: not yet supported.",
  );
});

test("Hear a sample: says exactly Magana's lines, unclear number included; nothing leaves the site; no cookies", async ({ page, context }) => {
  const outside: string[] = [];
  const site = new URL(test.info().project.use.baseURL!).origin;
  page.on("request", (r) => {
    if (!r.url().startsWith("data:") && new URL(r.url()).origin !== site) outside.push(r.url());
  });
  await page.addInitScript(() => {
    const said: string[] = [];
    (window as unknown as { __said: string[] }).__said = said;
    const fake = {
      speak(u: SpeechSynthesisUtterance) { said.push(u.text); setTimeout(() => u.onend?.(new Event("end") as SpeechSynthesisEvent), 10); },
      cancel() {}, getVoices: () => [], pause() {}, resume() {}, speaking: false, pending: false, paused: false,
    };
    Object.defineProperty(window, "speechSynthesis", { value: fake });
  });
  await ready(page, "/");
  await page.getByRole("button", { name: "Listen to the medicine label" }).click();
  await expect(page.getByRole("button", { name: "Listen to the medicine label" })).toBeVisible();
  const said = await page.evaluate(() => (window as unknown as { __said: string[] }).__said);
  const medicine = samples.find((s) => s.id === "medicine")!;
  expect(said).toEqual(medicine.lines.map((l) => l.said));
  expect(said.join(" ")).toContain("unclear number");
  expect(outside).toEqual([]);
  expect(await context.cookies()).toEqual([]);
});

// ---------- the hero demo (components/HeroDemo.tsx)

const running = (page: Page) => page.evaluate(() =>
  document.querySelector(".pd")!.getAnimations({ subtree: true }).filter((a) => a.playState === "running").length);
const opacity = (page: Page, sel: string) => page.evaluate((s) => Number(getComputedStyle(document.querySelector(s)!).opacity), sel);

test("hero demo: one description for screen readers, visuals hidden, captions not announced, CSS only", async ({ page }) => {
  await ready(page, "/");
  await expect(page.locator("#demo-desc")).toContainText("four steps");
  await expect(page.locator(".pd-visual")).toHaveAttribute("aria-hidden", "true");
  expect(await page.locator(".pd [aria-live], .pd [role=status], .pd [role=alert]").count()).toBe(0);
  expect(await page.locator(".pd video, .pd iframe, .pd canvas, .pd img").count()).toBe(0);
  expect(await running(page)).toBeGreaterThan(10);  // CSS animations, nothing else
});

test("hero demo: Pause/Play (WCAG 2.2.2), and it pauses on hover", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await ready(page, "/");
  await page.mouse.move(5, 5);
  const pause = page.getByRole("button", { name: "Pause demo" });
  await pause.click();
  await page.mouse.move(5, 5);
  await page.evaluate(() => (document.activeElement as HTMLElement).blur());  // away from the demo: still paused
  await expect(page.getByRole("button", { name: "Play demo" })).toBeVisible();
  expect(await running(page)).toBe(0);
  await page.getByRole("button", { name: "Play demo" }).click();
  await page.evaluate(() => (document.activeElement as HTMLElement).blur());
  await page.mouse.move(5, 5);
  await expect.poll(() => running(page)).toBeGreaterThan(10);
  await page.locator(".pd-phone").hover();
  await expect.poll(() => running(page)).toBe(0);
});

test("hero demo: a step chip jumps to its scene and keeps focus", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await ready(page, "/");
  await page.getByRole("button", { name: "Show step 3 Learn" }).click();
  await expect(page.locator("#pd-chip-3")).toBeFocused();
  await expect.poll(() => opacity(page, ".pd-screen > .sc:nth-child(3)")).toBeGreaterThan(0.9);  // the quiz
  expect(await opacity(page, ".pd-screen > .sc:nth-child(1)")).toBeLessThan(0.1);
  await page.keyboard.press("Tab");
  await page.keyboard.press("Enter");  // the 4th chip, from the keyboard
  await expect(page.locator("#pd-chip-4")).toBeFocused();
  await expect.poll(() => opacity(page, ".pd-screen > .sc:nth-child(4)")).toBeGreaterThan(0.9);  // the call-back
  await expect(page.locator(".pd-emergency")).toContainText("112");
});

test("hero demo: with reduced motion, scene 2 shows still", async ({ browser }) => {
  const page = await browser.newPage({ reducedMotion: "reduce" });
  await ready(page, "/");
  expect(await running(page)).toBe(0);
  expect(await opacity(page, ".pd-screen > .sc.s2")).toBe(1);
  for (const n of [1, 3, 4]) expect(await opacity(page, `.pd-screen > .sc:nth-child(${n})`)).toBe(0);
  expect(await opacity(page, ".pd-cap-k1")).toBe(1);
  await expect(page.getByRole("button", { name: "Pause demo" })).toBeHidden();
  await page.close();
});


test("Download for Android: the stable address, version, size, date, Android 7, three steps", async ({ page }) => {
  await page.route("**/downloads/latest.json", (r) => r.fulfill({ json: {
    version: "0.1.0+6", bytes: 35225883, date: "2026-10-26", min_android: "7.0", sha256: "ab".repeat(32) } }));
  await ready(page, "/android/");
  const button = page.getByRole("link", { name: "Download for Android" });
  await expect(button).toHaveAttribute("href", "/download/android");
  expect((await button.boundingBox())!.height).toBeGreaterThanOrEqual(64);
  for (const fact of ["Version 0.1.0+6", "34 MB", "Released 26 Oct 2026", "Android 7 or newer"]) {
    await expect(page.getByText(fact, { exact: true })).toBeVisible();
  }
  await expect(page.getByRole("heading", { name: "Install it in 3 steps" })).toBeVisible();
  await expect(page.locator(".download-steps li")).toHaveCount(3);
});

test("What to test: six tasks and Report a problem", async ({ page }) => {
  await ready(page, "/test/");
  await expect(page.locator(".test-tasks > li")).toHaveCount(6);
  for (const t of ["Read an English page", "Read a page with two columns", "Read a table", "Read a Hausa, Yorùbá or Igbo page",
                   "Read a page in airplane mode", "Read a medicine label"]) {
    await expect(page.getByRole("heading", { name: t })).toBeVisible();
  }
  await expect(page.getByText("Report a problem").first()).toBeVisible();
  await expect(page.getByRole("link", { name: "Download for Android" })).toHaveAttribute("href", "/download/android");
});
