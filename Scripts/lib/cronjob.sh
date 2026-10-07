#!/bin/bash
# Wraps a one-line cron command in joblog.sh, so its success/failure reaches Loki/Grafana
# like the backup scripts do. Exists because lilboi's nightly `qm reboot 105` failed every
# night for over a month and only told a root mailbox that bounces.
#
# USAGE (in a crontab)
#   0 3 * * * /root/Scripts/lib/cronjob.sh homieReboot /usr/sbin/qm reboot 105
#   @reboot   /home/yasir/Scripts/lib/cronjob.sh jellyfinRestart bash -c 'sleep 600 && cd ... && docker compose up -d'
#
# Output is captured into the log line instead of mailed, so chatty commands stop
# generating root mail.

[ $# -ge 2 ] || { echo "usage: $0 <job-name> <command...>" >&2; exit 2; }
JOB_NAME="$1"; shift
. "$(dirname "$(readlink -f "$0")")/joblog.sh"
job_start
job_run "$JOB_NAME" "$@"
job_end
