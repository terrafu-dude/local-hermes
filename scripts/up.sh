#!/usr/bin/env bash
# local-hermes — one-command bring-up.
#
# This is the "baked-in setup": it provisions the HOST VNC desktop that the
# Hermes Desktop app's "bot screen" connects to, then starts the Docker stack.
# Docker containers can't install host packages, so this wrapper is the hook —
# run it INSTEAD of a bare `docker compose up`. First run asks for your sudo
# password once to install the VNC + XFCE system packages.
#
#   ./up.sh                     # install host VNC (once) + compose up
#   ./up.sh --build             # rebuild the hermes image too
set -uo pipefail
cd "$(dirname "$0")/.."

# ── 1. Host VNC/XFCE packages (installed only if missing) ────────────────────
PKGS="tigervnc-standalone-server xfce4-panel xfwm4 xfdesktop4 xfce4-settings \
xfce4-terminal dbus-x11 x11-xserver-utils x11-utils x11-xkb-utils xauth fonts-dejavu-core"
need=""
for p in $PKGS; do
  dpkg -s "$p" >/dev/null 2>&1 || need="$need $p"
done
if [ -n "$need" ]; then
  echo ">> Installing host VNC desktop packages:$need"
  echo "   (one sudo password prompt follows; needed only the first time)"
  sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends $need
fi

# ── 2. VNC password (from .env VNC_PASSWORD, default 'hermes') ────────────────
set -a; [ -f .env ] && . ./.env; set +a
VNC_PW="${VNC_PASSWORD:-hermes}"
mkdir -p "$HOME/.vnc"
if [ ! -s "$HOME/.vnc/passwd" ]; then
  printf '%s\n' "$VNC_PW" | vncpasswd -f > "$HOME/.vnc/passwd" 2>/dev/null \
    || printf '%s\n' "$VNC_PW" | vncpasswd -f > "$HOME/.vnc/passwd"
  chmod 600 "$HOME/.vnc/passwd"
fi

# ── 3. Start the host VNC desktop (display :1 = port 5901) if not already up ─
if ! pgrep -u "$USER" -f "Xvnc.*:1" >/dev/null 2>&1; then
  cat > "$HOME/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER; unset DBUS_SESSION_BUS_ADDRESS
dbus-launch --exit-with-session xfce4-session
EOF
  chmod +x "$HOME/.vnc/xstartup"
  vncserver -kill :1 >/dev/null 2>&1 || true
  vncserver :1 -geometry 1440x900 -depth 24 >/dev/null 2>&1 || \
    vncserver :1 -geometry 1440x900 -depth 24
fi
echo ">> Bot-screen VNC ready: vnc://localhost:5901  (password = \$VNC_PASSWORD in .env, default 'hermes')"

# ── 4. Bring up the Docker stack ─────────────────────────────────────────────
exec docker compose up -d --build "$@"
