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

// Test team accounts: [email, role]. Each browser project has its own owner, and approvals go
// through their own reviewer, so no two sign-ins ever race for one account's codes.
export const TOTP_SECRET = "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP";
export const TEAM_ACCOUNTS: [string, string][] = [
  ["team@magana.test", "owner"], ["team-phone@magana.test", "owner"], ["approver@magana.test", "reviewer"],
  ["support@magana.test", "support"],
];

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
      // The Magana team's test accounts first, with the server's own setup command (development
      // flags: a role and a known authenticator key), then the API.
      command: ["cd ../backend",
                ...TEAM_ACCOUNTS.map(([email, role]) =>
                  `.venv/bin/python -m app.team_setup --email ${email} --name "${role} ${email.split("@")[0]}" --role ${role} --totp-secret ${TOTP_SECRET} >/dev/null 2>&1`),
                `exec .venv/bin/uvicorn app.main:app --port ${API_PORT}`].join("; "),
      url: `http://localhost:${API_PORT}/health`,
      env: { MAGANA_ENV: "development", MAGANA_API_KEY: "", MAGANA_MAIL: "outbox", MAGANA_DATA_DIR: dataDir,
             MAGANA_DEV_SIGNIN_LIMIT: "10000", MAGANA_DEV_REGISTER_LIMIT: "10000",
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
