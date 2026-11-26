#!/bin/bash
# Installs the SMART self-test exporter + timer from this directory. Run with sudo.
set -e
here=$(dirname "$(readlink -f "$0")")
install -m 755 "$here/smart_selftest_prom.py" /usr/local/bin/smart_selftest_prom.py
install -m 644 "$here/smart-selftest-prom.service" "$here/smart-selftest-prom.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now smart-selftest-prom.timer
systemctl start smart-selftest-prom.service
echo "$(hostname): timer $(systemctl is-active smart-selftest-prom.timer)"
grep -v "^#" /var/lib/prometheus/node-exporter/smart_selftest.prom
