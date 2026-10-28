# Infrastructure (test phase, free)

> **Since 28 Oct 2026.** The AWS account is suspended. A free Hugging Face Docker Space now needs a paid plan, so the API runs on an **Oracle Cloud Always Free** server in London. Nothing here costs money. One-time setup is in docs/DEPLOY.md; backups and restores are in docs/RESTORE.md.

## What runs where

| Address | What | Where | Free plan |
|---|---|---|---|
| **api.magana.ng** | The API: FastAPI with Tesseract and RapidOCR, all reading features, behind Caddy (TLS) | Oracle Cloud, **UK South (London)**, VM.Standard.A1.Flex: 2 OCPU, 12 GB, arm64, Ubuntu 24.04 (instance `magana-api`) | Always Free: up to 4 OCPU and 24 GB of A1 in all |
| (private) Neon project `magana` | The database (Postgres) | Neon, **AWS Europe (London), eu-west-2** | 0.5 GB; 100 CU-hours a month; the compute sleeps after 5 idle minutes |
| no-reply@magana.ng | Sign-in codes, invitations, school emails, alerts | Resend (sending in Ireland, eu-west-1) | 3,000 emails a month, 100 a day |
| (private) github.com/jemiridaniel/magana-backups | Encrypted daily database dumps, and an encrypted copy of the server's settings | GitHub | |
| magana.ng, app.magana.ng, teachers.magana.ng | The website, the tester PWA, the teacher portal | Cloudflare Pages (unchanged, docs/DEPLOY_PAGES.md) | |
| The Android APK | | GitHub Releases (unchanged, `scripts/publish-apk.sh`) | |

```
 app / PWA / portal ──HTTPS──▶ api.magana.ng: Caddy ──▶ API container (slot a or b) ──TLS──▶ Neon (London)
   X-Magana-Key, cookie        TLS, caller's address,   Tesseract, RapidOCR,              tables, quizzes,
                               "waking up" while         photos in memory only             proofs (encrypted)
                               restarting
 GitHub Actions: tests → tag "production" ─ ─ ─ ▶ (the server pulls it every minute)
                 daily backup ─▶ Neon ─▶ encrypted ─▶ magana-backups (private)
                 every 10 min: monitor ─▶ api.magana.ng/livez ─▶ email if down 30 min
```

## The server

- **Disposable.** Nothing on it is the only copy. The database is in Neon. The settings have a copy, encrypted, in the backups repository (and in `~/.magana/server.env`). The code is on GitHub. `scripts/server-setup.sh` rebuilds a new server from nothing in about 10 minutes (docs/RESTORE.md).
- **Set up by** `deploy/server/bootstrap.sh`, run through `scripts/server-setup.sh`. It is safe to run again, and it does the following:
  - **Updates:** security updates (Ubuntu's, Docker's and Caddy's) install by themselves every day (`unattended-upgrades`). If one needs a restart, it happens at 03:30 UTC.
  - **Firewall:**
    - Oracle's own iptables rules stay (`/etc/iptables/rules.v4`; they also protect the instance's metadata and boot volume). 80 and 443 are added before the final REJECT, live and in the saved file, so they survive restarts.
    - It doesn't use ufw: Oracle advises against it on these images.
    - Oracle's network security group lets in 80 and 443. SSH: see "SSH" below.
  - **SSH:** keys only, no root login, no passwords. fail2ban shuts out an address after 5 failed logins in 10 minutes: an hour the first time, longer each time it returns, up to a week.
  - **Tailscale** joins the server to your private network as `magana-api`, for SSH.
  - **Docker and Caddy:** both start at boot and restart if they stop (Caddy has `Restart=always`; containers have `--restart unless-stopped`).
- **Caddy** (`deploy/server/Caddyfile`):
  - **Certificate:** it gets and renews api.magana.ng's TLS certificate itself (Let's Encrypt).
  - **Caller's address:** it passes the caller's address to the API as `X-Forwarded-For`, replacing whatever the caller sent. The API's per-address limits depend on it.
  - **During a restart:** while no API container answers, it answers 503 `{"detail": {"code": "server_waking", "retry_after": 5}}`, with CORS for the portal. The app says "Magana is waking up, one moment…" and waits up to 60 s (`app/lib/api.dart`); a page photo is read on the phone meanwhile. The portal does the same (`portal/lib/server.ts`).
- **The API container:**
  - **Image and access:** built from `deploy/server/Dockerfile` on the server itself (arm64). It is published on 127.0.0.1 only.
  - **Locked down:** read-only, no Linux capabilities, at most 8 GB of memory.
  - **Settings:** from `/etc/magana/magana.env`, readable only by root, written by `scripts/server-env.sh --push`. They never go in the repository or an app.

  | Setting | What |
  |---|---|
  | `DATABASE_URL` | Neon, the **pooled** connection string |
  | `MAGANA_CODE_KEY` | Seals class codes, authenticator keys and proofs. **Without it the sealed data can't be opened.** Copies: `~/.magana/server.env`, and `settings/server.env.age` in the backups repository |
  | `MAGANA_API_KEY` | The app key in the testers' APK and IPA (from `~/.magana/app.env`, unchanged, so installed apps keep working) |
  | `MAGANA_WEB_API_KEY` | The PWA's and portal's key (also the GitHub secret of that name) |
  | `RESEND_API_KEY`, `RESEND_WEBHOOK_SECRET` | Sending (magana.ng only), and checking Resend's bounce and complaint events |
  | `WHATSAPP_*`, `EXPLAIN_*`, `IBA_*` | Optional, as before |
  | Fixed (not secret) | `MAGANA_ENV=production`, `MAGANA_MAIL=resend`, `MAIL_FROM`, `MAGANA_PORTAL_URL`, `MAGANA_CORS_ORIGIN_REGEX`, `EXPLAIN_ENGINE=stub` |

  Without `DATABASE_URL`, the API uses a SQLite file in the Docker volume `magana-data`. That is only for before Neon is set up: nothing made then is moved to Neon.
- **What the API does itself:**
  - **CORS** for teachers.magana.ng, magana.ng, www.magana.ng and app.magana.ng, with credentials (`MAGANA_CORS_ORIGIN_REGEX`).
  - **Rate limits** per address and per device, with daily caps (`backend/app/ratelimit.py`).
  - These used to be repeated in a Cloudflare Worker in front of the Hugging Face Space. Without the Space there is nothing for a Worker to add, so it is gone.
- **Logs:**
  - **Where:** `sudo docker logs magana-api-a` (or `-b`), rotated at 5 × 20 MB. Deploys are logged in `/var/lib/magana/deploy.log`.
  - **What's in them:** they never hold photos, page text, recordings or quick-check answers, as before. They do hold callers' internet addresses (docs/PRIVACY.md).
- **Ibà is not run in the test phase.** `IBA_API_URL` is unset, so the quick check uses Magana's own danger-sign rules (`triage.py`). That is the fallback CLAUDE.md rule 7 describes.

### Why the DNS record is "DNS only"

`api.magana.ng` is an A record to the server, **DNS only** (grey cloud):
- **The certificate:** Caddy gets and renews its own certificate directly. Behind Cloudflare's proxy, Let's Encrypt's HTTP check can be redirected by zone settings such as "Always Use HTTPS". Renewals would then fail silently 60 days later.
- **The caller's address:** the API sees the real caller's address with nothing to trust or configure. Its rate limits depend on it.
- **No proxy limits:** none of Cloudflare's 100 MB upload cap or 100-second response limit.
- **What it costs:**
  - No Cloudflare DDoS shield, and the server's address is public. The API's own rate limits and daily caps are the protection, as on AWS.
  - **Switching to proxied later:** set **SSL/TLS → Full (strict)** first. Caddy already believes `CF-Connecting-IP` only from Cloudflare's addresses (the `trusted_proxies` list in the Caddyfile). Then check that a renewal works.

## Deploys and rollbacks

The server pulls; GitHub never logs in to it and holds no key to it. So nothing in a deploy needs SSH, and port 22 can be closed to the internet ("SSH" below).
1. On every push to main, once every test passes, the CI job `deploy` moves the git tag **`production`** to the commit. That is the only thing CI can change, and it uses `contents: write` for this repository only.
2. Every minute, `magana-deploy` on the server reads the tag from the public repository (`magana-deploy.timer`; no key, no account).
3. **A new commit:**
   1. It is checked out and built as `magana-api:<commit>`. That takes 1–2 minutes, or several when requirements change.
   2. It is started in the free slot (a: 8001, b: 8002) next to the live one.
   3. It must answer `/health` with its commit and `database: ok` within 3 minutes.
4. **Good:**
   1. The old slot stops gracefully (60 s for requests in progress). Caddy sends everything to the new one, and must answer with it within 30 s.
   2. Then the Caddyfile, `magana-deploy` and its timer are updated from that commit; the Caddyfile only if `caddy validate` passes.
   3. Then old images are pruned: the last 3 are kept, for fast rollbacks.
5. **Bad:**
   - **Automatic rollback:** the new container is removed, and the old one never stopped serving. If Caddy couldn't reach the new one, the old one is started again.
   - The commit is marked failed and not tried again (`sudo magana-deploy --force` retries it).
6. **CI waits:**
   - It reads `https://api.magana.ng/deploy-status` (states and commits only) for up to 30 minutes, and fails at once if the server refused the commit.
   - Then it checks `/health` and that calls without the app key still get 401 (`scripts/wait-for-deploy.sh`).

**Rolling back by hand:** **GitHub → Actions → Rollback → Run workflow**, with an earlier commit on main. It moves the tag back, and the server switches within a minute; recent commits need no rebuild. The next push to main deploys as usual. On the server: `sudo magana-deploy --status`.

**New settings:** `scripts/server-env.sh --push` (or `sudo nano /etc/magana/magana.env` on the server, then `sudo magana-deploy --restart`). The restart works the same way: a new container with the new settings, checked before the old one stops. If the check fails, the old settings stay live.

## SSH

You move between places, so SSH isn't limited to one home address. It goes over **Tailscale** instead (free personal plan): a private network between your computers and the server, encrypted end to end.
- **The server's name** on it is `magana-api` (MagicDNS), so `ssh -i ~/.ssh/magana_oracle.key ubuntu@magana-api` works from anywhere your Mac has Tailscale on.
- **The scripts** (`server-setup.sh`, `server-env.sh`, `team-setup.sh`, `server-ssh.sh`) use `magana-api` by default. `MAGANA_SERVER=<address>` overrides it, for example for a brand-new server.
- **The firewall:** anything arriving on the `tailscale0` interface is let in (iptables, before the final REJECT).
- **Port 22 from the internet: closed since 28 Oct 2026** (Tailscale only). Checked from outside: 22 doesn't answer; 80 and 443 do. It had been open, guarded by fail2ban, until `/etc/magana/ssh-tailscale-only` was created. `scripts/server-ssh.sh --tailscale-only` sets it, and refuses unless it is itself running over Tailscale, so it can't lock you out. The rule is then removed live and from the saved rules, and bootstrap keeps it removed. Oracle's security list rule for 22 is removed too (docs/DEPLOY.md, step 3), so 22 is closed at two layers. 80 and 443 stay open.
  - **Not ufw:** Oracle advises against ufw on these images, so the host firewall stays Oracle's iptables rules, changed the same way as for 80 and 443.
- **What doesn't use SSH:**
  - Deploys: the server pulls the `production` tag over HTTPS.
  - The monitor: `https://api.magana.ng/livez` and `/health`.
  - Backups: GitHub talks to Neon and the backups repository, never to the server.
  - CI's wait: `https://api.magana.ng/deploy-status`.

  None of them change when port 22 closes.
- **Two Tailscale settings that matter** (docs/DEPLOY.md, step 3):
  - **Key expiry is turned off for `magana-api`.** Otherwise Tailscale drops the server from the network after 180 days.
  - **The server's connection** goes out through Tailscale's relays, or direct where possible. No inbound port is opened for it.
- **Locked out** (Tailscale down, or its sign-in lost):
  - Oracle's console connection still reaches the server (docs/RESTORE.md). It needs the `ubuntu` password set beforehand (docs/DEPLOY.md, step 3b). SSH never accepts passwords.
  - From there, `sudo rm /etc/magana/ssh-tailscale-only` and the port 22 rule reopen SSH.

## Oracle's idle reclaim

- **The rule** (Oracle's Always Free documentation, read 28 Oct 2026): an Always Free instance counts as idle if, over 7 days, all three of these are under 20%:
  - CPU use, at the 95th percentile;
  - network use;
  - memory use (A1 shapes only).
- **What happens:** idle instances may be stopped ("reclaimed"). Oracle's notice says a stopped instance can be started again if the shape is available. Its earlier announcement also mentions termination.
- **Magana will look idle.** During testing, the CPU is mostly quiet between readings, and the API uses 1–2 GB of the 12 GB. So the risk is real on a free-tier account.
- **Accounts on Pay As You Go are not reclaimed**, but upgrading puts a hold of about €93 on the card. **Decision (28 Oct 2026): the account stays on the free tier for now.**
- **No fake load.** We don't run a load generator to look busy. It wastes the free capacity, and Oracle may treat it as abuse.
- **If Oracle stops the instance:**
  1. The monitor emails within about 30 minutes ("Magana API is down").
  2. Open **Oracle Cloud → Compute → Instances → magana-api** and choose **Start**.
  3. **Nothing else is needed.** Everything comes back by itself:
     - Docker, containerd, Caddy, `magana-deploy.timer`, the saved firewall rules (`netfilter-persistent`) and unattended upgrades are all enabled at boot.
     - The API container has `--restart unless-stopped`.
     - A minute after boot, the timer checks that the `production` commit is the one running, and deploys it if not.
  4. Tested on 28 Oct 2026 with a full restart. Within about a minute: Docker, Caddy and the timer were active, the 80/443 rules were back, the container was healthy, and port 80 answered from outside.
  5. Oracle keeps the instance's public address through a stop and start; it is released only when the instance is terminated. So the DNS record needs no change. If the address ever does change, point the `api` A record at the new one (docs/DEPLOY.md, step 1).
  6. The monitor sends "back up" once it answers again.
- **If Oracle terminates it,** or the account is lost: `scripts/server-setup.sh` makes a new server (docs/RESTORE.md). No data is on it.

## The database

- **Neon, Postgres, London.**
  - The code still writes SQLite's SQL (development and tests use a SQLite file). `backend/app/database.py` translates it for Postgres when `DATABASE_URL` is set.
  - Every backend test runs on both, in CI (a Postgres 16 service) and on the Mac (`MAGANA_TEST_DATABASE_URL=… pytest`).
- **Schema:** created by the API on first use, then extended by the same migration code as before (`accounts._migrate`). There is no separate migration step.
- **Connections:**
  - A small pool (`psycopg_pool`, up to 4, `DATABASE_POOL_SIZE`) through Neon's pooler (host with `-pooler`).
  - Idle connections close after 2 minutes, so the compute can scale to zero. Server and database are both in London, so a new connection takes milliseconds.
- **Neon's free compute hours:**
  - 100 CU-hours a month is about 400 hours at the smallest size, and a month has 730. So the database must sleep more than half the time.
  - Frequent checks therefore never touch it: Caddy, Docker and the monitor call `/livez` (no query). `/health` (with a query) is called by deploys, and once an hour by the monitor.

## Backups

`.github/workflows/backup.yml`, every day at 02:40 UTC, on GitHub. So it works even if the server, or the whole Oracle account, is gone.
1. `pg_dump` (Postgres 18 client) of the whole database, checked as a readable dump with tables.
2. Encrypted with `age` to the public key in `deploy/backup/age-recipient.txt`, before it leaves the job. Only the private key opens it; it is kept in the password manager and in `~/.magana/backup-age-key.txt`.
3. Pushed to the **private** repository jemiridaniel/magana-backups with a deploy key that can write to that one repository only (`BACKUP_DEPLOY_KEY`).
   - **Kept:** 30 daily dumps, and the first of each month for 12 months.
   - **Size:** the repository holds one commit with only what is kept, so it doesn't grow forever.
4. **If it fails:** an email to ALERT_EMAIL. The earlier backups are untouched.

Neon's own short restore window (Backup & Restore in its console) is a second line, for undoing a mistake made today.

## Monitoring

`.github/workflows/monitor.yml`, every 10 minutes, on GitHub.
- **The check:** `/livez`, 3 tries over a minute; once an hour, also `/health` with the database.
- **The alert:**
  - If this run and the failed runs just before it cover **30 minutes or more**, it emails `ALERT_EMAIL` (daniel@magana.ng) through Resend. It emails again every 6 hours while the API is down, and once when it is back.
  - GitHub may start scheduled runs some minutes late, so an alert can come a little after 30 minutes.
- **Keeping the schedules on:** GitHub turns off scheduled workflows in a repository with no activity for 60 days. A push keeps them on.

## Email

- **Sending:** Resend sends from no-reply@magana.ng (`mailer._resend`).
  - Its DNS records sit on the `send` subdomain and on `resend._domainkey` (docs/DEPLOY.md, step 6).
  - Cloudflare Email Routing for incoming mail is unchanged.
- **Bounces and complaints:**
  - Resend posts them to `https://api.magana.ng/internal/mail-events`, signed the Svix way.
  - The API checks the signature and its age (5 minutes), then marks the address undeliverable (`mail_events.py`).
- **Weekly check:** bounce and complaint rates over 7 days, from the API's own daily counts. If bounces pass 2% or complaints 0.05%, it emails daniel@magana.ng (`mail_health.py`).

## Limits to know (free plans)

- **Oracle:**
  - Reclaim of idle instances on free-tier accounts (above).
  - 2 OCPU for everything: a burst of many readings at once queues.
  - A deploy that changes requirements takes several minutes to build. The old version keeps serving meanwhile.
- **Neon:** 0.5 GB of storage, and 100 CU-hours a month. The first query after 5 idle minutes takes about a second longer.
- **Resend:** 100 emails a day. A busy sign-in morning for many schools could reach it; the portal then says the code couldn't be sent.
- **Older APKs:** builds older than 0.1.0+3, which used the old sslip.io address, no longer reach the server. Every build since uses api.magana.ng and keeps working.
