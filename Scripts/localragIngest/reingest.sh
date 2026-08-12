#!/bin/bash
# Nightly re-index of Joplin notes into LocalRAG's vector DB.
#
# WHY THIS IS NEEDED: the headless Joplin client on this host keeps database.sqlite in
# sync continuously, but ChromaDB is only written by ingest.py. Without this, the app
# happily answers from whatever the notes looked like the last time someone ran it by
# hand - stale answers with no error and no clue anything is wrong.
#
# Guarded on ~/LocalRAG so it is a no-op on every other host in the fleet (the repo is
# shared, this job is not).
[ -d "$HOME/LocalRAG" ] || exit 0

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
VENV="${VENV_PATH:-$HOME/.venvs/localrag}"

. "$(dirname "$(readlink -f "$0")")/../lib/joblog.sh"
job_start

# Refuse to reindex from a database that is missing or empty rather than silently
# replacing a good index with nothing.
job_run "check-notes" "$VENV/bin/python" -c "
import sqlite3, sys
db = '$HOME/.config/joplin-desktop/database.sqlite'
n = sqlite3.connect('file:'+db+'?mode=ro', uri=True).execute('select count(*) from notes').fetchone()[0]
print(f'notes available: {n}')
sys.exit(0 if n > 0 else 1)
"

job_run "ingest" bash -c "cd '$HOME/LocalRAG' && '$VENV/bin/python' ingest.py"

# Both app.py and openai_api.py load the collection at startup, so each keeps serving the
# OLD index until restarted. Restarting only one is how you end up with a fresh index on the
# service nobody uses and stale answers on the one they do.
#
# `systemctl restart` STARTS a stopped unit, so this cannot be a blind restart: the Gradio UI
# has no authentication and is deliberately left disabled here, and a 5am cron must not be
# what turns it back on. Refresh what is running, start what is enabled, skip the rest.
job_run "restart-services" bash -c '
for unit in localrag-api.service localrag.service; do
    [ -n "$(systemctl --user list-unit-files --no-legend "$unit" 2>/dev/null)" ] || continue
    if systemctl --user is-active --quiet "$unit"; then
        echo "restarting $unit"
    elif systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
        echo "starting $unit (enabled but stopped)"
    else
        echo "skipping $unit (disabled)"
        continue
    fi
    systemctl --user restart "$unit" || exit 1
done'

job_end
