#!/bin/bash
# Records this network's public IPv4 for porty's Alloy, which tags portfolio log lines from it home="true"
# so the Grafana portfolio-access alert skips my own visits. Residential IP, so it drifts.

OUT=/home/yasir/yasirsgarageData/home-ip.txt
valid() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

for src in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
    ip=$(curl -4 -s -m 10 "$src" | tr -d '[:space:]')
    valid "$ip" && break
done
valid "$ip" || { echo "updateHomeIP: no valid public IP from any source" >&2; exit 1; }

old=$(cat "$OUT" 2>/dev/null)
[ "$ip" = "$old" ] && exit 0
# no trailing newline: Alloy splices the file content straight into a template comparison
printf '%s' "$ip" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
echo "updateHomeIP: home IP changed ${old:-<none>} -> $ip"
