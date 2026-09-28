#!/usr/bin/env bash
# Pull the latest main, rebuild the container, and restart it.
#
# Usage (as root):  bash /opt/nairika/deploy/deploy.sh
set -euo pipefail

APP_DIR=/opt/nairika
PORT=5190

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0"; exit 1; }
[ -f "$APP_DIR/.env" ] || { echo "Missing $APP_DIR/.env"; exit 1; }

cd "$APP_DIR"

echo "==> Pulling latest code"
git pull --ff-only

echo "==> Building and restarting"
docker compose up -d --build

for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"; then
    echo "Site is up on 127.0.0.1:$PORT."
    exit 0
  fi
  sleep 1
done

echo "Site did not respond. Recent logs:"
docker compose logs --tail 40 web
exit 1
