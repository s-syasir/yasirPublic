#!/bin/bash
# Installs usbWatchdog.sh as a user service. No sudo: yasir is in the adm group,
# so the kernel journal is readable, and a user service is what has the session
# bus that notify-send needs. Idempotent, safe to re-run.
set -euo pipefail

WORKER="$(dirname "$(readlink -f "$0")")/usbWatchdog.sh"
UNIT="$HOME/.config/systemd/user/usbWatchdog.service"

[ -f "$WORKER" ] || { echo "missing $WORKER" >&2; exit 1; }
command -v notify-send >/dev/null || echo "note: notify-send absent, alerts will only reach the log" >&2
journalctl -k -n1 --no-pager >/dev/null 2>&1 || { echo "cannot read the kernel journal; need group adm or systemd-journal" >&2; exit 1; }

chmod +x "$WORKER"
mkdir -p "$(dirname "$UNIT")"

cat >"$UNIT" <<UNITFILE
[Unit]
Description=Watch the kernel log for USB faults
After=graphical-session.target

[Service]
Type=simple
ExecStart=$WORKER
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNITFILE

systemctl --user daemon-reload
systemctl --user enable usbWatchdog.service >/dev/null
systemctl --user restart usbWatchdog.service

echo "installed: $UNIT"
systemctl --user --no-pager --lines=0 status usbWatchdog.service | head -4
echo
echo "check for faults by hand:  $WORKER --check"
echo "alert log:                 ${XDG_CACHE_HOME:-$HOME/.cache}/usbWatchdog.log"
