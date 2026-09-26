#!/bin/bash
set -euo pipefail

# Nginx Proxy Manager: proxy hosts, access lists, custom configs and certificates
# Usage: ./scripts/backup.sh [backup_directory]
# Default backup directory: ./backups
#
# The archive holds certificate private keys, so it is written with mode 600.
# data/logs is left out: it is most of the volume and NPM recreates it.
# Restore: docker compose down && sudo tar -xzf <archive> -C . && docker compose up -d

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${1:-$PROJECT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETAIN_COUNT=14
CONTAINER=nginx-proxy-manager
ARCHIVE="$BACKUP_DIR/npm_${TIMESTAMP}.tar.gz"
STAGING=$(mktemp -d)
chmod 700 "$STAGING"
trap 'rm -rf "$STAGING" "$ARCHIVE.partial"' EXIT

mkdir -p "$BACKUP_DIR" "$STAGING/data"
echo "=== nginx-proxy-manager backup $TIMESTAMP ==="

# data/ and letsencrypt/ belong to root; read them through the container
docker exec "$CONTAINER" tar -cf - -C /data --exclude=./logs --exclude=./database.sqlite . \
    | tar -xf - -C "$STAGING/data"
docker exec "$CONTAINER" tar -cf - -C /etc letsencrypt \
    | tar -xf - -C "$STAGING"

# NPM may write while we copy; the SQLite backup API gives a consistent file
python3 - "$PROJECT_DIR/data/database.sqlite" "$STAGING/data/database.sqlite" <<'PY'
import sqlite3
import sys

source = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
target = sqlite3.connect(sys.argv[2])
source.backup(target)
target.close()
source.close()
PY

(umask 077 && tar -czf "$ARCHIVE.partial" --owner=0 --group=0 -C "$STAGING" data letsencrypt)
mv "$ARCHIVE.partial" "$ARCHIVE"
echo "  Archive: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

echo "Cleaning up old backups (keeping last $RETAIN_COUNT)..."
ls -t "$BACKUP_DIR"/npm_*.tar.gz | tail -n +$((RETAIN_COUNT + 1)) | while read -r old; do
    echo "  Removing: $(basename "$old")"
    rm -f "$old"
done

echo "=== Backup complete ==="
