#!/usr/bin/env bash
# MT7922 (mt7921e) firmware wedges after ethernet plug/unplug: scans return no
# networks though the card is up. Reloading the driver reinitializes it.
set -euo pipefail

echo "reloading mt7921e..."
sudo modprobe -r mt7921e
sleep 2
sudo modprobe mt7921e
sleep 4

echo "rescanning..."
nmcli device wifi rescan
sleep 5
nmcli -f IN-USE,SSID,SIGNAL device wifi list
