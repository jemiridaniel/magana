// End-to-end checks of the portal against a real Magana backend, at the two sizes the
// design is checked at. `npm run test:e2e` starts both servers (backend in development
// mode, with an empty data folder of its own).
import { defineConfig } from "@playwright/test";
import os from "node:os";
import path from "node:path";

const API_PORT = 8766;
const PORTAL_PORT = 3101;
// Set once by the runner; its workers inherit it, so every process reads the same outbox.
process.env.MAGANA_E2E_DATA ??= path.join(os.tmpdir(), `magana-portal-e2e-${process.pid}`);
export const dataDir = process.env.MAGANA_E2E_DATA;

export default defineConfig({
  testDir: "e2e",
  workers: 1,
  timeout: 60_000,
  use: { baseURL: `http://localhost:${PORTAL_PORT}`, channel: "chrome" },
  projects: [
    { name: "desktop", use: { viewport: { width: 1280, height: 900 } } },
    { name: "phone", use: { viewport: { width: 390, height: 844 } } },
  ],
  webServer: [
    {
      command: `../backend/.venv/bin/uvicorn app.main:app --app-dir ../backend --port ${API_PORT}`,
      url: `http://localhost:${API_PORT}/health`,
      env: { MAGANA_ENV: "development", MAGANA_API_KEY: "", MAGANA_MAIL: "outbox", MAGANA_DATA_DIR: dataDir,
             // One team email per browser project and per worker: parallel sign-ins never replace each other's code.
             MAGANA_TEAM_EMAILS: ["team@magana.test", "team-phone@magana.test",
                                  ...Array.from({ length: 8 }, (_, i) => `approver-${i}@magana.test`)].join(","), MAGANA_DEV_SIGNIN_LIMIT: "10000", MAGANA_DEV_REGISTER_LIMIT: "10000",
             MAGANA_DEV_CODE_GAP: "0", MAGANA_DEV_CODES_PER_HOUR: "10000",
             MAGANA_CORS_ORIGIN_REGEX: `http://localhost:${PORTAL_PORT}` },
      reuseExistingServer: !!process.env.E2E_REUSE,  // E2E_REUSE=1: servers you started (to read their logs)
    },
    {
      command: `npx next dev --port ${PORTAL_PORT}`,
      url: `http://localhost:${PORTAL_PORT}/quizzes`,
      env: { NEXT_PUBLIC_API_URL: `http://localhost:${API_PORT}` },
      reuseExistingServer: !!process.env.E2E_REUSE,  // E2E_REUSE=1: servers you started (to read their logs)
      timeout: 120_000,
    },
  ],
});

export const apiUrl = `http://localhost:${API_PORT}`;
