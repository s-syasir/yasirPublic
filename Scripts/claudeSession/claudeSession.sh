#!/bin/bash
# Runs the server-ops Claude Code session in a detached tmux session with Remote Control,
# so it can be reached from the phone. Attach locally with: makeKonsolePersistent claude
#
# USAGE
#   claudeSession.sh start   # no-op if already running
#   claudeSession.sh stop

SESSION_NAME="${TMUX_NAME:-claude}"
SESSION_ID="<REDACTED_UUID>"
CLAUDE_CMD="${CLAUDE_CMD:-/home/yasir/.local/bin/claude --resume $SESSION_ID --remote-control babyboi --permission-mode auto}"
TMUX_BIN=/usr/bin/tmux

case "$1" in
    start)
        if $TMUX_BIN has-session -t "$SESSION_NAME" 2>/dev/null; then
            echo "tmux session '$SESSION_NAME' already running"
            exit 0
        fi
        TERM=xterm-256color $TMUX_BIN new-session -d -s "$SESSION_NAME" -x 200 -y 50 -c /home/yasir "$CLAUDE_CMD"
        # claude never persists folder trust for the home dir, so the prompt appears on every launch
        for _ in $(seq 1 15); do
            sleep 2
            $TMUX_BIN has-session -t "$SESSION_NAME" 2>/dev/null || { echo "claude exited right after starting" >&2; exit 1; }
            pane=$($TMUX_BIN capture-pane -p -t "$SESSION_NAME")
            if grep -q "Yes, I trust this folder" <<<"$pane"; then
                $TMUX_BIN send-keys -t "$SESSION_NAME" Down
                sleep 0.5
                $TMUX_BIN send-keys -t "$SESSION_NAME" Enter
                sleep 3
                if $TMUX_BIN capture-pane -p -t "$SESSION_NAME" | grep -q "Yes, I trust this folder"; then
                    echo "trust prompt did not clear" >&2; exit 1
                fi
                echo "accepted folder trust prompt"
                break
            fi
        done
        echo "started tmux session '$SESSION_NAME'"
        ;;
    stop)
        $TMUX_BIN has-session -t "$SESSION_NAME" 2>/dev/null || { echo "not running"; exit 0; }
        # /exit lets claude flush the transcript before the session goes away
        $TMUX_BIN send-keys -t "$SESSION_NAME" Escape
        $TMUX_BIN send-keys -t "$SESSION_NAME" -l "/exit"
        $TMUX_BIN send-keys -t "$SESSION_NAME" Enter
        sleep 10
        $TMUX_BIN kill-session -t "$SESSION_NAME" 2>/dev/null && echo "killed leftover session" || echo "exited cleanly"
        ;;
    *)
        echo "usage: $0 start|stop" >&2
        exit 2
        ;;
esac
