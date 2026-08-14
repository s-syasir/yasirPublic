#!/bin/bash
# Template for a per-host "restore from the git repo" job. Copy to restore<Host>.sh.
#
# This is the ONLY file in this directory published to the public mirror.
#
# ⚠ RESTORE SCRIPTS ARE DESTRUCTIVE BY DESIGN. Several of the real ones begin by
# removing the directories they are about to replace, so that a restore is a reset
# rather than a merge. Know that before running one interactively.

HOST="$(hostname)"
STORE="$HOME/Store/2025_backup/<category>/$HOST"

if [ ! -d "$STORE" ]; then
    echo "No store for $HOST at $STORE - refusing to run." >&2
    exit 1
fi

# Minimal case: just put the shell config back.
cp -r "$STORE/.bashrc" "$HOME/"

# Fuller case, if this host's backup carries more. Uncomment what applies:
#
#   rsync -a "$STORE/.config/." "$HOME/.config/"
#
# Do NOT `rm -rf "$HOME/.config"` first. It is tempting, because `cp -r` into an existing
# directory nests it (~/.config/.config) instead of merging -- but .config holds state no
# backup captures (this exact mistake wiped an entire emulator setup, repeatedly, on every
# maintenance run). rsync with a trailing /. merges correctly and deletes nothing.
#
# System files usually want reviewing rather than blind copying - a stale /etc from
# another host's backup will break more than it fixes:
#
#   sudo rsync -a --dry-run "$STORE/slashStuff/etc/" /etc/
