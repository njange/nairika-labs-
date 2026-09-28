#!/usr/bin/env bash
# Pull the latest main, rebuild for Node, and restart the site.
#
# Usage (as root):  bash /home/nairika/app/deploy/deploy.sh
set -euo pipefail

APP_USER=nairika
APP_DIR=/home/$APP_USER/app
PORT=3000

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0"; exit 1; }
[ -f "$APP_DIR/.env" ] || { echo "Missing $APP_DIR/.env"; exit 1; }

cd "$APP_DIR"

echo "==> Pulling latest code"
sudo -u "$APP_USER" -H git pull --ff-only

echo "==> Installing dependencies and building"
# VITE_* values are baked into the client bundle, so .env must be loaded at build time.
sudo -u "$APP_USER" -H bash -c '
  set -euo pipefail
  set -a; . ./.env; set +a
  npm ci --no-audit --no-fund
  NITRO_PRESET=node-server npm run build
'

echo "==> Restarting"
systemctl restart nairika

for _ in $(seq 1 20); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"; then
    echo "Site is up on port $PORT."
    exit 0
  fi
  sleep 1
done

echo "Site did not respond. Recent logs:"
journalctl -u nairika -n 40 --no-pager
exit 1
