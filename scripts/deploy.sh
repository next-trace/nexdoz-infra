#!/usr/bin/env bash
# Nexdoz deploy script — runs on the droplet (via SSH from CI or a laptop).
#
# Usage (local, from a laptop that already has SSH access to the droplet):
#   ssh deploy@DROPLET_HOST 'bash -s' < scripts/deploy.sh
#
# Usage (in CI): the deploy-prod.yml workflow wires this up.

set -euo pipefail

REPO_DIR=${NEXDOZ_INFRA_DIR:-/opt/nexdoz}
COMPOSE_FILE="$REPO_DIR/docker-compose.prod.yml"

cd "$REPO_DIR"

echo "==> git pull"
git pull --ff-only origin main

echo "==> docker compose pull"
docker compose -f "$COMPOSE_FILE" pull

echo "==> docker compose up -d"
docker compose -f "$COMPOSE_FILE" up -d

echo "==> waiting for user-api /healthz"
for attempt in $(seq 1 30); do
  if docker compose -f "$COMPOSE_FILE" exec -T user-api wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
    echo "user-api healthy after ${attempt} attempts"
    break
  fi
  if [ "$attempt" -eq 30 ]; then
    echo "ERROR: user-api failed healthcheck after 5 minutes" >&2
    docker compose -f "$COMPOSE_FILE" logs --tail=200 user-api
    exit 1
  fi
  sleep 10
done

echo "==> image versions running"
docker compose -f "$COMPOSE_FILE" images

echo "==> prune dangling images"
docker image prune -f >/dev/null || true

echo "Deploy complete."
