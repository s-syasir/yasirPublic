#!/bin/bash
# Drop whatever exit node is set and confirm traffic goes out directly again
set -euo pipefail
sudo tailscale set --exit-node=
sleep 2
curl -s https://am.i.mullvad.net/connected
