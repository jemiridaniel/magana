# Setting up the test-phase hosting (Oracle Cloud, Neon, Resend)

What runs where, and why, is in docs/INFRA.md. These are the one-time steps, in order. Everything here is free.

**Before you start:**
- **There is no backup to restore.** The only database was on the AWS server. The test phase starts with a clean database, and step 9 makes the first Magana admin.
- **Keep every value you copy out of chat and out of the repository.** Values go only into `~/.magana/server.env`, into a dashboard, or into your password manager.

**Already done** (by `scripts/server-setup.sh`, 28 Oct 2026), on the server `magana-api` (143.47.239.12):
- updates, including daily security updates with a 03:30 UTC restart when one is needed;
- the firewall (80, 443 and SSH, kept across restarts) and SSH hardening;
- Docker, Caddy, and the deploy timer;
- its first settings: the two keys made here, and the app key.

To redo it on a new server: `MAGANA_SERVER=<address> scripts/server-setup.sh`, then `MAGANA_SERVER=<address> scripts/server-env.sh --push`.

## 1. DNS for api.magana.ng (Cloudflare)

1. Open **dash.cloudflare.com → magana.ng → DNS → Records**.
2. Find the **A** record **`api`** (it still points at the old AWS address, 35.178.64.255). Choose **Edit**:
   - **Type:** A. **Name:** `api`. **IPv4 address:** `143.47.239.12`.
   - **Proxy status:** **DNS only** (grey cloud). Turn the orange cloud off. docs/INFRA.md explains why.
   - **TTL:** Auto. Then **Save**.
3. Delete any **AAAA** record named `api` (the server has no IPv6 address).

Within a few minutes, Caddy on the server gets api.magana.ng's certificate by itself.

## 2. Oracle: staying on the free tier

**Decision (28 Oct 2026): the account stays on the free tier.** Upgrading to Pay As You Go would stop idle reclaim, but it puts a hold of about €93 on the card.

Oracle may stop the instance for looking idle: under 20% CPU, network and memory over 7 days (docs/INFRA.md). If it does:
1. The monitor emails you within about 30 minutes.
2. Open **cloud.oracle.com → ☰ → Compute → Instances → magana-api** and choose **Start**.
3. That's all. Docker, Caddy, the API and the deploy timer come back by themselves within about a minute (tested with a full restart), and the monitor emails "back up".

To upgrade later: **☰ → Billing & Cost Management → Upgrade and Manage Payment → Pay As You Go**. Keep the $1 budget alert, and create nothing beyond Always Free.

## 3. SSH over Tailscale, then close port 22 to the internet

Already done on the server:
- fail2ban guards SSH;
- Tailscale is installed and waiting to be joined to your network as `magana-api`.

**a. Your Tailscale network, and the server in it:**
1. Open the sign-in link Claude gave you (from `sudo tailscale up --hostname magana-api` on the server). Sign in with Google, GitHub or Microsoft; this creates your free tailnet. Choose **Connect**.
   - If the link has expired, ask for a new one, or run that command on the server yourself.
2. Open **login.tailscale.com/admin/machines → magana-api → ⋯ → Disable key expiry**. Otherwise the server drops off after 180 days.
3. **DNS** tab: check that **MagicDNS** is on (it is by default).

**b. Your Mac:**
1. Install Tailscale: the **Mac App Store** ("Tailscale"), or `brew install --cask tailscale`.
2. Open it from Applications. Allow the VPN configuration when macOS asks, then **Log in** with the **same account** as in a1.
3. In a terminal:
   ```bash
   ssh -i ~/.ssh/magana_oracle.key ubuntu@magana-api 'echo "$SSH_CONNECTION" | cut -d" " -f1'
   ```
   It should print an address starting with `100.`. That means the connection went over Tailscale.
4. **Set a console password**, the way back in if Tailscale ever fails (docs/RESTORE.md):
   1. Run `ssh -t -i ~/.ssh/magana_oracle.key ubuntu@magana-api sudo passwd ubuntu`.
   2. Choose a long password and keep it in your password manager.
   3. SSH still refuses passwords; this one works only on Oracle's console.
5. **Tell Claude it works.** Then Claude runs (or you run) `scripts/server-ssh.sh --tailscale-only`. It closes port 22 on the server itself, and refuses unless run over Tailscale.

**c. Oracle's security list (after b5):**
1. Open **☰ → Networking → Virtual cloud networks →** your VCN **→ Security** tab **→ Security Lists → Default Security List for …**.
2. Under **Security rules → Ingress rules**, find the rule with **Destination port 22**. Choose **⋮ → Remove**.
3. Leave the network security group `ig-quick-action-NSG` (80 and 443 from anywhere) as it is.

**Other computers or a phone:** install Tailscale and log in with the same account, then copy `~/.ssh/magana_oracle.key` to that computer.

## 4. The database: Neon (London)

**Why Neon:** it has a London region, next to the server, and an IPv4 address. Its database is never paused for being unused; only its compute sleeps, and it wakes on the next query.

1. Sign up at **neon.tech** (GitHub sign-in is fine).
2. **Create project:**
   - **Project name:** `magana`.
   - **Postgres version:** the default.
   - **Cloud provider:** **AWS**. **Region:** **AWS Europe (London) eu-west-2**.
   - Choose **Create project**.
3. On the project's dashboard, choose **Connect**:
   - **Branch:** `production`. **Database:** `neondb`. **Role:** `neondb_owner`.
   - Turn **Connection pooling** **on**.
   - Copy the connection string (`postgresql://neondb_owner:…@ep-…-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require`).
   - Paste it into `~/.magana/server.env` as `DATABASE_URL`.
4. **Settings → Compute:** leave **Scale to zero** on.

The tables are created by the API itself. There is no migration to run.

## 5. The backups repository (private)

1. Open **github.com/new** (signed in as **jemiridaniel**).
2. **Repository name:** `magana-backups`. **Visibility:** **Private**. Tick **Add a README file**. Choose **Create repository**.
3. In a terminal:
   ```bash
   cd ~/Desktop/Personal\ Project/magana
   scripts/backup-setup.sh
   ```
   This gives the backup workflow a key that can write to that one repository only.
4. **Put the backup key in your password manager.**
   - Open `~/.magana/backup-age-key.txt` and copy all of it into a new secure note, "Magana backup key".
   - **Without it, no backup can be opened.** It is the only copy besides this Mac.

## 6. Email: Resend for no-reply@magana.ng

**a. The domain:**
1. Sign up at **resend.com**.
2. Go to **Domains → Add Domain**. **Name:** `magana.ng`. **Region:** **Ireland (eu-west-1)**. Choose **Add**.
3. Resend shows three records. Add each one in **Cloudflare → magana.ng → DNS → Records → Add record**. Every one is **DNS only**, TTL Auto.

   | Type | Name | Content | Priority |
   |---|---|---|---|
   | TXT | `resend._domainkey` | the long `p=…` value Resend shows (copy it exactly) | |
   | MX | `send` | `feedback-smtp.eu-west-1.amazonses.com` | 10 |
   | TXT | `send` | `v=spf1 include:amazonses.com ~all` | |

   These sit on the `send` subdomain and the DKIM name, so magana.ng's own MX records are untouched: **Cloudflare Email Routing keeps working**.
4. **Edit the root SPF record** (TXT, name `magana.ng`):
   - **Today:** `v=spf1 include:_spf.mx.cloudflare.net include:amazonses.com include:_spf.google.com ~all`
   - **Change it to:** `v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all`
5. **Fix DMARC: magana.ng has two DMARC records, which counts as none.**
   - Delete both `_dmarc` TXT records.
   - Add one: TXT, name `_dmarc`, content `v=DMARC1; p=none; rua=mailto:support@magana.ng`.
6. Back in Resend, choose **Verify DNS Records**. It turns **Verified** within minutes, sometimes up to an hour.

**b. The sending key:**
1. Go to **API Keys → Create API Key**.
2. **Name:** `magana-server`. **Permission:** **Sending access**. **Domain:** `magana.ng`.
3. Choose **Add**, then paste the key (`re_…`) into `~/.magana/server.env` as `RESEND_API_KEY`.

**c. Bounces and complaints:**
1. Go to **Webhooks → Add Webhook**.
2. **Endpoint URL:** `https://api.magana.ng/internal/mail-events`.
3. **Events:** `email.bounced`, `email.complained`, `email.delivery_delayed`, `email.delivered`.
4. Choose **Add**. Open the webhook, then copy its **Signing Secret** (`whsec_…`) into `~/.magana/server.env` as `RESEND_WEBHOOK_SECRET`.

## 7. Send the settings

`~/.magana/server.env` already exists, with `MAGANA_CODE_KEY` and `MAGANA_WEB_API_KEY` made on this Mac. After steps 4 and 6 it also has `DATABASE_URL`, `RESEND_API_KEY` and `RESEND_WEBHOOK_SECRET`.

```bash
scripts/server-env.sh --check    # which are filled in (names only)
scripts/server-env.sh --push     # to the server (it restarts the API with them), plus an encrypted copy in magana-backups
scripts/server-env.sh --github   # GitHub secrets: MAGANA_WEB_API_KEY, RESEND_API_KEY, DATABASE_URL
```

- **Keep a copy of the file itself in your password manager too.** Its `MAGANA_CODE_KEY` opens class codes, authenticator keys and proofs.
- `--github` sets a new web key. The next push rebuilds the PWA and the portal with it, and the server already takes it.
- **Without a Mac:**
  1. SSH to the server.
  2. Run `sudo nano /etc/magana/magana.env` and add the lines there.
  3. Run `sudo magana-deploy --restart`.
  4. Set the three GitHub secrets under **GitHub → magana → Settings → Secrets and variables → Actions**.

## 8. Deploy

Push to main, or re-run the latest CI run. The `deploy` job:
1. tags the commit `production`;
2. waits while the server builds it, checks it and switches over (a few minutes; longer the first time).

Then check:
- `https://api.magana.ng/health` shows `"status": "ok"`, `"database": "ok"` and the commit.
- The app reads a page, and the portal opens.

## 9. The first Magana admin

```bash
scripts/team-setup.sh --email daniel@magana.ng --name "Jemiri Daniel Taiwo"
```

This runs on the server, in the live API container, against Neon. **Do it after step 7**, so the admin is made in Neon, not in the temporary SQLite file.
1. Sign in at **teachers.magana.ng**. The first sign-in sets up the authenticator and shows the backup codes once.
2. Send yourself a sign-in code: **Resend → Emails** shows it delivered.

## 10. Check the backup and the monitor

1. **GitHub → Actions → Backup → Run workflow.** A minute later, magana-backups has `daily/magana-<today>.dump.age`.
2. **GitHub → Actions → Monitor → Run workflow.** It should pass. From now on it runs every 10 minutes and emails daniel@magana.ng if the API is down for 30 minutes.
   - To send alerts elsewhere: `gh variable set ALERT_EMAIL --body you@example.com`.
3. Remove the old GitHub settings that are no longer used:
   ```bash
   gh secret delete HF_DEPLOY_TOKEN; gh variable delete HF_SPACE
   gh variable delete AWS_DEPLOY_ROLE_ARN; gh variable delete MAGANA_INSTANCE_ID; gh variable delete PORTAL_ON_PAGES
   ```
   Some of these may not exist; that's fine.

## Later

- **When the AWS account is back:** terminate the EC2 instance, release its Elastic IP, and delete the SES identities, the SNS topic and the IAM roles. That stops any charge.
- **WhatsApp:** Meta's webhook URL is still `https://api.magana.ng/whatsapp/webhook`. Add its settings to `~/.magana/server.env` and push them (docs/WHATSAPP_SETUP.md).
- **Explain (N-ATLaS):** set `EXPLAIN_ENGINE`, `EXPLAIN_URL` and `EXPLAIN_API_KEY` in `~/.magana/server.env`, then run `scripts/server-env.sh --push`.
- **Rotating the app key:**
  1. Add `MAGANA_API_KEY_PREVIOUS` and `MAGANA_API_KEY_PREVIOUS_UNTIL` (at most 14 days ahead).
  2. Set the new `MAGANA_API_KEY`, push the settings, then build new apps.
  3. The web key works the same way with `MAGANA_WEB_API_KEY_PREVIOUS…`. Also run `--github` (`main.accepted_keys`).
