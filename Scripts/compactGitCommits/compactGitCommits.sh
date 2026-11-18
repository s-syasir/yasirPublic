#!/bin/bash
# Squashes the home repo's history into 2 commits (configs, then Store) and force-pushes it.
# Run periodically on ONE machine, then on every other clone: git pull && git reflog expire --expire=now --all && git gc --prune=now
# A clone with unpushed commits must be dealt with first, or its pull replays the old history.
# Usage: compactGitCommits.sh [repo_dir] [backup_dir]     defaults: ~ and ~/gitHistoryBackups
set -euo pipefail
REPO="${1:-$HOME}"
BACKUP_DIR="${2:-$HOME/gitHistoryBackups}"
cd "$REPO"

[ "$(git symbolic-ref --short HEAD)" = main ] || { echo "not on main" >&2; exit 1; }
git fetch -q origin
OLD=$(git rev-parse HEAD)
# a push since the last pull would be silently dropped
[ "$OLD" = "$(git rev-parse origin/main)" ] || { echo "main != origin/main, pull/push first" >&2; exit 1; }

echo "== backing up current history"
mkdir -p "$BACKUP_DIR"
BUNDLE="$BACKUP_DIR/$(basename "$REPO")-history-$(date +%F-%H%M).bundle"
git bundle create -q "$BUNDLE" --all
git bundle verify -q "$BUNDLE" >/dev/null 2>&1 || { echo "bundle failed to verify: $BUNDLE" >&2; exit 1; }
echo "   $BUNDLE ($(du -h "$BUNDLE" | cut -f1)), restore with: git clone $BUNDLE <dir>"

echo "== building new history from the working tree"
git checkout -q --orphan compact
# empty index (not git rm --cached, which refuses when staged content differs from the file)
git read-tree --empty
git add -A -- . ':!Store'
git commit -q -m "add dotfiles, scripts, ansible and compose configs"
git add -A -- Store
git commit -q -m "add per-machine config backups"
if [ -n "$(git status --porcelain)" ]; then
    echo "tree not fully committed, aborting; old main untouched, run: git symbolic-ref HEAD refs/heads/main" >&2
    git status --short | head >&2
    exit 1
fi
git branch -M compact main
git log --oneline --stat=80 | grep -E '^[0-9a-f]{7,} |files? changed'

echo "== pushing (one commit per push)"
git push -q --force-with-lease=main:"$OLD" origin main~1:refs/heads/main
git push -q -u origin main

echo "== dropping old objects locally (they live in the bundle)"
git for-each-ref --format='%(refname)' refs/original refs/stash | xargs -r -n1 git update-ref -d
git reflog expire --expire=now --all
git gc -q --prune=now --aggressive
echo "   .git now $(du -sh .git | cut -f1)"
git status -sb | head -1
echo "== now on every other clone: git pull && git reflog expire --expire=now --all && git gc --prune=now"
