#!/bin/bash
# Keeps the TrueNAS NFS mounts alive. Runs every 5 minutes from root's crontab on
# docker1 and dockerArr.
#
# Logging is deliberately event-only: at 288 runs/day/host, logging every success
# would bury Loki in noise. It only speaks when it had to remount (which means the
# NAS dropped, worth knowing) or when a remount FAILED.

. "$(dirname "$(readlink -f "$0")")/../lib/joblog.sh"

BACKUP_MOUNT="<NAS_MOUNT>"
ARR_MOUNT="<NAS_MOUNT>"

remount() {  # <label> <mountpoint> <source>
    local label="$1" mp="$2" src="$3"
    mountpoint -q "$mp" && return 0          # already mounted, stay silent
    local out rc
    out=$(sudo mount -t nfs -o rw "$src" "$mp" 2>&1); rc=$?
    if [ $rc -eq 0 ]; then
        _joblog info REMOUNTED "step=$label mount=$mp msg=\"was unmounted, remounted OK\""
    else
        _joblog err STEP_FAIL "step=$label mount=$mp rc=$rc error=\"$(printf '%s' "$out" | tr '\n' ' ' | tr -d '"' | cut -c1-300)\""
    fi
    return $rc
}

rc=0
remount backup "$BACKUP_MOUNT" "<NFS_EXPORT>" || rc=1
remount arr    "$ARR_MOUNT"    "<NFS_EXPORT>"            || rc=1
exit $rc
