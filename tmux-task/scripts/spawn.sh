#!/usr/bin/env bash
# spawn.sh — run a Pi task in a visible tmux pane and block until completion.
#
# Usage:
#   spawn.sh <slug> <workdir> <brief-file> [--timeout SECONDS] [--window] [--model MODEL]
#
# The brief must include the marker line:  echo done > /tmp/pi-tasks/<slug>/done
# (see the skill's SKILL.md for the full brief protocol).
#
# Behavior:
#   - Inside tmux: opens a new pane in the current window (default) or a new window (--window).
#   - Outside tmux: opens a new detached session "pi-task-<slug>" and prints the attach command.
#   - Waits for the marker file (done), the pane dying / pi exiting (exited), or --timeout.
#   - done/exited: closes the pane (and session, if it created one). timeout: leaves it open.
#
# Exit codes: 0 done | 1 timeout (pane left open) | 2 child exited early | 3 setup error

set -euo pipefail

SLUG="" WORKDIR="" BRIEF="" TIMEOUT=1800 WINDOW=0 MODEL="" MODELARG=""
usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 3; }

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="${2:?--timeout needs a value}"; shift 2;;
    --window) WINDOW=1; shift;;
    --model) MODEL="${2:?--model needs a value}"; shift 2;;
    -h|--help) usage;;
    *)
      if [ -z "$SLUG" ]; then SLUG="$1"; shift
      elif [ -z "$WORKDIR" ]; then WORKDIR="$1"; shift
      elif [ -z "$BRIEF" ]; then BRIEF="$1"; shift
      else echo "unexpected argument: $1" >&2; usage; fi;;
  esac
done
[ -n "$SLUG" ] && [ -n "$WORKDIR" ] && [ -n "$BRIEF" ] || usage
if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "slug must be lowercase alphanumerics + hyphens, e.g. phase-2-sizing (got: $SLUG)" >&2; exit 3
fi
[ -d "$WORKDIR" ] || { echo "workdir does not exist: $WORKDIR" >&2; exit 3; }
[ -f "$BRIEF" ] || { echo "brief file does not exist: $BRIEF" >&2; exit 3; }
command -v tmux >/dev/null 2>&1 || { echo "tmux is not installed" >&2; exit 3; }
command -v pi >/dev/null 2>&1 || { echo "pi is not on PATH" >&2; exit 3; }
if [ -n "$MODEL" ]; then MODELARG="--model $MODEL"; fi

SCRATCH="/tmp/pi-tasks/$SLUG"
MARKER="$SCRATCH/done"
if ! grep -qF "echo done > $MARKER" "$BRIEF"; then
  echo "brief must include the marker line (exactly):  echo done > $MARKER" >&2
  echo "the spawner uses that file to detect completion — see SKILL.md" >&2
  exit 3
fi
mkdir -p "$SCRATCH"
cp "$BRIEF" "$SCRATCH/brief.md"

# Single-child lock: one locally-hosted model = one running pi inference at a time.
LOCK="/tmp/pi-tasks/.active"
if [ -f "$LOCK" ]; then
  other=$(cat "$LOCK" 2>/dev/null || true)
  opid=${other##* }
  if [ -n "$opid" ] && kill -0 "$opid" 2>/dev/null; then
    echo "another child is already running (lock: $other) — wait for it, or remove $LOCK if you are sure" >&2
    exit 3
  fi
fi
echo "$SLUG $$" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# --- create the pane (or session) ---
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  if [ "$WINDOW" = 1 ]; then
    WIN=$(tmux new-window -t "$TMUX" -c "$WORKDIR" -P -F '#{window_id}') \
      || { echo "could not open a new tmux window" >&2; exit 3; }
    PANE=$(tmux list-panes -t "$WIN" -F '#{pane_id}' | head -1)
    CREATED=window
  else
    PANE=$(tmux split-window -t "$TMUX_PANE" -c "$WORKDIR" -P -F '#{pane_id}') \
      || { echo "could not split the pane (window too small?) — retry with --window" >&2; exit 3; }
    CREATED=pane
  fi
  echo "task: $SLUG  pane: $PANE  created: $CREATED  workdir: $WORKDIR  timeout: ${TIMEOUT}s"
else
  SESS="pi-task-$SLUG"
  if tmux has-session -t "$SESS" 2>/dev/null; then
    echo "tmux session $SESS already exists — pick another slug" >&2; exit 3
  fi
  tmux new-session -d -s "$SESS" -c "$WORKDIR" || { echo "could not create tmux session" >&2; exit 3; }
  PANE=$(tmux list-panes -t "$SESS" -F '#{pane_id}' | head -1)
  CREATED=session
  echo "task: $SLUG  session: $SESS  pane: $PANE  workdir: $WORKDIR  timeout: ${TIMEOUT}s"
  echo "watch the task:  tmux attach -t $SESS"
fi

# --- launch interactive pi in the pane ---
PROMPT="Read $SCRATCH/brief.md in full. It is your brief — execute exactly what it says, in full."
tmux send-keys -t "$PANE" "pi --approve --name task-$SLUG $MODELARG \"$PROMPT\"" Enter
sleep 6
CMD=$(tmux display-message -t "$PANE" -p '#{pane_current_command}' 2>/dev/null || echo none)
if [ "$CMD" != "pi" ] && [ "$CMD" != "node" ]; then
  echo "pi did not start (pane command: $CMD)" >&2
  tmux kill-pane -t "$PANE" 2>/dev/null || true
  if [ "$CREATED" = "session" ]; then tmux kill-session -t "$SESS" 2>/dev/null || true; fi
  exit 2
fi

# --- wait loop: pure bash, zero inference (single local model stays safe) ---
START=$(date +%s)
STATUS=""
while :; do
  if [ -f "$MARKER" ]; then STATUS=done; break; fi
  if ! tmux list-panes -t "$PANE" >/dev/null 2>&1; then STATUS=exited; break; fi
  CMD=$(tmux display-message -t "$PANE" -p '#{pane_current_command}' 2>/dev/null || echo none)
  if [ "$CMD" != "pi" ] && [ "$CMD" != "node" ]; then STATUS=exited; break; fi
  NOW=$(date +%s); EL=$((NOW - START))
  if [ "$EL" -ge "$TIMEOUT" ]; then STATUS=timeout; break; fi
  if [ "$EL" -gt 0 ] && [ $((EL % 60)) -lt 11 ]; then
    echo "still running: $SLUG (${EL}s)"
  fi
  sleep 10
done
EL=$(( $(date +%s) - START ))

# --- finish ---
echo "---"
case "$STATUS" in
  done)
    sleep 15 # let the child finish its closing text before we take the GPU back
    tmux capture-pane -p -t "$PANE" -S -400 > "$SCRATCH/tail.txt" 2>/dev/null || true
    tmux kill-pane -t "$PANE" 2>/dev/null || true
    if [ "$CREATED" = "session" ]; then tmux kill-session -t "$SESS" 2>/dev/null || true; fi
    echo "STATUS: done (${EL}s) — pane closed"
    ;;
  timeout)
    tmux capture-pane -p -t "$PANE" -S -400 > "$SCRATCH/tail.txt" 2>/dev/null || true
    echo "STATUS: timeout after ${TIMEOUT}s — pane left OPEN (task may still be running)"
    if [ "$CREATED" = "session" ]; then
      echo "watch: tmux attach -t $SESS"
    else
      echo "pane: $PANE (still in your current window)"
    fi
    echo "do NOT spawn another child until this one is confirmed finished."
    echo "resume its saved session later with: cd $WORKDIR && pi -r"
    ;;
  exited)
    tmux capture-pane -p -t "$PANE" -S -400 > "$SCRATCH/tail.txt" 2>/dev/null || true
    tmux kill-pane -t "$PANE" 2>/dev/null || true
    if [ "$CREATED" = "session" ]; then tmux kill-session -t "$SESS" 2>/dev/null || true; fi
    echo "STATUS: child exited early (${EL}s) — crash, quit, or unexpected exit; see tail"
    ;;
esac
echo "tail:  $SCRATCH/tail.txt"
echo "brief: $SCRATCH/brief.md"
echo "resume full transcript: cd $WORKDIR && pi -r"
case "$STATUS" in
  done) exit 0;;
  timeout) exit 1;;
  exited) exit 2;;
esac
