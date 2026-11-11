#!/bin/bash
# Records this network's public IPv4 for porty's Alloy, which tags portfolio log lines from it home="true"
# so the Grafana portfolio-access alert skips my own visits. Residential IP, so it drifts.

OUT=/home/yasir/yasirsgarageData/home-ip.txt
STALE_MIN=60
valid() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

lookup() {
    local src
    for src in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
        ip=$(curl -4 -s -m 10 "$src" | tr -d '[:space:]')
        valid "$ip" && return 0
    done
    return 1
}

# ride out short internet blips (a 30s drop at 04:50 on 2026-11-11 fired two cron alerts)
for attempt in 1 2 3; do
    lookup && break
    [ $attempt -lt 3 ] && sleep 30
done

if ! valid "$ip"; then
    # the file's mtime is the last confirmed lookup; keeping the last known IP is harmless for a while
    if [ -n "$(find "$OUT" -mmin -$STALE_MIN 2>/dev/null)" ]; then
        echo "updateHomeIP: no public IP from any source after 3 tries, keeping $(cat "$OUT") (confirmed <${STALE_MIN}m ago)"
        exit 0
    fi
    echo "updateHomeIP: no valid public IP from any source for over ${STALE_MIN}m" >&2
    exit 1
fi

old=$(cat "$OUT" 2>/dev/null)
if [ "$ip" = "$old" ]; then
    touch "$OUT"
    exit 0
fi
# no trailing newline: Alloy splices the file content straight into a template comparison
printf '%s' "$ip" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
echo "updateHomeIP: home IP changed ${old:-<none>} -> $ip"
