#!/usr/bin/env bash
# One-time VPS setup for the Nairika Labs site (Ubuntu 22.04 / 24.04).
# Installs Node + Caddy, clones the repo, creates the systemd service and
# Caddy site, then runs the first deploy. Safe to re-run.
#
# Usage (as root):  bash setup.sh yourdomain.com
set -euo pipefail

DOMAIN="${1:?Usage: bash setup.sh yourdomain.com}"
APP_USER=nairika
APP_DIR=/home/$APP_USER/app
REPO_URL=https://github.com/njange/nairika-labs-.git
PORT=3000

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash setup.sh $DOMAIN"; exit 1; }

echo "==> Installing base packages"
apt-get update
apt-get install -y curl git ufw gnupg debian-keyring debian-archive-keyring apt-transport-https

if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 22 ]; then
  echo "==> Installing Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if ! command -v caddy >/dev/null; then
  echo "==> Installing Caddy"
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
fi

echo "==> Firewall"
# Keep whatever port this SSH session came in on open, so we never lock ourselves out.
SSH_PORT="${SSH_CONNECTION##* }"
ufw allow "${SSH_PORT:-22}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> App user and code"
id "$APP_USER" &>/dev/null || adduser --disabled-password --gecos "" "$APP_USER"
if [ ! -d "$APP_DIR/.git" ]; then
  sudo -u "$APP_USER" -H git clone "$REPO_URL" "$APP_DIR"
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
chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"

echo "==> systemd service"
cat > /etc/systemd/system/nairika.service <<EOF
[Unit]
Description=Nairika Labs site
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
Environment=NODE_ENV=production PORT=$PORT HOST=127.0.0.1
ExecStart=/usr/bin/node .output/server/index.mjs
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable nairika

echo "==> Caddy site"
# With a Cloudflare Origin Certificate in place, use it (SSL mode "Full (strict)").
# Otherwise Caddy gets a Let's Encrypt certificate automatically.
if [ -f /etc/caddy/origin.pem ] && [ -f /etc/caddy/origin.key ]; then
  TLS_LINE="tls /etc/caddy/origin.pem /etc/caddy/origin.key"
else
  TLS_LINE=""
fi
[ -f /etc/caddy/Caddyfile.orig ] || cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.orig
cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN, www.$DOMAIN {
	$TLS_LINE
	encode zstd gzip
	reverse_proxy 127.0.0.1:$PORT
}
EOF
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl reload caddy || systemctl restart caddy

echo "==> First deploy"
bash "$APP_DIR/deploy/deploy.sh"

echo
echo "Done. Point $DOMAIN and www.$DOMAIN (A records) at this server's IP."
