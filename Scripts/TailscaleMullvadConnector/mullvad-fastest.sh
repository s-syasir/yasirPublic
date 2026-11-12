#!/bin/bash
# Connect to the lowest-latency Mullvad exit node. Usage: mullvad-fastest.sh [Country] (default USA)
set -euo pipefail
COUNTRY="${1:-USA}"

sudo -v
# an active exit node would skew every ping, so measure from the real connection
sudo tailscale set --exit-node=

echo "Pinging Mullvad relays in $COUNTRY..."
RESULTS=$(tailscale exit-node list --filter="$COUNTRY" \
    | grep -o '[a-z]\{2\}-[a-z]\{3\}-wg-[0-9]\{3\}' | sort -u \
    | xargs -P32 -I{} sh -c 'printf . >&2; t=$(timeout 4 ping -c2 -W1 -q {}.relays.mullvad.net 2>/dev/null | awk -F/ "/rtt/{print \$5}"); [ -n "$t" ] && echo "$t {}"' \
    | sort -n | head -5 || true)
echo

if [ -z "$RESULTS" ]; then
    echo "No reachable Mullvad relays found for '$COUNTRY'." >&2
    exit 1
fi
echo "$RESULTS"

BEST=$(echo "$RESULTS" | head -1 | awk '{print $2}')
echo "Connecting to $BEST.mullvad.ts.net"
sudo tailscale set --exit-node="$BEST.mullvad.ts.net"
sleep 2
curl -s https://am.i.mullvad.net/connected
