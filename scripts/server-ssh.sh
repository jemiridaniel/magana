#!/usr/bin/env bash
# Who may reach the server's SSH (docs/INFRA.md, "SSH").
#   scripts/server-ssh.sh --tailscale-only   close port 22 to the internet (Tailscale only)
#   scripts/server-ssh.sh --public           open it again (fail2ban guards it)
# Run --tailscale-only only from a computer that is already reaching the server over Tailscale:
# it refuses otherwise, so it can't lock you out. Also remove the port 22 rule in Oracle's security
# list (docs/DEPLOY.md, step 3). Recovery if locked out: Oracle's console connection (docs/RESTORE.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${MAGANA_SERVER:-magana-api}"
KEY="${MAGANA_SSH_KEY:-$HOME/.ssh/magana_oracle.key}"
SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$HOST")
case "${1:-}" in
  --tailscale-only)
    peer=$("${SSH[@]}" 'echo "$SSH_CONNECTION"' | cut -d' ' -f1)
    case "$peer" in 100.*) ;; *) echo "this SSH session comes from $peer, not over Tailscale: refusing"; exit 1;; esac
    "${SSH[@]}" 'sudo touch /etc/magana/ssh-tailscale-only' ;;
  --public)
    "${SSH[@]}" 'sudo rm -f /etc/magana/ssh-tailscale-only' ;;
  *) echo "usage: scripts/server-ssh.sh --tailscale-only | --public"; exit 1 ;;
esac
MAGANA_SERVER="$HOST" "$ROOT/scripts/server-setup.sh" | grep -E "public SSH|== done|refusing"
