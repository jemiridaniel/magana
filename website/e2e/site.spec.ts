import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import samples from "../data/samples.json";

const PAGES = ["/", "/privacy/", "/accessibility/", "/android/"];
const WIDTHS = [
  { name: "desktop", width: 1280, height: 900 },
  { name: "phone", width: 390, height: 844 },
];

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
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      expect(overflow).toBeLessThanOrEqual(0);
    });
  }
}

test("loader: a progressbar in the first HTML, at least 0.8 s on screen, then gone", async ({ page, request }) => {
  const html = await (await request.get("/")).text();
  expect(html).toContain('role="progressbar"');
  expect(html).toContain('aria-label="Loading Magana"');
  expect(html.indexOf('id="mg-loader"')).toBeLessThan(html.indexOf("/_next/static/chunks/") === -1 ? Infinity : html.lastIndexOf("<main"));
  await ready(page, "/");
  const info = await page.evaluate(() => (window as unknown as { __mgLoader: { shownMs: number; slow: boolean } }).__mgLoader);
  expect(info.shownMs).toBeGreaterThanOrEqual(800);
  // Finished on real progress, not on the 20 s fallback (a nomodule script once held it there).
  expect(info.shownMs).toBeLessThan(8000);
  expect(info.slow).toBe(false);
  expect(await page.locator("[data-dot][data-on]").count()).toBe(14);
  expect(await page.locator("[data-letter][data-on]").count()).toBe(6);
  expect(await page.locator("[data-progress]").getAttribute("aria-valuenow")).toBe("100");
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
