#!/usr/bin/env bash
# Amber Subscription — one-line installer
#   bash <(curl -fsSL https://raw.githubusercontent.com/frank0live/amber-subscription/main/install.sh)
#
# Detects the web server (nginx / caddy / apache / none), installs the page
# under /var/www/amber-sub, serves it at https://<your-domain>/amber/ and prints
# ready-to-share links for every subscriber token.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/frank0live/amber-subscription/main"
WEBROOT="/var/www/amber-sub"
PREFIX="/amber"
PANEL_DEFAULT=""

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()   { printf '  \033[31m✗\033[0m %s\n' "$*"; exit 1; }

bold "Amber Subscription installer"
echo

# ---------------------------------------------------------------- 1. root check
[ "$(id -u)" = "0" ] || die "run as root (sudo)"
ok "root"

# ---------------------------------------------------------------- 2. panel url
detect_panel() {
  # 1) explicit value
  [ -n "$PANEL_DEFAULT" ] && { echo "$PANEL_DEFAULT"; return; }
  # 2) PORT_FILE / panel port from a local 3x-ui or marzban install
  for db in /etc/x-ui/x-ui.db /etc/3x-ui/x-ui.db; do
    [ -r "$db" ] || continue
    if command -v sqlite3 >/dev/null 2>&1; then
      p=$(sqlite3 "$db" "SELECT value FROM settings WHERE key='port';" 2>/dev/null || true)
      [ -n "${p:-}" ] && { echo "http://127.0.0.1:$p"; return; }
    fi
  done
  # 3) running uvicorn/fastapi process with :PORT
  p=$(ss -tlnp 2>/dev/null | grep -E 'python|uvicorn' | grep -oE ':[0-9]{4,5}' | head -1 | tr -d ':')
  [ -n "${p:-}" ] && { echo "http://127.0.0.1:$p"; return; }
  # 4) container exposing a panel
  if command -v docker >/dev/null 2>&1; then
    p=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oE '0.0.0.0:([0-9]{4,5})->' | head -1 | grep -oE '[0-9]{4,5}')
    [ -n "${p:-}" ] && { echo "http://127.0.0.1:$p"; return; }
  fi
  echo ""
}
PANEL="$(detect_panel)"
if [ -n "$PANEL" ]; then ok "panel: $PANEL"; else warn "panel not detected — links will still work, you just need ?panel=<url>"; fi

# ---------------------------------------------------------------- 3. web server
detect_server() {
  # systemd-backed host: prefer an active service
  if command -v systemctl >/dev/null 2>&1; then
    if command -v nginx  >/dev/null 2>&1 && systemctl is-active --quiet nginx 2>/dev/null; then echo nginx; return; fi
    if command -v caddy  >/dev/null 2>&1 && systemctl is-active --quiet caddy  2>/dev/null; then echo caddy;  return; fi
  fi
  # no systemd (container / chroot): fall back to the binary + its config tree
  if command -v nginx >/dev/null 2>&1 && { [ -d /etc/nginx/conf.d ] || [ -d /etc/nginx/sites-available ]; }; then echo nginx; return; fi
  if command -v caddy  >/dev/null 2>&1 && [ -f /etc/caddy/Caddyfile ]; then echo caddy; return; fi
  if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then echo apache; return; fi
  echo none
}
SERVER="$(detect_server)"
ok "server: $SERVER"

# ---------------------------------------------------------------- 4. fetch files
command -v curl >/dev/null 2>&1 || die "curl is required"
mkdir -p "$WEBROOT/assets" "$WEBROOT/amber"
curl -fsSL "$REPO_RAW/index.html"   -o "$WEBROOT/index.html"
curl -fsSL "$REPO_RAW/amber/index.html" -o "$WEBROOT/amber/index.html" 2>/dev/null || cp "$WEBROOT/index.html" "$WEBROOT/amber/index.html"
curl -fsSL "$REPO_RAW/assets/logo.png"  -o "$WEBROOT/assets/logo.png"  2>/dev/null || true
chmod -R a+rX "$WEBROOT"
ok "files → $WEBROOT"

# ---------------------------------------------------------------- 5. configure
case "$SERVER" in
  nginx)
    CONF="/etc/nginx/conf.d/amber-sub.conf"
    # A standalone server block: `location` is illegal at http level, and we must not
    # touch whatever vhost the host already serves its own site from.
    cat > "$CONF" <<NGINX
# Amber Subscription (managed by install.sh)
server {
    listen 80;
    listen [::]:80;
    server_name _;

    location = /amber { return 301 /amber/; }

    location /amber/ {
        alias $WEBROOT/;
        index index.html;
        try_files \$uri \$uri/ /amber/index.html;
        add_header Cache-Control "no-store";
    }
}
NGINX
    if ! nginx -t >/dev/null 2>&1; then
      rm -f "$CONF"
      nginx -t || true
      die "nginx config test failed — file rolled back"
    fi
    if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
      systemctl reload nginx && ok "nginx reloaded ($CONF)" || warn "systemctl reload failed — try: nginx -s reload"
    elif nginx -s reload 2>/dev/null; then
      ok "nginx reloaded (nginx -s reload)"
    else
      warn "nginx config written to $CONF — reload it manually (nginx -s reload)"
    fi
    # if the host already serves its own site on port 80, say how to merge instead
    if grep -q "server[[:space:]]*{" /etc/nginx/nginx.conf 2>/dev/null || \
       ls /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf 2>/dev/null | grep -qv "amber-sub.conf"; then
      warn "an existing vhost on port 80 may win — if so, add this inside your own server{} block:"
      echo "      location = /amber        { return 301 /amber/; }"
      echo "      location /amber/ { alias $WEBROOT/; index index.html; try_files \$uri \$uri/ /amber/index.html; }"
    fi
    ;;
  caddy)
    # append the route to the existing site block only if it isn't there yet
    if grep -qs "handle_path $PREFIX/*" /etc/caddy/Caddyfile; then
      ok "caddy route already present"
    else
      warn "caddy: add this block to your site in /etc/caddy/Caddyfile, then 'systemctl reload caddy':"
      echo
      echo "  handle_path $PREFIX/* {"
      echo "      root * $WEBROOT"
      echo "      file_server"
      echo "  }"
      echo
    fi
    ;;
  apache)
    CONF="/etc/apache2/conf-available/amber-sub.conf"
    if [ -d /etc/apache2/conf-available ]; then
      cat > "$CONF" <<APACHE
Alias $PREFIX "$WEBROOT"
<Directory "$WEBROOT">
    Options -Indexes +FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
APACHE
      a2enconf amber-sub >/dev/null 2>&1 && systemctl reload apache2 && ok "apache enabled + reloaded"
    else
      warn "apache: manually add an Alias $PREFIX $WEBROOT and reload httpd"
    fi
    ;;
  none)
    warn "no web server found — files are in $WEBROOT; point any vhost at it with prefix $PREFIX"
    ;;
esac

# ---------------------------------------------------------------- 6. self test
LOCAL="$(curl -sk -o /dev/null -w '%{http_code}' "http://127.0.0.1$PREFIX/" 2>/dev/null || echo 000)"
case "$LOCAL" in
  200) ok "local test: 200 OK" ;;
  *)   warn "local test: HTTP $LOCAL (TLS/domain may be handled by a proxy in front)" ;;
esac

# ---------------------------------------------------------------- 7. print links
bold ""
bold "Done. Share these links with subscribers:"
echo
if [ -n "$PANEL" ]; then
  echo "  https://YOUR-DOMAIN$PREFIX/?panel=$(printf '%s' "$PANEL" | sed 's/:/%3A/g; s#/#%2F#g')&token=<TOKEN>"
else
  echo "  https://YOUR-DOMAIN$PREFIX/?panel=<PANEL_URL>&token=<TOKEN>"
fi
echo "  https://YOUR-DOMAIN$PREFIX/#<TOKEN>        (uses the panel preset if you set PANEL_DEFAULT)"
echo
echo "  <TOKEN> = whatever the panel shows after /sub/ in the subscriber's link."
bold "Update: re-run this command (it is idempotent)."
