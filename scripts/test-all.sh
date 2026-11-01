#!/usr/bin/env bash
# Run the same checks as .github/workflows/ci.yml locally, before pushing.
#   scripts/test-all.sh                 # everything ci.yml runs on every push/PR
#   scripts/test-all.sh --full          # + the OCR-heavy subset ci.yml excludes (ocr.yml's job)
#   scripts/test-all.sh --only backend  # just one section (see SECTIONS below)
#   scripts/test-all.sh --only backend --full   # that section, OCR tests included
#
# Each section is independent: one failing doesn't stop the rest, so you get the whole picture
# in one run, same as seeing every CI job's result on a PR. Exit code is non-zero if any failed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# Tool locations that aren't always on PATH by default on this machine.
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$HOME/development/flutter/bin:$PATH"

SECTIONS=(secrets backend app portal website)
ONLY=""
FULL=0
for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    --only) NEED_VALUE=1 ;;
    *)
      if [ "${NEED_VALUE:-0}" = 1 ]; then ONLY="$arg"; NEED_VALUE=0; else
        echo "Unknown argument: $arg (expected --full or --only <section>)" >&2; exit 2
      fi
      ;;
  esac
done
if [ -n "$ONLY" ] && [[ ! " ${SECTIONS[*]} " == *" $ONLY "* ]]; then
  echo "Unknown section '$ONLY'. Choices: ${SECTIONS[*]}" >&2
  exit 2
fi

# No associative arrays (declare -A needs bash 4+; macOS ships bash 3.2 at /usr/bin/bash) --
# one plain variable per section instead, set with printf -v and read back with ${!name}.
should_run() {
  [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]
}
run_section() {
  should_run "$1" || return 1
  echo
  echo "== $1 =="
}

ok()   { printf -v "RESULT_$1" '%s' "PASS"; }
fail() { printf -v "RESULT_$1" '%s' "FAIL"; }
skip() { printf -v "RESULT_$1" '%s' "SKIP ($2)"; }

# --- secrets: gitleaks over the full history, same rules as CI and the pre-commit hook -------
section_secrets() {
  run_section secrets || return
  if ! command -v gitleaks >/dev/null 2>&1; then
    skip secrets "gitleaks not installed -- brew install gitleaks"; return
  fi
  if gitleaks git --redact --verbose --no-banner --log-opts=--all --config .gitleaks.toml .; then
    ok secrets
  else
    fail secrets
  fi
}

# --- backend: same Docker image as CI, sqlite always, postgres if Docker can run it -----------
section_backend() {
  run_section backend || return
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    skip backend "Docker not available -- open Docker Desktop"; return
  fi
  echo "Building backend image (cached layers reused after the first run)..."
  if ! docker build -q -t magana-backend backend >/dev/null; then
    fail backend; return
  fi
  # An array, not a plain string: "-m" and "not ocr" must stay two separate argv words, or
  # pytest reads "-m not" (an empty/invalid expression) and "ocr" as a bogus path filter --
  # silently matching zero tests instead of failing loudly.
  marker_args=(-m "not ocr")
  [ "$FULL" = 1 ] && marker_args=()
  if [ "$FULL" = 1 ]; then echo "Backend tests on sqlite (full suite, OCR tests included)..."
  else echo "Backend tests on sqlite..."; fi
  if ! docker run --rm --user root --network host -v "$PWD:/m" -w /m/backend \
       -e OMP_THREAD_LIMIT=1 \
       magana-backend python -m pytest -q -p no:cacheprovider -n auto --durations=15 "${marker_args[@]}"; then
    fail backend; return
  fi
  echo "Backend tests on postgres..."
  docker rm -f magana-test-pg >/dev/null 2>&1 || true
  if ! docker run -d --name magana-test-pg -e POSTGRES_PASSWORD=magana -p 55432:5432 postgres:16 >/dev/null; then
    echo "  could not start a throwaway Postgres container; sqlite result stands alone."
    ok backend; return
  fi
  for _ in $(seq 1 30); do
    docker exec magana-test-pg pg_isready -U postgres >/dev/null 2>&1 && break
    sleep 1
  done
  local pg_ok=1
  if ! docker run --rm --user root --network host -v "$PWD:/m" -w /m/backend \
       -e MAGANA_TEST_DATABASE_URL="postgresql://postgres:magana@127.0.0.1:55432/postgres" \
       -e OMP_THREAD_LIMIT=1 \
       magana-backend python -m pytest -q -p no:cacheprovider -n auto --durations=15 "${marker_args[@]}"; then
    pg_ok=0
  fi
  docker rm -f magana-test-pg >/dev/null 2>&1 || true
  [ "$pg_ok" = 1 ] && ok backend || fail backend
}

# --- app: Flutter analyze + test ---------------------------------------------------------------
section_app() {
  run_section app || return
  if ! command -v flutter >/dev/null 2>&1; then
    skip app "flutter not on PATH -- expected at ~/development/flutter/bin/flutter"; return
  fi
  (cd app && flutter pub get && flutter analyze && flutter test) && ok app || fail app
}

# --- portal: lint only (same as CI) -------------------------------------------------------------
section_portal() {
  run_section portal || return
  if ! command -v npm >/dev/null 2>&1; then skip portal "npm not found"; return; fi
  (cd portal && npm ci && npm run lint) && ok portal || fail portal
}

# --- website: lint, build, then the real check CI does -- axe + layout e2e in Chromium ---------
section_website() {
  run_section website || return
  if ! command -v npm >/dev/null 2>&1; then skip website "npm not found"; return; fi
  (
    cd website
    npm ci
    npm run lint
    npx next build
    npx playwright install chromium >/dev/null
    npx playwright test --reporter=line
  ) && ok website || fail website
}

section_secrets
section_backend
section_app
section_portal
section_website

echo
echo "== summary =="
status=0
for s in "${SECTIONS[@]}"; do
  should_run "$s" || continue
  var="RESULT_$s"
  r="${!var:-did not run}"
  printf '%-10s %s\n' "$s" "$r"
  [[ "$r" == FAIL* ]] && status=1
done
[ "$status" = 0 ] && echo "All good." || echo "Something failed -- see above."
exit $status
