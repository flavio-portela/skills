#!/usr/bin/env bash
# Start the RPC controller without tmux; keep a per-parent-session lock until it exits.
# Usage: headless-run.sh <session-key> <slug> <workdir> <brief-file> [model] [pi-bin]
set -euo pipefail
SESSION_KEY="${1:?session key required}"
SLUG="${2:?slug required}"
WORKDIR="${3:?workdir required}"
BRIEF="${4:?brief required}"
MODEL="${5:-}"
PIBIN="${6:-${PI_TASK_PI_BIN:-pi}}"
[[ "$SESSION_KEY" =~ ^[a-f0-9]{64}$ ]] || { echo "invalid session key" >&2; exit 3; }
[[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid slug" >&2; exit 3; }
[ -d "$WORKDIR" ] && [ -f "$BRIEF" ] || { echo "missing workdir or brief" >&2; exit 3; }
ROOT="${PI_TASK_ROOT:-/tmp/pi-tasks}"
SCRATCH="$ROOT/$SLUG"
LOCK="$ROOT/.active-$SESSION_KEY"
GUARD="$ROOT/.active-$SESSION_KEY.guard"
mkdir -p "$ROOT"
exec {LOCKFD}>"$GUARD"
flock -x "$LOCKFD"
if [ -f "$LOCK" ]; then
  read -r _ pid _ < "$LOCK" || true
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null &&
    ps -o command= -p "$pid" 2>/dev/null | grep -qE 'pane-run|spawn\.sh|headless-run\.sh|rpc-task\.py'; then
    echo "another child is running in this session ($(head -1 "$LOCK"))" >&2
    exit 3
  fi
fi
echo "$SLUG $$ headless" > "$LOCK"
flock -u "$LOCKFD"
exec {LOCKFD}>&-
child=""
cleanup() {
  if [ -n "$child" ]; then
    kill "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
  exec {LOCKFD}>"$GUARD"
  flock -x "$LOCKFD"
  read -r owner owner_pid _ < "$LOCK" 2>/dev/null || true
  if [ "${owner:-}" = "$SLUG" ] && [ "${owner_pid:-}" = "$$" ]; then rm -f "$LOCK"; fi
  flock -u "$LOCKFD"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
rm -rf "$SCRATCH"
mkdir -m 700 "$SCRATCH"
cp "$BRIEF" "$SCRATCH/brief.md"
if [ "$BRIEF" = "$ROOT/brief-$SLUG.md" ]; then rm -f "$BRIEF"; fi
printf '%s\n' "$WORKDIR" > "$SCRATCH/.workdir"
cd "$WORKDIR"
python3 "$(dirname "$0")/rpc-task.py" run "$SLUG" "$PIBIN" "$MODEL" > "$SCRATCH/controller.log" 2>&1 &
child=$!
wait "$child"
child=""
