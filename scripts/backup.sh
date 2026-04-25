#!/usr/bin/env bash
# Nightly Postgres backup to DO Spaces.
#
# Assumes:
#   - nexdoz-infra is cloned at /opt/nexdoz
#   - .env contains POSTGRES_* variables
#   - s3cmd is installed + configured with DO Spaces credentials (~/.s3cfg)
#   - GPG is installed + a recipient key is imported
#
# Schedule via cron (as deploy user):
#   0 3 * * * /opt/nexdoz/scripts/backup.sh >> /var/log/nexdoz-backup.log 2>&1

set -euo pipefail

REPO_DIR=${NEXDOZ_INFRA_DIR:-/opt/nexdoz}
cd "$REPO_DIR"

# shellcheck disable=SC1091
set -a; . ./.env; set +a

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUTFILE="/tmp/nexdoz-backup-${STAMP}.sql.gz.gpg"
BUCKET=${BACKUP_BUCKET:-nexdoz-backups-eu}
GPG_RECIPIENT=${BACKUP_GPG_RECIPIENT:?BACKUP_GPG_RECIPIENT must be set}

echo "==> dumping postgres"
docker compose -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges \
  | gzip -9 \
  | gpg --encrypt --recipient "$GPG_RECIPIENT" --output "$OUTFILE"

echo "==> uploading to DO Spaces: s3://${BUCKET}/$(basename "$OUTFILE")"
s3cmd put "$OUTFILE" "s3://${BUCKET}/$(basename "$OUTFILE")" --acl-private

echo "==> retention: prune backups older than 30 days"
CUTOFF=$(date -u -d '30 days ago' +%Y%m%d)
s3cmd ls "s3://${BUCKET}/" | awk '{print $4}' | while read -r key; do
  name=$(basename "$key")
  dstamp=$(echo "$name" | sed -n 's/^nexdoz-backup-\([0-9]\{8\}\)T.*$/\1/p')
  if [ -n "$dstamp" ] && [ "$dstamp" -lt "$CUTOFF" ]; then
    echo "  rm $key"
    s3cmd rm "$key"
  fi
done

rm -f "$OUTFILE"
echo "Backup complete."
