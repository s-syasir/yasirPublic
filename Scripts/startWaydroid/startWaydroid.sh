#!/bin/bash
# Launches Android (Waydroid) in a nested Weston window. Waydroid needs a Wayland
# compositor and this desktop is X11, so Weston provides one inside an X11 window.
# Usage: startWaydroid [WIDTHxHEIGHT]      default 2560x1440
set -u

GEO="${1:-2560x1440}"
WIDTH=${GEO%x*}
HEIGHT=${GEO#*x}
SOCKET=waydroid-wl
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/startWaydroid.log"

# waydroid-container is deliberately not enabled at boot, so it usually needs starting
systemctl is-active --quiet waydroid-container || sudo systemctl start waydroid-container

# one Weston per socket name: a second instance cannot bind the same name
if [ ! -S "${XDG_RUNTIME_DIR}/${SOCKET}" ]; then
    # setsid+nohup so closing the terminal doesn't take Android down with it
    setsid nohup weston --backend=x11 --width="$WIDTH" --height="$HEIGHT" --socket="$SOCKET" \
        >>"$LOG" 2>&1 &
    for _ in $(seq 1 30); do
        [ -S "${XDG_RUNTIME_DIR}/${SOCKET}" ] && break
        sleep 0.5
    done
fi
[ -S "${XDG_RUNTIME_DIR}/${SOCKET}" ] || { echo "weston did not start, see $LOG" >&2; exit 1; }

WAYLAND_DISPLAY="$SOCKET" setsid nohup waydroid show-full-ui >>"$LOG" 2>&1 &
echo "Android is starting in the Weston window (log: $LOG)"
echo "To stop it:  waydroid session stop"
