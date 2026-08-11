#!/bin/bash
# Template for a per-host nightly backup-to-NAS job. Copy to <host>SyncJobs.sh, fill in
# the three variables below, and add it to root's crontab.
#
# This is the ONLY file in this directory that is published to the public mirror; the
# real per-host copies are not. Keep it generic.
#
# The value here is the EXCLUDE LIST. Every exclude below was added after a specific
# nightly failure, and each one is commented with the reason. Without them rsync exits
# 23 or 24 on files it fundamentally cannot copy, the job is marked FAILURE, and the
# alerting cries wolf every night until people start ignoring it.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# --- fill these in -----------------------------------------------------------------
BACKUP_KEY="/root/.ssh/<your-backup-key>"          # key with write access to the NAS
NAS="<user>@<nas-host>:/<path>/<to>/backup/Servers/<hostname>"
# -----------------------------------------------------------------------------------

SSH="ssh -i $BACKUP_KEY"
DEST="$NAS"

# Journald logging, so a failure is visible in Grafana/Loki instead of dying in a mail
# spool nobody reads. Two hosts here went ~8 months without a single successful backup
# because the scripts had no error checking: rsync failed, the script carried on and
# exited 0. See lib/joblog.sh.
. "$(dirname "$(readlink -f "$0")")/../lib/joblog.sh"
job_start

job_run "backupCronTab" "$HOME/Scripts/backupCronTab/backup.sh"
job_run "backupPackages" "$HOME/Scripts/backupPackages/backupAptPackages.sh"

# --- home ---------------------------------------------------------------------------
job_run "user-home-folder" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' \
    `# the repo's own Store/ and Scripts/ are already versioned in git elsewhere` \
    --exclude 'Store' --exclude 'Scripts' --exclude '.git' --exclude '.vscode-server' \
    `# containers keep device nodes and sockets inside their bind-mounted config dirs.` \
    `# rsync cannot copy a char device or a socket and exits non-zero, which fails the` \
    `# whole job. Add one of these per offending container as you meet them.` \
    --exclude 'docker/*/etc/*/dev/' \
    --exclude 'docker/*/.gnupg/S.gpg-agent*' \
    "$HOME/" "$DEST/home/$(id -un)/"

# --- root ---------------------------------------------------------------------------
job_run "root" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' \
    /root/ "$DEST/root/"

# --- etc ----------------------------------------------------------------------------
job_run "etc" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' \
    /etc/ "$DEST/etc/"

# --- var ----------------------------------------------------------------------------
# The one that needed the most tuning. Every exclude here is a real nightly failure.
job_run "var" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' --exclude 'run/' --exclude 'lock/' --exclude 'cache/' \
    `# lxcfs is a FUSE mount of synthetic /proc+/sys files on hypervisors; unreadable as` \
    `# regular files, meaningless in a backup, and made rsync exit 23 nightly` \
    --exclude 'lib/lxcfs/' \
    `# a block device inside docker's volume dir; rsync can't copy it and exits 23` \
    --exclude 'lib/docker/volumes/backingFsBlockDev' \
    `# live Prometheus TSDB: the WAL is rewritten mid-transfer (exit 24), and a half-copied` \
    `# TSDB is worthless anyway - metrics are re-scraped, not restored` \
    --exclude 'lib/prometheus/' \
    `# postfix's chroot holds device nodes (dev/) and ~25 sockets (private/, public/)` \
    --exclude 'spool/postfix/' \
    `# container image LAYERS - tens of GB, plus sockets/char-devs/whiteouts that exit 23.` \
    `# Reconstructible by re-pulling images; the data that matters is in lib/docker/volumes/` \
    `# and any bind mounts under the home dir, both still backed up above.` \
    --exclude 'lib/docker/overlay2/' \
    /var/ "$DEST/var/"

# --- boot / sbin / usr-local-bin ------------------------------------------------------
job_run "boot" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' \
    /boot/ "$DEST/boot/"

job_run "sbin" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' \
    /sbin/ "$DEST/sbin/"

job_run "usr_local_bin" rsync -a --mkpath -e "$SSH" \
    --exclude '.stfolder' --exclude '.stversions' \
    /usr/local/bin/ "$DEST/usr/local/bin/"

# Emits the SUCCESS/FAILURE summary line and exits non-zero if any step failed, so cron
# and the alerting both see a real result.
job_end
