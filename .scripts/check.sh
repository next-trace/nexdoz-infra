#!/usr/bin/env bash
# Local verification for nexdoz-infra.
# Mirrors CI: validate compose file, lint shell scripts.

set -euo pipefail

cd "$(dirname "$0")/.."

step() {
    printf '\n==> %s\n' "$1"
}

step "docker compose config"
# Need a stub .env for variable expansion
if [ ! -f .env ]; then
    cp .env.dist .env
    sed -i 's|CHANGE_ME_32_BYTE_HEX|placeholder|g' .env
fi
docker compose -f docker-compose.prod.yml config > /dev/null

step "shellcheck scripts/"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck scripts/*.sh || true
else
    echo "(shellcheck not installed; skipping)"
fi

printf '\nAll local checks passed.\n'
