#!/usr/bin/env bash
# pane-run.sh — runs inside the task pane (launched by spawn.sh via tmux send-keys).
#
# Owns the single-child lock while rpc-task.py runs Pi in RPC mode and displays
# its events in this pane. The spawner observes the controller's outcome files.
#
# Usage: pane-run.sh <slug> [--model MODEL] [--pi-bin PATH]
set -u

SLUG="${1:?usage: pane-run.sh <slug> [--model MODEL] [--pi-bin PATH]}"
shift
MODEL=""
PIBIN="pi"
while [ $# -gt 0 ]; do
  case "$1" in
    --model)  MODEL="${2:?--model needs a value}"; shift 2;;
    --pi-bin) PIBIN="${2:?--pi-bin needs a value}"; shift 2;;
    *) echo "unknown argument: $1" >&2; exit 3;;
  esac
done

SCRATCH="/tmp/pi-tasks/$SLUG"
MARKER="$SCRATCH/done"
BLOCKEDF="$SCRATCH/blocked"
STATUSF="$SCRATCH/status"
LOCK="/tmp/pi-tasks/.active"
LOCK_GUARD="/tmp/pi-tasks/.active.guard"

lock_guard() {
  exec {LOCKFD}> "$LOCK_GUARD"
  flock -x "$LOCKFD"
}

unlock_guard() {
  flock -u "$LOCKFD"
  exec {LOCKFD}>&-
}

PANEID=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_id}' 2>/dev/null || echo '?')
lock_guard
read -r OWNER_SLUG OWNER_PID OWNER_PANE < "$LOCK" 2>/dev/null || true
if [ "${OWNER_SLUG:-}" != "$SLUG" ] || [ "${OWNER_PANE:-}" != "$PANEID" ]; then
  unlock_guard
  echo "lock no longer belongs to $SLUG in $PANEID — refusing to start pi" >&2
  echo "exited 3" > "$STATUSF"
  exit 3
fi
# Claim the lock with our own pid while the spawner is still alive.
echo "$SLUG $$ $PANEID" > "$LOCK"
unlock_guard
echo "$$" > "$SCRATCH/pane.pid"

python3 "$(dirname "$0")/rpc-task.py" run "$SLUG" "$PIBIN" "$MODEL"
RC=$?

# The controller writes done/blocked/status. Record unexpected exits too.
if [ ! -f "$MARKER" ] && [ ! -f "$BLOCKEDF" ] && [ ! -f "$STATUSF" ]; then
  echo "exited $RC" > "$STATUSF"
fi
lock_guard
read -r OWNER_SLUG OWNER_PID OWNER_PANE < "$LOCK" 2>/dev/null || true
if [ "${OWNER_SLUG:-}" = "$SLUG" ] && [ "${OWNER_PID:-}" = "$$" ] && [ "${OWNER_PANE:-}" = "$PANEID" ]; then
  rm -f "$LOCK"
fi
unlock_guard
exit "$RC"
