#!/usr/bin/env bash
# Back up the test-phase database (Neon) to this Mac, outside the repository (docs/RESTORE.md).
#   scripts/db-backup.sh            → ~/magana-backups/magana-<UTC time>.dump (custom format)
# Reads DATABASE_URL from ~/.magana/space.env (never committed, never printed). Needs pg_dump 16
# or newer (brew install postgresql@16). The dump holds teachers' and schools' data: keep it on
# this Mac only, never in the repository, a chat or a shared drive.
set -euo pipefail
# shellcheck disable=SC1090
source "${MAGANA_SPACE_ENV:-$HOME/.magana/space.env}"
: "${DATABASE_URL:?set DATABASE_URL in ~/.magana/space.env}"
PG_DUMP="${PG_DUMP:-$(command -v pg_dump || echo /opt/homebrew/opt/postgresql@16/bin/pg_dump)}"
dir="${MAGANA_BACKUP_DIR:-$HOME/magana-backups}"
mkdir -p "$dir" && chmod 700 "$dir"
out="$dir/magana-$(date -u +%Y%m%dT%H%M%SZ).dump"
"$PG_DUMP" --format=custom --no-owner --no-privileges --dbname="$DATABASE_URL" --file="$out"
chmod 600 "$out"
echo "Backed up to $out ($(du -h "$out" | cut -f1))"
# Keep the newest 12.
ls -1t "$dir"/magana-*.dump 2>/dev/null | tail -n +13 | xargs -r rm -f
