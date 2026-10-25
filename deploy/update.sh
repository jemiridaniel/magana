#!/usr/bin/env bash
# Finish an update on the server, after the new commit has been merged into ~/srv/magana
# (.github/workflows/ci.yml runs this through AWS Systems Manager, so GitHub needs no SSH;
# docs/DEPLOY_AWS.md §8a):
#   deploy/update.sh <previous commit> [<web bundle URL> <its sha256>]
#
# 1. Pull Ibà and rebuild the containers.
# 2. Wait for https://<domain>/health. If it doesn't answer in time, go back to <previous
#    commit> (and Ibà's previous commit), rebuild, and fail.
# 3. Only then, install the PWA (app.), teacher portal (teachers.) and website from the web bundle:
#    built by CI with placeholders instead of keys, which are filled in here from .env.
#    The keys are never printed.
set -euo pipefail

# Everything runs from inside main(), which bash reads in full before running: the rollback
# rewrites this file.
main() {
  local prev="$1" url="${2:-}" sum="${3:-}"
  cd "$HOME/srv/magana"
  local compose="sudo docker compose -f docker-compose.prod.yml"
  local domain
  domain="api.$(env_value MAGANA_DOMAIN)"
  local iba_prev
  iba_prev="$(git -C ../iba-natlas rev-parse HEAD)"

  echo "magana: $(git log --oneline -1)"
  ensure_secrets
  git -C ../iba-natlas pull -q --ff-only
  echo "iba:    $(git -C ../iba-natlas log --oneline -1)"
  $compose up -d --build --quiet-pull 2>&1 | tail -5
  # Caddy mounts the Caddyfile as a single file: a pull replaces the file, so Caddy keeps the
  # old one until it restarts.
  if ! git diff --quiet "$prev" HEAD -- deploy/Caddyfile; then
    $compose restart caddy >/dev/null && echo "caddy restarted (Caddyfile changed)"
  fi

  if ! healthy "$domain"; then
    echo "health check failed: going back to ${prev:0:7}"
    $compose logs --tail 30 magana 2>&1 || true
    git reset -q --hard "$prev"
    git -C ../iba-natlas reset -q --hard "$iba_prev"
    $compose up -d --build --quiet-pull 2>&1 | tail -5
    $compose restart caddy >/dev/null
    healthy "$domain" && echo "rolled back, healthy" || echo "rolled back, STILL NOT HEALTHY"
    exit 1
  fi
  sudo docker image prune -f >/dev/null
  echo "healthy"

  if [ -n "$url" ]; then
    install_web "$url" "$sum"
  fi
  $compose ps --format '{{.Service}} {{.Status}}'
}

env_value() { grep -m1 "^$1=" .env | cut -d= -f2-; }

healthy() {
  for _ in $(seq 1 30); do
    curl -fsS --max-time 5 "https://$1/health" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

# Server-only secrets the code needs, made here on first deploy so they never pass through
# GitHub, chat or SSH: MAGANA_CODE_KEY keys the class, session and teacher codes (codes.py).
ensure_secrets() {
  if ! grep -q '^MAGANA_CODE_KEY=.' .env; then
    sed -i '/^MAGANA_CODE_KEY=/d' .env
    echo "MAGANA_CODE_KEY=$(openssl rand -hex 32)" >> .env
    echo "made MAGANA_CODE_KEY"
  fi
}

install_web() {
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL --max-time 120 -o "$tmp/web.tar.gz" "$1"
  echo "$2  $tmp/web.tar.gz" | sha256sum -c --quiet -
  tar -xzf "$tmp/web.tar.gz" -C "$tmp"
  # Fill in the keys (read from .env, never echoed).
  MAGANA_API_KEY="$(env_value MAGANA_API_KEY)" \
    python3 - "$tmp/web" "$tmp/teachers" "$tmp/site" <<'PY'
import os, pathlib, sys
keys = {"__MAGANA_API_KEY__": os.environ["MAGANA_API_KEY"]}
assert all(keys.values()), "a key is missing from .env"
for root in [r for r in sys.argv[1:] if os.path.isdir(r)]:
    for p in pathlib.Path(root).rglob("*"):
        if p.suffix in (".js", ".html", ".txt", ".json") and p.is_file():
            s = p.read_text(encoding="utf-8", errors="surrogateescape")
            if "__MAGANA_" in s:
                for k, v in keys.items():
                    s = s.replace(k, v)
                assert "__MAGANA_" not in s, f"unfilled placeholder in {p.name}"
                p.write_text(s, encoding="utf-8", errors="surrogateescape")
PY
  # Copy into the directories Caddy has mounted (replacing them would break the mounts).
  mkdir -p deploy/web deploy/teachers deploy/site deploy/downloads
  # Docker creates a missing mount folder as root; keep them ours.
  sudo chown ubuntu:ubuntu deploy/web deploy/teachers deploy/site deploy/downloads
  rsync -a --delete "$tmp/web/" deploy/web/
  rsync -a --delete "$tmp/teachers/" deploy/teachers/
  if [ -d "$tmp/site" ]; then rsync -a --delete "$tmp/site/" deploy/site/; fi
  rm -rf "$tmp"
  echo "PWA, teacher portal and website installed"
}

main "$@"
