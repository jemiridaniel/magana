# Backups and restoring (test phase)

What runs where is in docs/INFRA.md.

## What holds data

- **Neon:** the database holds everything Magana keeps. That's schools, staff, classes, learners as schools record them, consent, attendance, the audit log, team accounts, quizzes, encrypted proof-of-school files, WhatsApp profiles and call-backs, and problem reports.
- **This Mac:** `~/.magana/space.env` holds `MAGANA_CODE_KEY`, which opens the sealed parts (class codes for teachers, authenticator keys, proofs). **A database backup is no use without that key.** Keep a copy of the file in your password manager.
- **Nothing else.** The Space keeps nothing on its disk. The Worker, the Space's code and the websites are all rebuilt from GitHub.

## Backups

1. **Neon's own history:** **Neon → the project → Backup & Restore**. The free plan keeps only a short window of history, a few hours; check the console for the exact figure. Use it to undo a mistake made today.
2. **A copy on this Mac, weekly** (and before any risky change):
   ```bash
   brew install postgresql@16      # once: pg_dump 16 or newer
   scripts/db-backup.sh            # → ~/magana-backups/magana-<time>.dump; keeps the newest 12
   ```
   The dump holds schools' and teachers' data. Keep it on this Mac only, never in the repository, a chat or a shared drive. GitHub can't make these backups: the repository is public, so its Actions artifacts could be downloaded by anyone.

## Restoring

**The whole database from a dump** (into the same or a new Neon project):
```bash
source ~/.magana/space.env
/opt/homebrew/opt/postgresql@16/bin/pg_restore --clean --if-exists --no-owner --no-privileges \
  --dbname="$DATABASE_URL" ~/magana-backups/magana-<time>.dump
```
- **A new project:** put its pooled connection string in `~/.magana/space.env` as `DATABASE_URL`, then run `python3 scripts/space_secrets.py`. The Space restarts with it.
- **The key:** use the same `MAGANA_CODE_KEY` as when the dump was made.

**A day's mistake:** in **Neon → Backup & Restore**, choose a time inside the window and restore it. This needs no dump.

**The Space, lost or broken:**
1. Re-run the latest CI run on main (**GitHub → Actions → CI → Re-run all jobs**). It pushes the code and waits for health.
2. If the Space itself is gone, create it again (docs/DEPLOY.md, steps 1, 2b and 6), then re-run CI.
3. Then put the new read token into the Worker (step 7c).

**The Worker:** re-run CI. Its secret `HF_TOKEN` survives deploys. If it's lost, set it again (docs/DEPLOY.md, step 7c).

**An owner locked out of the portal:**
```bash
scripts/team-setup.sh --email you@example.com --reset-authenticator
```

**Email:** nothing to restore. Resend keeps no data of ours that we need. The undeliverable list is in the database.

## Checking a restore worked

- `https://api.magana.ng/health` shows `"database": "ok"`.
- Sign in at teachers.magana.ng: the schools, classes and quizzes are there.
- A class code still opens its class in the app. That proves `MAGANA_CODE_KEY` matches.
