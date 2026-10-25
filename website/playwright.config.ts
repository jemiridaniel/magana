import { defineConfig } from "@playwright/test";

// Checks the built site (out/) in the installed Chrome: npx next build && npx playwright test
// SITE_URL=https://magana.ng runs the same checks against the live site.
const url = process.env.SITE_URL ?? "http://127.0.0.1:4321";

export default defineConfig({
  testDir: "e2e",
  timeout: 60_000,
  use: { baseURL: url, channel: "chrome" },
  webServer: process.env.SITE_URL
    ? undefined
    : { command: "python3 -m http.server 4321 --bind 127.0.0.1 --directory out", url, reuseExistingServer: true },
});
