#!/bin/bash
# Copies custom/*.conf into NPM's /data/nginx/custom and reloads nginx. If
# the config test fails, the previous custom files are put back.
set -euo pipefail

cd "$(dirname "$0")/.."
CONTAINER="${NPM_CONTAINER:-nginx-proxy-manager}"
CUSTOM_DIR=/data/nginx/custom

previous="$(mktemp -d)"
trap 'rm -rf "$previous"' EXIT
docker exec "$CONTAINER" mkdir -p "$CUSTOM_DIR"
docker cp "$CONTAINER:$CUSTOM_DIR/." "$previous/"

for file in custom/*.conf; do
    docker cp "$file" "$CONTAINER:$CUSTOM_DIR/$(basename "$file")"
done

if ! docker exec "$CONTAINER" nginx -t -q; then
    docker exec "$CONTAINER" sh -c "rm -f $CUSTOM_DIR/*.conf"
    docker cp "$previous/." "$CONTAINER:$CUSTOM_DIR/"
    echo "nginx -t failed; the previous custom config is back in place" >&2
    exit 1
fi

docker exec "$CONTAINER" nginx -s reload
echo "custom config applied, nginx reloaded"
