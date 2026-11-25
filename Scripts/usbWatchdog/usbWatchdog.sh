#!/bin/bash
# Watches the kernel log for USB faults and alerts while the machine is still
# usable. Run by usbWatchdog.service (see installUsbWatchdog.sh), or by hand:
#
#   usbWatchdog.sh            follow the log and alert (what the service does)
#   usbWatchdog.sh --check    print this boot's faults and exit
#
# SYMPTOM
#   Keyboard and mouse die, nothing new will connect, load average climbs on an
#   idle machine. By the time it is noticed the desktop is unusable and the only
#   way in is ssh.
#
# CAUSE
#   A USB device fails to re-enumerate (error -32/-71, "not accepting address").
#   That can leave xHCI's command ring inconsistent, and a hot unplug arriving
#   in that state wedges usb_hub_wq: kworkers sit in D state in xhci_setup_device
#   forever, unkillable, so no further device on that controller can enumerate.
#   Only a reboot clears it. Observed on poppy 2026-11-23, controller <PCI_ADDR>.
#
# WHY WATCH RATHER THAN FIX
#   The deadlock is a kernel defect, there is nothing to configure around it. But
#   the enumeration failures that precede it show up in the log seconds to minutes
#   earlier, while the desktop still works. Catching those is the difference
#   between power-cycling a hung box and noticing a flaky cable in time.
set -uo pipefail

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/usbWatchdog.log"
STATE="${XDG_RUNTIME_DIR:-/tmp}/usbWatchdog"
COOLDOWN=300

# everything that preceded the lockup, plus the lockup itself
# "Cannot enable" is anchored: bare, it also matches kvm_amd's x2AVIC firmware-bug line
PATTERNS='error -(32|71|110)|not accepting address|not responding to setup address|disabled by hub|over-current|Cannot enable\. Maybe|mismatched command completion|unknown event type|invalid context state|blocked for more than'

# notify-send needs the session bus, which a user service does not always inherit
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] ||
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"

mkdir -p "$STATE" "$(dirname "$LOG")"

# one key per device per error class, so a retry storm is a single alert
category() {
    local dev err
    dev=$(grep -oE '[0-9]+-[0-9.]+(-port[0-9]+)?' <<<"$1" | head -1)
    err=$(grep -oE 'error -[0-9]+|not accepting address|not responding to setup address|disabled by hub|over-current|Cannot enable|mismatched command completion|unknown event type|invalid context state|blocked for more than' <<<"$1" | head -1)
    printf '%s' "${dev:-none}_${err:-other}" | tr -c 'a-zA-Z0-9_' '_'
}

alert() {
    local line=$1 key stamp now
    now=$(date +%s)
    key=$(category "$line")
    stamp="$STATE/$key"
    if [ -f "$stamp" ] && [ $(( now - $(cat "$stamp" 2>/dev/null || echo 0) )) -lt "$COOLDOWN" ]; then
        return
    fi
    echo "$now" >"$stamp"
    printf '%s  %s\n' "$(date -Is)" "$line" >>"$LOG"
    if [ -t 1 ]; then
        printf 'USB FAULT  %s\n' "$line"
    else
        notify-send -u critical -i dialog-warning \
            "USB fault detected" "${line}

Logged to ${LOG}" 2>/dev/null
    fi
}

if [ "${1:-}" = "--check" ]; then
    hits=$(journalctl -k -b --no-pager -o short-iso 2>/dev/null | grep -E "$PATTERNS")
    if [ -z "$hits" ]; then
        echo "no USB faults this boot"
    else
        printf '%s\n' "$hits"
        printf '\n%s fault lines this boot\n' "$(wc -l <<<"$hits")"
    fi
    exit 0
fi

# anything that went wrong before login, summarised once
backfill=$(journalctl -k -b --no-pager -o cat 2>/dev/null | grep -cE "$PATTERNS")
if [ "${backfill:-0}" -gt 0 ]; then
    printf '%s  %s fault lines already present this boot\n' "$(date -Is)" "$backfill" >>"$LOG"
    notify-send -u normal -i dialog-warning "USB faults earlier this boot" \
        "${backfill} fault lines before the watchdog started.
Run: usbWatchdog.sh --check" 2>/dev/null
fi

journalctl -k -f -n0 -o short-iso 2>/dev/null |
    grep --line-buffered -E "$PATTERNS" |
    while IFS= read -r line; do alert "$line"; done
