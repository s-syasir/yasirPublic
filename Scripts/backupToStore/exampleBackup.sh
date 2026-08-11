#!/bin/bash
# Template for a per-host "backup into the git repo" job. Copy to backup<Host>.sh.
#
# This is the ONLY file in this directory published to the public mirror; the real
# per-host copies are not, because they enumerate exactly which service holds which
# secret. Keep this one generic.
#
# WHAT THIS IS FOR: pulling the small, restore-critical config out of a host and into
# the Store/ tree so it lands in git. It is NOT a data backup - bulk data goes to the
# NAS via the rsyncLocalScripts job. The whole discipline here is keeping the repo small.

shopt -s extglob

HOST="$(hostname)"
STORE="$HOME/Store/2025_backup/<category>/$HOST"     # e.g. main-servers / baby-servers
ARCHETYPE="$HOME/Store/archetypes/$HOST"

# Page cache fills up fast when copying many GB; drop it between big steps so a small
# VM does not OOM mid-backup.
drop_cache() { sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null; }

# ionice keeps this off the critical path; the host stays responsive while it runs.
safe_copy() { sudo ionice -c 3 rsync -a "$1" "$2"; }

# --- system config ------------------------------------------------------------------
rm -rf "$STORE/slashStuff/"*
safe_copy /etc/ "$STORE/slashStuff/etc/"

# /sbin is distro binaries that apt reinstalls byte-identically, and they do NOT delta in
# git - one 41MB binary committed 7 times is ~280MB of permanent history for something
# `apt install` reproduces exactly. Keep the small local scripts, drop the compiled weight,
# and leave a manifest recording what was there.
sudo ionice -c 3 rsync -a --max-size=1M /sbin/ "$STORE/slashStuff/sbin/"
ls -lA /sbin > "$STORE/slashStuff/sbin.manifest.txt"
drop_cache

# root-owned files are painful to work with later; hand them back.
sudo chown -R "$(id -un)" "$STORE/slashStuff/"*

# --- package + cron state (the real restore path for binaries) -----------------------
"$HOME/Scripts/backupCronTab/backup.sh"
"$HOME/Scripts/backupPackages/backupAptPackages.sh"

# --- dotfiles and generated lists ----------------------------------------------------
ionice -c 3 rsync -a "$HOME"/{.config,.local,aptlist.txt,installedpackages.txt,cron,.bashrc} "$STORE/"
drop_cache

# --- per-service config --------------------------------------------------------------
# One block per service. The pattern that matters: copy the CONFIG, exclude the DATA.
# Caches, media, search indexes and raw database directories are either re-downloadable
# or too big for git, and a raw datadir copy is not crash-consistent anyway.
#
#   mkdir -p "$STORE/docker/<service>/"
#   sudo ionice -c 3 rsync -a \
#       --exclude='cache' --exclude='logs' --exclude='*.db' \
#       "$HOME/docker/<service>/" "$STORE/docker/<service>/"
#   drop_cache
#
# For anything with a real database, dump it instead of copying the datadir:
#
#   docker exec <db-container> sh -c 'exec mariadb-dump --single-transaction \
#       --no-tablespaces -u root -p"$MYSQL_ROOT_PASSWORD" <db>' > "$STORE/docker/<svc>/dump.sql"
#
# Note the password comes from the container's own environment - it is never written
# into this script.

sudo chown -R "$(id -un)" "$STORE/docker/" 2>/dev/null || true

# Strip bulky re-downloadable junk before mirroring into the archetype copy.
"$HOME/Scripts/backupToStore/_pruneBackupJunk.sh" "$STORE"

# --- archetype mirror ----------------------------------------------------------------
# archetypes/ is the "what a fresh host of this type looks like" copy: dotfiles and
# generated lists, without the host-specific system and service data.
ionice -c 3 rsync -a "$STORE"/.[!.]* "$ARCHETYPE/"
ionice -c 3 rsync -a --exclude='slashStuff' --exclude='docker' "$STORE/" "$ARCHETYPE/"
