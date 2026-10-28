#!/usr/bin/env bash
# Set up (or bring up to date) the test-phase server over SSH (docs/DEPLOY.md): copies
# deploy/server/ to it and runs bootstrap.sh as root. Safe to run again.
#   scripts/server-setup.sh          # ubuntu@$MAGANA_SERVER with $MAGANA_SSH_KEY
# Prints no secrets: the settings file is written by scripts/server-env.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${MAGANA_SERVER:-magana-api}"  # the server's Tailscale name (docs/INFRA.md)
KEY="${MAGANA_SSH_KEY:-$HOME/.ssh/magana_oracle.key}"
SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$HOST")
COPYFILE_DISABLE=1 tar -C "$ROOT/deploy" -czf - server | "${SSH[@]}" 'rm -rf /tmp/magana-setup && mkdir -p /tmp/magana-setup && tar -C /tmp/magana-setup -xzf -'
"${SSH[@]}" 'sudo bash /tmp/magana-setup/server/bootstrap.sh; s=$?; rm -rf /tmp/magana-setup; exit $s'
