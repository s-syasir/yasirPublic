#!/usr/bin/env python3
"""Export each drive's latest SMART self-test result for node_exporter's textfile collector.

Debian's stock smartmon.sh only exports attributes and overall health, so a failed self-test
(e.g. a read error at one LBA while health still says PASSED) never reached Grafana.

Install: /usr/local/bin/smart_selftest_prom.py, run as root by smart-selftest-prom.timer.
Metrics (per disk):
  smart_selftest_logged          1 if the drive has at least one finished self-test logged
  smart_selftest_last_passed     1/0 for the most recent *finished* test (aborted/in-progress skipped)
  smart_selftest_last_age_hours  power-on hours since that test ran
  smart_selftest_failed_total    failed entries still in the drive's log
"""
import json, os, subprocess, sys

OUT = "/var/lib/prometheus/node-exporter/smart_selftest.prom"

# ATA status codes (high nibble): 0 ok, 1-2 aborted/interrupted, 3-8 failed, 15 in progress.
ATA_FAILED = set(range(3, 9))
# NVMe result codes: 0 ok, 5-7 failed, 15 unused slot, rest = aborted.
NVME_FAILED = {5, 6, 7}


def smartctl(*args):
    p = subprocess.run(["smartctl", "-j", *args], capture_output=True, text=True)
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return {}


def latest(dev, dtype):
    j = smartctl("-a", "-d", dtype, dev)
    poh = j.get("power_on_time", {}).get("hours")
    rows = []
    for e in j.get("ata_smart_self_test_log", {}).get("standard", {}).get("table", []):
        # Raw status byte: high nibble = status code, low nibble = percent remaining.
        code = e.get("status", {}).get("value", 0xF0) >> 4
        if code == 0 or code in ATA_FAILED:
            rows.append((code == 0, e.get("type", {}).get("string", "?"), e.get("lifetime_hours")))
    for e in j.get("nvme_self_test_log", {}).get("table", []):
        code = e.get("self_test_result", {}).get("value", 15)
        if code == 0 or code in NVME_FAILED:
            rows.append((code == 0, e.get("self_test_code", {}).get("string", "?"), e.get("power_on_hours")))
    return poh, rows  # both logs list newest first


def main():
    scan = smartctl("--scan-open").get("devices", [])
    lines = [
        "# HELP smart_selftest_logged 1 if the drive has a finished SMART self-test in its log.",
        "# TYPE smart_selftest_logged gauge",
        "# HELP smart_selftest_last_passed 1 if the most recent finished SMART self-test passed.",
        "# TYPE smart_selftest_last_passed gauge",
        "# HELP smart_selftest_last_age_hours Power-on hours since the most recent finished self-test.",
        "# TYPE smart_selftest_last_age_hours gauge",
        "# HELP smart_selftest_failed_total Failed self-test entries still in the drive's log.",
        "# TYPE smart_selftest_failed_total gauge",
    ]
    for d in scan:
        dev, dtype = d.get("name"), d.get("type", "auto")
        if not dev:
            continue
        poh, rows = latest(dev, dtype)
        lbl = f'disk="{dev}",type="{dtype}"'
        lines.append(f"smart_selftest_logged{{{lbl}}} {1 if rows else 0}")
        lines.append(f"smart_selftest_failed_total{{{lbl}}} {sum(1 for r in rows if not r[0])}")
        if rows:
            passed, ttype, hours = rows[0]
            lines.append(f'smart_selftest_last_passed{{{lbl},test="{ttype}"}} {1 if passed else 0}')
            if poh is not None and hours is not None:
                lines.append(f"smart_selftest_last_age_hours{{{lbl}}} {max(poh - hours, 0)}")
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)
    if "-v" in sys.argv:
        print("\n".join(l for l in lines if not l.startswith("#")))


if __name__ == "__main__":
    main()
