#!/usr/bin/env bash
set -uo pipefail

logs="${RUNNER_TEMP:-/tmp}/nexdoz-infra-ci"
mkdir -p "$logs"
infra_log="$logs/infrastructure.log"
security_log="$logs/security.log"

(
  set -euo pipefail
  docker compose -f docker-compose.prod.yml config >/dev/null
  docker run --rm -v "$PWD":/work -w /work caddy:2-alpine \
    caddy validate --config Caddyfile --adapter caddyfile --envfile .env
  for file in scripts/*.sh; do
    docker run --rm -v "$PWD":/mnt koalaman/shellcheck:v0.10.0 \
      --severity=warning --format=gcc "/mnt/$file"
    bash -n "$file"
  done
) >"$infra_log" 2>&1 &
infra_pid=$!

(
  set -uo pipefail
  failed=0
  trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 caddy:2-alpine || failed=1
  trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 postgres:16-alpine || failed=1
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
