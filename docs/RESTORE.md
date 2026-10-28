# Backups and restoring (test phase)

What runs where is in docs/INFRA.md.

## What holds data

- **Neon:** the database holds everything Magana keeps:
  - schools, staff, classes, and learners as schools record them;
  - consent, attendance and the audit log;
  - team accounts, quizzes and encrypted proof-of-school files;
  - WhatsApp profiles and call-backs, and problem reports.
- **The settings:** `/etc/magana/magana.env` on the server. Copies are in `~/.magana/server.env` and, encrypted, in `settings/server.env.age` in jemiridaniel/magana-backups. They include `MAGANA_CODE_KEY`, which opens the sealed parts: class codes for teachers, authenticator keys and proofs. **A database backup is no use without that key.**
- **The backup key:** `~/.magana/backup-age-key.txt` and your password manager. It opens the dumps and the settings copy. **Without it, no backup can be opened.**
- **Nothing else.** The server is disposable: the code, the Caddyfile and the deploy script all come from GitHub.

## Backups

1. **Daily, off the server and off Oracle:**
   - `.github/workflows/backup.yml` runs at 02:40 UTC and writes `daily/magana-YYYY-MM-DD.dump.age` to the private repository jemiridaniel/magana-backups.
   - It keeps 30 daily dumps, and `monthly/` for 12 months.
   - The dumps are encrypted before they leave GitHub's job. A failure is emailed.
   - **Run one by hand before any risky change:** **GitHub → Actions → Backup → Run workflow**.
2. **Neon's own history:** **Neon → the project → Backup & Restore**. The free plan keeps a short window, a few hours (the console shows it). Use it to undo a mistake made today.

## Restoring

**The whole database from a dump.** On any computer with Docker, `age` and the backup key:
```bash
gh repo clone jemiridaniel/magana-backups && cd magana-backups
age -d -i ~/.magana/backup-age-key.txt -o magana.dump daily/magana-<date>.dump.age
docker run --rm -i -e DATABASE_URL="<the Neon connection string>" postgres:18 \
  sh -c 'pg_restore --clean --if-exists --no-owner --no-privileges --dbname="$DATABASE_URL"' < magana.dump
rm magana.dump
```
- **Into a new Neon project:**
  1. Put its pooled connection string in `~/.magana/server.env` as `DATABASE_URL`.
  2. Run `scripts/server-env.sh --push` and `scripts/server-env.sh --github`.
- **The key:** the settings must have the same `MAGANA_CODE_KEY` as when the dump was made.
- On the server itself, the same commands work. `age` is `sudo apt install age`. Delete the key and the decrypted dump afterwards.

**The settings, if `~/.magana/server.env` is lost:**
```bash
age -d -i ~/.magana/backup-age-key.txt -o ~/.magana/server.env magana-backups/settings/server.env.age && chmod 600 ~/.magana/server.env
```

**A day's mistake:** in **Neon → Backup & Restore**, choose a time inside the window and restore it. This needs no dump.

**The server, stopped:** **Oracle → Compute → Instances → magana-api → Start**. Docker, Caddy and the API start by themselves.

**The server, lost (terminated, or a new account):**
1. Create a new instance with these settings, then note its public address:
   - **Ubuntu 24.04**, **VM.Standard.A1.Flex**, 2 OCPU, 12 GB, in UK South (London);
   - your SSH key;
   - a network security group allowing TCP 80 and 443.
2. Set up the server:
   ```bash
   MAGANA_SERVER=<address> scripts/server-setup.sh
   MAGANA_SERVER=<address> scripts/server-env.sh --push
   ```
3. Point the `api` A record at the new address (docs/DEPLOY.md, step 1).
4. Within a minute the server builds the `production` commit. To start it at once, re-run the latest CI run.

Nothing else needs restoring: the data is in Neon.

**Locked out of SSH** (Tailscale down or signed out, with port 22 closed):
1. Open **Oracle → Compute → Instances → magana-api → Resources → Console connection → Launch Cloud Shell connection**.
2. Sign in as `ubuntu`. This needs a password; set one beforehand with `sudo passwd ubuntu`, which works only on the console, not over SSH.
3. Reconnect Tailscale with `sudo tailscale up`, or reopen public SSH:
   - `sudo rm /etc/magana/ssh-tailscale-only`, then `sudo iptables -I INPUT 4 -p tcp --dport 22 -j ACCEPT`;
   - also re-add the port 22 rule in Oracle's security list.
4. A lost server can always be replaced instead (above): nothing on it is the only copy.

**A bad deploy:** the server keeps the old version if the new one fails its checks (docs/INFRA.md). To put an earlier commit back by hand: **GitHub → Actions → Rollback → Run workflow**.

**An owner locked out of the portal:**
```bash
scripts/team-setup.sh --email you@example.com --reset-authenticator
```

**Email:** nothing to restore. Resend keeps no data of ours that we need, and the undeliverable list is in the database.

## Checking a restore worked

- `https://api.magana.ng/health` shows `"database": "ok"`.
- Sign in at teachers.magana.ng: the schools, classes and quizzes are there.
- A class code still opens its class in the app. That proves `MAGANA_CODE_KEY` matches.
