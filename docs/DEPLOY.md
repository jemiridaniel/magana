# Setting up the free test-phase hosting (Hugging Face, Neon, Cloudflare Worker, Resend)

What runs where, and why, is in docs/INFRA.md. These are the one-time steps, in order. Everything here is free; nothing asks for a card. About an hour in all.

**Before you start:**
- **There is no backup to restore.** The only database was on the AWS server, and the only backup command ran on that server. The test phase starts with a clean database, and step 8 makes the first Magana admin. Schools, teachers and quizzes from AWS have to be added again.
- **Keep every value you copy out of chat and out of the repository.** Values go only into `~/.magana/space.env` on this Mac, or into a dashboard.

## 1. The Hugging Face Space (private)

1. Sign in at **huggingface.co** (or **Sign up**).
2. Open **huggingface.co/new-space**.
3. **Owner:** your account. **Space name:** `magana-api`. **Short description:** "Magana API (test phase)".
4. **License:** leave empty, or choose *other*.
5. **Select the Space SDK:** **Docker**, then the **Blank** template.
6. **Space hardware:** **CPU basic · 2 vCPU · 16 GB · FREE**.
7. **Visibility:** **Private**.
8. Choose **Create Space**. It stays empty until the first deploy pushes the code (step 9).
9. Note its name as `<your username>/magana-api`. That's `HF_SPACE`.

## 2. Two Hugging Face access tokens (fine-grained, this Space only)

Open **huggingface.co/settings/tokens → Create new token → Fine-grained**.

**a. For the Worker (read only):**
1. **Token name:** `magana-worker-read`.
2. Leave every **User permissions** box empty.
3. Under **Repositories permissions**, search for and select `<your username>/magana-api`. Tick only **Read access to contents of selected repos**.
4. Choose **Create token** and **copy it once**. It goes into Cloudflare in step 7c. Keep it in your password manager meanwhile, not in a file in the repository.

**b. For GitHub's deploys (write):**
1. **Token name:** `magana-deploy`.
2. Select the same Space under **Repositories permissions**. Tick **Write access to contents/settings of selected repos** (it includes read).
3. Choose **Create token**, copy it, and paste it into `~/.magana/space.env` as `HF_DEPLOY_TOKEN` (step 5).

## 3. The database: Neon (London)

**Why Neon over Supabase:**
- Neon has a London region and an IPv4 address. A free Supabase project's direct address is IPv6 only, which the Space may not reach.
- A free Supabase project is paused after a week without use. A Neon database only sleeps its compute and wakes on the next query.

1. Sign up at **neon.tech** (GitHub sign-in is fine).
2. **Create project:**
   - **Project name:** `magana`.
   - **Postgres version:** the default (17).
   - **Cloud provider:** **AWS**. **Region:** **AWS Europe (London) eu-west-2**.
   - Then **Create project**.
3. On the project's dashboard, choose **Connect**.
   - **Branch:** `production`. **Database:** `neondb`. **Role:** `neondb_owner`.
   - Turn **Connection pooling** **on**.
   - Copy the connection string. It looks like `postgresql://neondb_owner:…@ep-…-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require`.
   - Paste it into `~/.magana/space.env` as `DATABASE_URL` (step 5).
4. **Settings → Compute:** leave **Scale to zero** on (the free plan's default).

The tables are created by the server itself on first use, and by step 8 if that comes first. There is no migration to run.

## 4. Email: Resend for no-reply@magana.ng

**a. The domain:**
1. Sign up at **resend.com**.
2. Go to **Domains → Add Domain**. **Name:** `magana.ng`. **Region:** **Ireland (eu-west-1)**. Choose **Add**.
3. Resend shows three records. In **dash.cloudflare.com → magana.ng → DNS → Records**, add each with **Add record**. Every one is **DNS only** (grey cloud), TTL Auto.

   | Type | Name | Content | Priority |
   |---|---|---|---|
   | TXT | `resend._domainkey` | the long `p=…` value Resend shows (copy it exactly) | |
   | MX | `send` | `feedback-smtp.eu-west-1.amazonses.com` | 10 |
   | TXT | `send` | `v=spf1 include:amazonses.com ~all` | |

   These sit on the `send` subdomain and the DKIM name, so they don't touch magana.ng's own MX records: **Cloudflare Email Routing keeps working**.
4. **Edit the root SPF record** (TXT, name `magana.ng`). SES no longer sends for magana.ng. Resend's SPF lives on `send` (above), and DKIM aligns its mail with magana.ng.
   - **Today:** `v=spf1 include:_spf.mx.cloudflare.net include:amazonses.com include:_spf.google.com ~all`
   - **Change it to:** `v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all`
5. **Fix DMARC: there are two DMARC records now, which counts as none.** Receivers treat two `_dmarc` TXT records as an error.
   - Delete both `_dmarc` TXT records.
   - Add one: TXT, name `_dmarc`, content `v=DMARC1; p=none; rua=mailto:support@magana.ng` (the support address, `config/public.json`). The second record's Gmail report address is dropped.
6. Back in Resend, choose **Verify DNS Records**. It turns **Verified** within minutes, sometimes up to an hour.

**b. The sending key:**
1. Go to **API Keys → Create API Key**.
2. **Name:** `magana-space`. **Permission:** **Sending access**. **Domain:** `magana.ng`.
3. Choose **Add**, copy the key (`re_…`), and paste it into `~/.magana/space.env` as `RESEND_API_KEY`.

**c. Bounces and complaints (the webhook):**
1. Go to **Webhooks → Add Webhook**.
2. **Endpoint URL:** `https://api.magana.ng/internal/mail-events`.
3. **Events:** `email.bounced`, `email.complained`, `email.delivery_delayed`, `email.delivered`.
4. Choose **Add**. Open the webhook and copy its **Signing Secret** (`whsec_…`) into `~/.magana/space.env` as `RESEND_WEBHOOK_SECRET`.

## 5. `~/.magana/space.env` on this Mac

```bash
cd ~/Desktop/Personal\ Project/magana
scripts/space-env-init.sh
```

This creates `~/.magana/space.env` (only you can read it). It already holds a new `MAGANA_CODE_KEY` and a new `MAGANA_WEB_API_KEY`.
1. Open it in TextEdit and fill in `HF_SPACE`, `HF_DEPLOY_TOKEN`, `DATABASE_URL`, `RESEND_API_KEY` and `RESEND_WEBHOOK_SECRET`.
2. Fill in the WhatsApp and Explain lines only if you use them.
3. **Keep this file:** without `MAGANA_CODE_KEY`, class codes, authenticator keys and proofs can't be opened again.
4. The app key `MAGANA_API_KEY` is read from `~/.magana/app.env` (unchanged). Installed APKs and IPAs keep working.

## 6. The Space's secrets, and GitHub's

```bash
python3 scripts/space_secrets.py --check   # which are filled in (names only, never values)
python3 scripts/space_secrets.py           # sets the Space's secrets and variables
scripts/space-env-init.sh --github         # GitHub secrets: MAGANA_WEB_API_KEY, RESEND_API_KEY, HF_DEPLOY_TOKEN; variable HF_SPACE
```

Check them in the Space: **Settings → Variables and secrets**. Secrets show only their names.

Then, in a terminal, remove the AWS variables from GitHub. They're unused now:
```bash
gh variable delete AWS_DEPLOY_ROLE_ARN; gh variable delete MAGANA_INSTANCE_ID; gh variable delete PORTAL_ON_PAGES
```

## 7. The Cloudflare Worker on api.magana.ng

**a. Let GitHub deploy Workers.**
1. Open **dash.cloudflare.com → My Profile → API Tokens**, then **magana-github-pages → Edit**.
2. Keep **Account → Cloudflare Pages → Edit**, and add:
   - **Account → Workers Scripts → Edit**
   - **Zone → Workers Routes → Edit**
   - **Zone → DNS → Edit**
   - **Zone → Zone → Read**
3. Under **Zone Resources**, choose **Include → Specific zone → magana.ng**.
4. Choose **Continue to summary → Update token**. The token's value doesn't change, so the GitHub secret `CLOUDFLARE_API_TOKEN` stays as it is.

**b. Free the name api.magana.ng.** In **magana.ng → DNS → Records**, delete the **A** record `api` → `35.178.64.255` (and any AAAA record for `api`). The Worker's custom domain creates its own record on its first deploy. Until then api.magana.ng doesn't answer, as now.

**c. After the first deploy (step 9) has created the Worker:**
1. Go to **Workers & Pages → magana-api → Settings → Variables and Secrets → Add**.
2. **Type:** **Secret**. **Variable name:** `HF_TOKEN`. **Value:** the read-only token from step 2a.
3. Choose **Deploy**.

Do this while CI is waiting for the server: until it's set, the Worker answers `server_unavailable`.

**d.** If your Space isn't `<username>/magana-api`, nothing more is needed: CI sets the Worker's `UPSTREAM` from `HF_SPACE`.

## 8. The first Magana admin

```bash
scripts/team-setup.sh --email daniel@magana.ng --name "Jemiri Daniel Taiwo"
```

This runs on this Mac, against Neon, with the same `MAGANA_CODE_KEY` as the Space, and creates the tables if they aren't there yet. Then sign in at **teachers.magana.ng**: the first sign-in sets up the authenticator and shows the backup codes once.

## 9. Deploy

Push to main (or re-run the latest CI run). The `space` job:
1. pushes the code to the Space;
2. deploys the Worker;
3. waits for `https://api.magana.ng/health` to answer with this commit and `"database": "ok"`.

Watch the Space build under **Space → Logs → Build**. Do step 7c meanwhile. Then check:
- `https://api.magana.ng/health` shows `"status": "ok"` and `"database": "ok"`.
- The app reads a page, and the portal signs in.
- Send yourself a sign-in code. Resend → **Emails** shows it delivered.

## 10. Keep-awake

Nothing to click. `.github/workflows/keep-awake.yml` runs every 6 hours and emails daniel@magana.ng if two checks in a row fail. To send the alert somewhere else: `gh variable set ALERT_EMAIL --body you@example.com`. Run it once by hand to see it work: **GitHub → Actions → Keep awake → Run workflow**.

## Later

- **WhatsApp:** Meta's webhook URL is still `https://api.magana.ng/whatsapp/webhook`. Nothing to change, once its secrets are in the Space.
- **When the AWS account is back:** terminate the EC2 instance, release its Elastic IP, and delete the SES identities, the SNS topic and the IAM roles. That stops any charge.
- **Explain (N-ATLaS):** set `EXPLAIN_ENGINE`, `EXPLAIN_URL` and `EXPLAIN_API_KEY` in `~/.magana/space.env` and run `python3 scripts/space_secrets.py` again. The Space restarts with them.
- **Rotating the app key:** add `MAGANA_API_KEY_PREVIOUS` and `MAGANA_API_KEY_PREVIOUS_UNTIL` (at most 14 days ahead) as Space secrets, set the new `MAGANA_API_KEY`, then build new apps. The web key works the same way with `MAGANA_WEB_API_KEY_PREVIOUS…`; also update the GitHub secret (`main.accepted_keys`).
