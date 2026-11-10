#!/usr/bin/env bash
set -uo pipefail

logs="${RUNNER_TEMP:-/tmp}/nexdoz-infra-ci"
mkdir -p "$logs"
export TMPDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
mkdir -p "$TMPDIR"
infra_log="$logs/infrastructure.log"
security_log="$logs/security.log"
export COMPOSE_PROJECT_NAME=nexdoz-infra-ci
caddy_image="${NEXDOZ_CADDY_CI_IMAGE:-nexdoz-caddy:2.11.9-hardened}"
postgres_image="${NEXDOZ_POSTGRES_CI_IMAGE:-nexdoz-postgres:16.15-alpine3.24-hardened}"

(
  set -euo pipefail
  docker compose -f docker-compose.prod.yml config >/dev/null
  docker run --rm -v "$PWD":/work -w /work "$caddy_image" \
    caddy validate --config Caddyfile --adapter caddyfile --envfile .env
  container="nexdoz-infra-ci-postgres-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-$$"
  cleanup() { docker rm --force --volumes "$container" >/dev/null 2>&1 || true; }
  trap cleanup EXIT
  docker run --detach --name "$container" \
    --env POSTGRES_USER=nexdoz_ci --env POSTGRES_PASSWORD=ci-only-password \
    --env POSTGRES_DB=nexdoz_ci "$postgres_image" >/dev/null
  for attempt in {1..30}; do
    if docker exec "$container" pg_isready --host=127.0.0.1 --username=nexdoz_ci --dbname=nexdoz_ci >/dev/null 2>&1 \
      && docker exec --env PGPASSWORD=ci-only-password "$container" \
        psql --host=127.0.0.1 --username=nexdoz_ci --dbname=nexdoz_ci --tuples-only --no-align \
        --command='SELECT 1' | grep -qx 1; then
      break
    fi
    if [[ "$attempt" == 30 ]]; then
      docker logs "$container"
      echo '::error::Hardened PostgreSQL image did not become ready'
      exit 1
    fi
    sleep 1
  done
  for file in scripts/*.sh; do
    shellcheck --severity=warning --format=gcc "$file"
    bash -n "$file"
  done
) >"$infra_log" 2>&1 &
infra_pid=$!

(
  set -uo pipefail
  failed=0
  for image in "$caddy_image" "$postgres_image"; do
    trivy image --scanners vuln --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 1 "$image" || failed=1
  done
  gitleaks detect --source . --redact --no-banner || failed=1
  exit "$failed"
) >"$security_log" 2>&1 &
security_pid=$!

infra_result=passed
security_result=passed
if ! wait "$infra_pid"; then
  infra_result=failed
  echo '::error::Infrastructure validation failed'
  sed -n '1,240p' "$infra_log"
fi
if ! wait "$security_pid"; then
  security_result=failed
  echo '::error::Security validation failed; review vulnerability and secret scan findings'
  sed -n '1,240p' "$security_log"
fi

{
  echo '### Infrastructure and security checks'
  echo
  echo '| task | result |'
  echo '| --- | --- |'
  echo "| Compose, Caddy and shell validation | $infra_result |"
  echo "| Image vulnerabilities and secrets | $security_result |"
} >> "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY must be set}"

[[ "$infra_result" == passed && "$security_result" == passed ]]
