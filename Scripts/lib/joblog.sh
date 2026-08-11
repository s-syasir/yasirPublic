#!/bin/bash
# Shared journald logging for unattended cron jobs.
#
# WHY: on 2026-08-06 it turned out bigboi and docker3 had NEVER successfully backed
# up to the NAS. bigboi's cron pointed at "bigboiboiSyncJobs.sh" (typo) and docker3
# was missing /root/.ssh/<KEY> entirely. Neither failed loudly: the scripts
# had no error checking, rsync failed, the script carried on and exited 0, and cron
# mailed root on a box nobody reads. It went unnoticed for roughly eight months.
#
# Grafana Alloy ships journald to Loki on every host, so anything logged through here
# is immediately queryable and alertable:
#
#   {job="systemd-journal", syslog_identifier="homelab-job"}
#   {job="systemd-journal", syslog_identifier="homelab-job"} |= "status=FAILURE"
#   {job="systemd-journal", syslog_identifier="homelab-job"} |= "status=STEP_FAIL"
#
# Log lines are key=value so Loki/LogQL can parse them with | logfmt
#
# USAGE
#   . "$(dirname "$(readlink -f "$0")")/../lib/joblog.sh"
#   job_start
#   job_run "etc"  rsync -a /etc/ dest:/etc/
#   job_run "home" rsync -a /home/ dest:/home/
#   job_end                        # exits non-zero if ANY step failed
#
# Override the job name with JOB_NAME=... before sourcing if the filename is unhelpful.

JOB_NAME="${JOB_NAME:-$(basename "$0" .sh)}"
JOB_TAG="homelab-job"
JOB_HOST="$(hostname)"

_joblog() {  # <syslog-level> <status> <extra key=val string>
    logger -t "$JOB_TAG" -p "user.$1" -- "job=$JOB_NAME host=$JOB_HOST status=$2 $3"
}

job_start() {
    JOB_T0=$(date +%s)
    JOB_STEPS=0
    JOB_FAILS=0
    _joblog info START ""
}

# job_run <label> <command...>
# Runs the command, captures its output, logs pass/fail with duration.
# Returns the command's exit code so callers can branch if they want.
job_run() {
    local label="$1"; shift
    local t0 out rc dur
    t0=$(date +%s)
    JOB_STEPS=$((JOB_STEPS + 1))
    out=$("$@" 2>&1); rc=$?
    dur=$(( $(date +%s) - t0 ))
    if [ $rc -eq 0 ]; then
        _joblog info STEP_OK "step=$label duration=${dur}s"
    else
        JOB_FAILS=$((JOB_FAILS + 1))
        # Keep the tail of stderr so the alert says WHY, not just that it broke.
        _joblog err STEP_FAIL "step=$label rc=$rc duration=${dur}s error=\"$(printf '%s' "$out" | tail -2 | tr '\n' ' ' | tr -d '"' | cut -c1-300)\""
    fi
    return $rc
}

job_end() {
    local dur=$(( $(date +%s) - ${JOB_T0:-$(date +%s)} ))
    if [ "${JOB_FAILS:-0}" -eq 0 ]; then
        _joblog info SUCCESS "steps=${JOB_STEPS:-0} duration=${dur}s"
        return 0
    fi
    _joblog err FAILURE "steps=${JOB_STEPS:-0} failed=${JOB_FAILS} duration=${dur}s"
    return 1
}
