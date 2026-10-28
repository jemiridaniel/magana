# Infrastructure (test phase, free)

> **Since 28 Oct 2026.** The AWS account is suspended, so the API moved to free services for the test phase. No paid service is used. The steps to set it up are in docs/DEPLOY.md, and backups and restores in docs/RESTORE.md.

## What runs where

| Address | What | Where | Free plan |
|---|---|---|---|
| **api.magana.ng** | A Cloudflare Worker (`cloudflare/api-proxy`) in front of the API | Cloudflare, every location | 100,000 requests a day |
| (private) `https://<owner>-magana-api.hf.space` | The API: FastAPI with Tesseract and RapidOCR, all reading features | A **private** Hugging Face Space, Docker, CPU basic (2 vCPU, 16 GB), United States | Sleeps after 48 h without a request |
| (private) Neon project `magana` | The database (Postgres) | Neon, **AWS Europe (London), eu-west-2** | 0.5 GB; the compute pauses after 5 idle minutes and resumes in about a second |
| no-reply@magana.ng | Sign-in codes, invitations, school emails | Resend (sending in Ireland, eu-west-1) | 3,000 emails a month, 100 a day |
| magana.ng, app.magana.ng, teachers.magana.ng | The website, the tester PWA, the teacher portal | Cloudflare Pages (unchanged, docs/DEPLOY_PAGES.md) | |
| The Android APK | | GitHub Releases (unchanged, `scripts/publish-apk.sh`) | |

```
 app / PWA / portal ──HTTPS──▶ api.magana.ng (Cloudflare Worker) ──HTTPS + HF token──▶ private Space ──TLS──▶ Neon (London)
   X-Magana-Key, cookie            CORS, limits, "waking up"                          Tesseract, RapidOCR      tables, quizzes,
                                                                                       photos in memory         proofs (encrypted)
```

## The Worker on api.magana.ng

`cloudflare/api-proxy/src/index.js`, deployed by CI with wrangler.
- **The token:** it adds the Space's access token from the Worker secret `HF_TOKEN`. The token is read-only, for this one Space. It is never sent to a client, and the Space answers nobody without it (CI checks it refuses).
- **Passed through unchanged:** Magana's own app key (`X-Magana-Key`), the portal's sign-in cookie, and request bodies, streamed, so large photos and PDFs work (up to Cloudflare's 100 MB).
- **The caller's address:** it sets `X-Forwarded-For` itself and drops the caller's own, so the server's per-address limits see the real caller.
- **Rate limits:** 300 requests a minute per address, and 30 a minute for reading, speech, Explain and uploads. These are counted per Cloudflare location. The server keeps its own finer limits per device and per day (`backend/app/ratelimit.py`). Over the limit: 429 `too_many_requests`.
- **CORS:** answered here for teachers.magana.ng, magana.ng, www.magana.ng and app.magana.ng, with credentials. Preflights never wake the Space.
- **Cold start:** a Space that is asleep, starting or building answers with a page that isn't JSON. The Worker turns that into 503 `{"detail": {"code": "server_waking", "retry_after": 5}}`.
  - The app says "Magana is waking up, one moment…" and waits up to 60 s (`app/lib/api.dart`). A page photo is read on the phone meanwhile, as when the server is slow ("Magana's server was waking up, so this page was read on this phone").
  - The portal shows the same in an alert and tries again for up to 60 s (`portal/lib/server.ts`).
- **A refused token:** if Hugging Face refuses the token (wrong or expired), the Worker answers 502 `server_unavailable`, never Hugging Face's page.

## The Space

- **Image:** built from `deploy/hf-space/Dockerfile`. CI assembles the folder with `scripts/build-space.sh`: the backend's code and requirements, `content/`, and the commit as `app/build.txt`. It runs as user 1000 on port 7860.
- **Disk is not permanent.** Nothing important is written to it:
  - The database is outside (`DATABASE_URL`).
  - Teachers' quizzes, proof-of-school files (encrypted) and WhatsApp's profiles, call-back requests and monthly count live in the database's `blobs` table (`backend/app/blobs.py`). They used to be files on the AWS disk.
  - Photos and PDFs are read in memory only, as before.
  - The second OCR engine reads in a child process through a pipe (`second_ocr.py`).
- **Secrets** are Space secrets, set from this Mac by `scripts/space_secrets.py`. They are never in the repository or an app.

  | Secret | What |
  |---|---|
  | `DATABASE_URL` | Neon, the **pooled** connection string |
  | `MAGANA_CODE_KEY` | Seals class codes, authenticator keys and proofs. **Keep a copy in `~/.magana/space.env`:** without it, the sealed data can't be opened |
  | `MAGANA_API_KEY` | The app key in the testers' APK and IPA (from `~/.magana/app.env`, unchanged, so installed apps keep working) |
  | `MAGANA_WEB_API_KEY` | The PWA's and portal's key (also the GitHub secret of that name) |
  | `RESEND_API_KEY` | Sending only, for magana.ng only |
  | `RESEND_WEBHOOK_SECRET` | Checks Resend's bounce and complaint events (`whsec_…`) |
  | `WHATSAPP_*`, `EXPLAIN_*` | Optional, as before |

  Variables (not secret): `MAGANA_ENV=production`, `MAGANA_MAIL=resend`, `MAIL_FROM`, `MAGANA_PORTAL_URL`, `MAGANA_CORS_ORIGIN_REGEX`, `EXPLAIN_ENGINE`.
- **Ibà is not run in the test phase.** `IBA_API_URL` is unset, so the quick check uses Magana's own danger-sign rules (`triage.py`), the fallback CLAUDE.md rule 7 describes. Running Ibà would need a second private Space and the iba-natlas repository; it is left for later.
- **Logs:** Hugging Face → the Space → Logs. They are kept only while it runs. They never hold photos, page text, recordings or quick-check answers, as before.

## The database

- **Neon, Postgres, London.**
  - The code still writes SQLite's SQL (development and tests use a SQLite file). `backend/app/database.py` translates it for Postgres when `DATABASE_URL` is set: placeholders, INSERT OR REPLACE, the schema types.
  - Every backend test runs on both, in CI (a Postgres 16 service) and on the Mac (`MAGANA_TEST_DATABASE_URL=… pytest`).
- **Schema:** created by the server on first use, then extended by the same migration code as before (`accounts._migrate`). There is no separate migration step.
- **Connections:** a small pool (`psycopg_pool`, 4 by default, `DATABASE_POOL_SIZE`). The database is in London and the server in the US, so a new TLS connection per request would add about 0.3 s. Prepared statements are off, for Neon's pooler.
- **The pooler:** the pooled connection string (host with `-pooler`, `sslmode=require`) goes through PgBouncer, so a burst of requests never runs out of connections.

## Email

- **Sending:** Resend sends from no-reply@magana.ng (`mailer._resend`). Its DNS records sit on the `send` subdomain and on `resend._domainkey` (docs/DEPLOY.md, step 4). Cloudflare Email Routing for incoming mail is unchanged.
- **Bounces and complaints:** Resend posts them to `https://api.magana.ng/internal/mail-events`, signed the Svix way. The server checks the signature and its age (5 minutes), then marks the address undeliverable, as before (`mail_events.py`). The app key isn't needed there; the signature is.
- **Weekly check:** bounce and complaint rates over 7 days, from the server's own daily counts (`mail_counts`; under 20 emails is too few to judge). If bounces pass 2% or complaints 0.05%, it emails daniel@magana.ng (`mail_health.py`). This replaces SES's CloudWatch metrics.

## Keep-awake and alerts

`.github/workflows/keep-awake.yml` calls `https://api.magana.ng/health` every 6 hours.
- **The check:** `/health` answers `status`, `database` (a real query) and `build` (the commit). A sleeping Space gets 2 minutes to wake.
- **Why every 6 hours:** a free Space sleeps after 48 hours without a request, so the Space never sleeps for long. It also keeps the Neon project in use.
- **Alerts:** if this check and the previous one both fail, it emails `ALERT_EMAIL` (daniel@magana.ng) through Resend, with the GitHub secret `RESEND_API_KEY`. It goes on emailing every 6 hours until the API is healthy again.

## Deploys

On every push to main, once all tests pass (`.github/workflows/ci.yml`, job `space`):
1. The bundle is pushed to the Space's repository with `HF_DEPLOY_TOKEN`, write access to that Space only. The Space then rebuilds itself, in about 5 to 10 minutes.
2. The Worker is deployed with wrangler.
3. CI waits until `/health` answers with the new commit and `database: ok`, for up to 20 minutes. Then it checks from outside: no app key means 401, and the bare Space refuses anyone without the token.

There is no automatic rollback: if a deploy is broken, revert the commit and push. The Space rebuilds the previous code.

## Limits to know (free plans)

- **Hugging Face:** CPU basic is shared, so a busy moment can be slower. The Space restarts on every deploy, and reading is unavailable for the few minutes of a rebuild (the app reads on the phone meanwhile). Hugging Face may change free plans.
- **Neon:** 0.5 GB of storage, and limited compute hours each month (plenty for testing). The first query after 5 idle minutes takes about a second longer.
- **Resend:** 100 emails a day. A busy sign-in morning for many schools could reach it; the portal then says the code couldn't be sent.
- **Cloudflare Workers:** 100,000 requests a day.
- **Older APKs:** builds older than 0.1.0+3, which used the old sslip.io address, no longer reach the server. Every build since uses api.magana.ng and keeps working.
