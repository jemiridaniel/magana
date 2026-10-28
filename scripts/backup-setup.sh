#!/usr/bin/env bash
# Connect the daily backup (.github/workflows/backup.yml) to the private repository that keeps the
# encrypted dumps (docs/DEPLOY.md). Run once, after creating that repository on GitHub:
#   scripts/backup-setup.sh            # jemiridaniel/magana-backups
# Makes a new SSH key that can write to that one repository only (a deploy key), gives its public
# half to the backups repository and its private half to this repository's Actions secret
# BACKUP_DEPLOY_KEY, then deletes it from this Mac. Prints no key.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="${MAGANA_BACKUP_REPO:-jemiridaniel/magana-backups}"
export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user jemiridaniel)}"
[ "$(gh repo view "$REPO" --json visibility --jq .visibility)" = PRIVATE ] \
  || { echo "$REPO must exist and be private"; exit 1; }
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
ssh-keygen -q -t ed25519 -N "" -C "magana backup workflow" -f "$tmp/key"
gh repo deploy-key add "$tmp/key.pub" --repo "$REPO" --allow-write --title "magana backup workflow" >/dev/null
gh secret set BACKUP_DEPLOY_KEY < "$tmp/key" >/dev/null
echo "Deploy key added to $REPO (write, that repository only); secret BACKUP_DEPLOY_KEY set."
echo "Run the first backup: GitHub → Actions → Backup → Run workflow (needs the DATABASE_URL secret)."
