#!/bin/sh
# local-hermes: start the headless VNC desktop (the Hermes Desktop "bot screen")
# inside THIS container, then run the Hermes gateway as the main process.
# Runs as the `hermes` container user (same user as the gateway) so computer_use
# can attach to the same display. VNC is best-effort: even if it fails, the
# gateway always runs.
export DISPLAY=:1
VNC_CFG="$HOME/.config/tigervnc"   # TigerVNC 1.15 reads its config from here (XDG)

if command -v vncserver >/dev/null 2>&1; then
  mkdir -p "$VNC_CFG" 2>/dev/null
  printf '%s\n' "${VNC_PASSWORD:-hermes}" | vncpasswd -f \
    > "$VNC_CFG/passwd" 2>/dev/null || true
  chmod 600 "$VNC_CFG/passwd" 2>/dev/null || true
  chown "$(id -u):$(id -g)" "$VNC_CFG" "$VNC_CFG/passwd" 2>/dev/null || true

  cat > "$VNC_CFG/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER; unset DBUS_SESSION_BUS_ADDRESS
dbus-launch --exit-with-session xfce4-session
EOF
  chmod +x "$VNC_CFG/xstartup"
  chown "$(id -u):$(id -g)" "$VNC_CFG/xstartup" 2>/dev/null || true

  # Bind all interfaces (-localhost=0, overriding tigervnc's localhost default)
  # so Docker's host port 5901->5901 forward reaches it. Start if not running.
  if ! pgrep -f "Xtigervnc.*:1\|Xvnc.*:1" >/dev/null 2>&1; then
    ( vncserver :1 -localhost=0 -geometry 1440x900 -depth 24 >/tmp/vnc.log 2>&1 & )
    sleep 3   # let the display bind :1 before the gateway starts
  fi
fi

exec hermes gateway run "$@"
