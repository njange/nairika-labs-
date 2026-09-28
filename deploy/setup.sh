#!/usr/bin/env bash
# One-time setup for the Nairika Labs site on the shared VPS.
# Runs the app in Docker on 127.0.0.1:5190 behind the existing nginx.
# Only adds its own files; other sites on the server are left alone. Safe to re-run.
#
# Usage (as root):  bash setup.sh
set -euo pipefail

DOMAIN=nairika.co.ke
APP_DIR=/opt/nairika
REPO_URL=https://github.com/njange/nairika-labs-.git
SITE_CONF=/etc/nginx/sites-available/$DOMAIN.conf

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash setup.sh"; exit 1; }

if [ ! -d "$APP_DIR/.git" ]; then
  echo "==> Cloning into $APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
fi

if [ ! -f "$APP_DIR/.env" ]; then
  cat <<EOF

!! $APP_DIR/.env is missing. Create it with these variables, then re-run this script:

   nano $APP_DIR/.env

   SUPABASE_URL=...
   SUPABASE_PUBLISHABLE_KEY=...
   SUPABASE_SERVICE_ROLE_KEY=...
   VITE_SUPABASE_URL=...
   VITE_SUPABASE_PUBLISHABLE_KEY=...
   VITE_SUPABASE_PROJECT_ID=...

EOF
  exit 1
fi
chmod 600 "$APP_DIR/.env"

echo "==> Building and starting the container"
bash "$APP_DIR/deploy/deploy.sh"

echo "==> nginx site"
# Don't overwrite an existing file: certbot adds its HTTPS config to it.
if [ ! -f "$SITE_CONF" ]; then
  cp "$APP_DIR/deploy/nginx/$DOMAIN.conf" "$SITE_CONF"
fi
ln -sf "$SITE_CONF" "/etc/nginx/sites-enabled/$DOMAIN.conf"
nginx -t
systemctl reload nginx

echo
echo "Done. Site is served over HTTP for $DOMAIN."
echo "Once $DOMAIN resolves to this server, add HTTPS with:"
echo "  certbot --nginx -d $DOMAIN -d www.$DOMAIN"
