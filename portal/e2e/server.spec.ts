// The portal lives on Cloudflare Pages and stays up when the API server is stopped: it must
// say so clearly ("Magana's server is sleeping"), in an alert, never a blank error.
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { apiUrl } from "../playwright.config";

test("API down: the portal says the server is sleeping, in an alert, and Try again checks", async ({ page }) => {
  await page.route(`${apiUrl}/**`, (route) => route.abort("connectionrefused"));
  await page.goto("/quizzes");
  const alert = page.getByRole("alert").filter({ hasText: "Magana’s server is sleeping. Please try again later." });
  await expect(alert).toBeVisible();
  const axe = await new AxeBuilder({ page: page as never }).withTags(["wcag2a", "wcag2aa", "wcag2aaa"]).analyze();
  expect(axe.violations.map((v) => v.id)).toEqual([]);

  await page.unroute(`${apiUrl}/**`);
  await alert.getByRole("button", { name: "Try again" }).click();
  await expect(alert).toBeHidden();
  // Awake again: the portal carries on (to sign in, as nobody is signed in here).
  await page.getByRole("button", { name: "Open the portal again" }).click();
  await expect(page).toHaveURL(/\/sign-in\/?$/);
});

test("a 503 page from the proxy counts as asleep too", async ({ page }) => {
  await page.route(`${apiUrl}/**`, (route) => route.fulfill({ status: 503, body: "<html>Service Unavailable</html>" }));
  await page.goto("/quizzes");
  await expect(page.getByRole("alert").filter({ hasText: "sleeping" })).toBeVisible();
});
