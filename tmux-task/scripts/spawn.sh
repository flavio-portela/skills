#!/usr/bin/env bash
# spawn.sh — run a Pi RPC task with a live activity view in a tmux pane.
#
# Usage:
#   spawn.sh <slug> <workdir> <brief-file> [--timeout SECONDS] [--window] [--model MODEL] [--pi-bin PATH]
#   spawn.sh --resume <slug> [--send ANSWER] [--timeout SECONDS]
#
# The child reports outcomes through the task_report Pi tool (see SKILL.md).
#
# Behavior:
#   - Inside tmux: opens a new pane in the current window (default) or a new window (--window).
#   - Outside tmux: opens a new detached session "pi-task-<slug>" and prints the attach command.
#   - The pane runs pane-run.sh, which owns the single-child lock while a Python
#     controller displays Pi's RPC events and records structured task outcomes.
#   - Waits (pure bash, zero inference) for: the done marker, a blocked file
#     (exit 4, pane closed), an ask file (question — exit 5, pane left open),
#     the status file, the pane dying, or --timeout. A heartbeat prints every
#     ~60s and warns when the pane shows no change for 2+ minutes.
#   - activity.log and events.jsonl stream to scratch; tail.txt is refreshed every poll.
#   - done / exited / blocked: closes the pane (and session, if it created one).
#     timeout / question: leaves it open; the lock stays held while the child is alive.
#   - --resume re-enters the wait loop: --send answers a pending question over RPC;
#     without --send it re-waits after a timeout.
#
# Exit codes: 0 done | 1 timeout (pane left open) | 2 child exited early or failed to start
#             | 3 setup error (incl. another child already running)
#             | 4 child reported blocked | 5 child has a question (pane left open)

set -euo pipefail

SLUG="" WORKDIR="" BRIEF="" TIMEOUT=1800 WINDOW=0 MODEL="" PIBIN="" RESUME=0 SEND=""
usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 3; }

if [ "${1:-}" = "--resume" ]; then RESUME=1; shift; fi
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)  TIMEOUT="${2:?--timeout needs a value}"; shift 2;;
    --window)   WINDOW=1; shift;;
    --model)    MODEL="${2:?--model needs a value}"; shift 2;;
    --pi-bin)   PIBIN="${2:?--pi-bin needs a value}"; shift 2;;
    --send)     SEND="${2:?--send needs a value}"; shift 2;;
    -h|--help)  usage;;
    *)
      if [ -z "$SLUG" ]; then SLUG="$1"; shift
      elif [ -z "$WORKDIR" ]; then WORKDIR="$1"; shift
      elif [ -z "$BRIEF" ]; then BRIEF="$1"; shift
      else echo "unexpected argument: $1" >&2; usage; fi;;
  esac
done
[ -n "$SLUG" ] || usage
if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "slug must be lowercase alphanumerics + hyphens, e.g. phase-2-sizing (got: $SLUG)" >&2; exit 3
fi
if ! [[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || [ "${#TIMEOUT}" -gt 9 ]; then
  echo "--timeout must be a positive integer of at most 9 digits" >&2; exit 3
fi
[ "$RESUME" = 1 ] || [ -z "$SEND" ] || { echo "--send requires --resume" >&2; exit 3; }

SCRATCH="/tmp/pi-tasks/$SLUG"
MARKER="$SCRATCH/done"
BLOCKEDF="$SCRATCH/blocked"
ASKF="$SCRATCH/ask"
STATUSF="$SCRATCH/status"
LOCK="/tmp/pi-tasks/.active"
LOCK_GUARD="/tmp/pi-tasks/.active.guard"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Is the lock held by a live spawner/wrapper (as opposed to stale)?
lock_is_live() {
  [ -f "$LOCK" ] || return 1
  local other lpid
  other=$(cat "$LOCK" 2>/dev/null || true)
  read -r _ lpid _ <<< "$other" || return 1
  [ -n "${lpid:-}" ] && kill -0 "$lpid" 2>/dev/null \
    && ps -o command= -p "$lpid" 2>/dev/null | grep -qE 'pane-run|spawn\.sh'
}

lock_guard() {
  exec {LOCKFD}> "$LOCK_GUARD"
  flock -x "$LOCKFD"
}

unlock_guard() {
  flock -u "$LOCKFD"
  exec {LOCKFD}>&-
}

release_lock_if_owned() {
  local owner_slug owner_pid owner_pane
  lock_guard
  if [ -f "$LOCK" ]; then read -r owner_slug owner_pid owner_pane < "$LOCK" || true; fi
  if [ "${owner_slug:-}" = "$SLUG" ] && [ "${owner_pid:-}" = "$1" ]; then rm -f "$LOCK"; fi
  unlock_guard
}

capture_tail() {
  if tmux capture-pane -p -t "$PANE" -S -400 > "$SCRATCH/.tail.tmp" 2>/dev/null; then
    mv -f "$SCRATCH/.tail.tmp" "$SCRATCH/tail.txt"
  fi
}

copy_transcript() {
  local session
  session=$(head -1 "$SCRATCH/.session-file" 2>/dev/null || true)
  if [ -n "$session" ] && [ -f "$session" ]; then
    cp "$session" "$SCRATCH/transcript.jsonl" 2>/dev/null || true
  fi
}

finish() {
  echo "---"
  case "$STATUS" in
    done)
      capture_tail
      tmux kill-pane -t "$PANE" 2>/dev/null || true
      [ "$CREATED" = session ] && tmux kill-session -t "$SESS" 2>/dev/null || true
      echo "STATUS: done (${EL}s) — pane closed"
      M=$(head -1 "$MARKER" 2>/dev/null || true)
      if [ -n "$M" ]; then echo "SUMMARY: $M"; fi
      ;;
    asking)
      capture_tail
      echo "STATUS: question pending (${EL}s) — pane left OPEN"
      echo "QUESTION: $(head -1 "$ASKF" 2>/dev/null || true)"
      if [ "$CREATED" = session ]; then
        echo "watch: tmux attach -t $SESS"
      fi
      echo "answer + re-wait:  bash $SCRIPT_DIR/spawn.sh --resume $SLUG --send '<your answer>'"
      echo "the lock stays held while the child is alive."
      ;;
    blocked)
      capture_tail
      tmux kill-pane -t "$PANE" 2>/dev/null || true
      [ "$CREATED" = session ] && tmux kill-session -t "$SESS" 2>/dev/null || true
      echo "STATUS: blocked after ${EL}s — $(head -1 "$BLOCKEDF" 2>/dev/null || true) — pane closed"
      ;;
    exited)
      capture_tail
      tmux kill-pane -t "$PANE" 2>/dev/null || true
      [ "$CREATED" = session ] && tmux kill-session -t "$SESS" 2>/dev/null || true
      echo "STATUS: child exited early (${EL}s) — crash, quit, or pi exit${STATUSF_CONTENT:+ (status: $STATUSF_CONTENT)}; see tail"
      ;;
    timeout)
      capture_tail
      echo "STATUS: timeout after ${TIMEOUT}s — pane left OPEN (task may still be running)"
      if [ "$CREATED" = session ]; then
        echo "watch: tmux attach -t $SESS"
      else
        echo "pane: $PANE (still in your current window)"
      fi
      echo "the lock stays held while the child is alive — do NOT spawn another child until it is confirmed finished."
      echo "resume its saved session later with: cd $WORKDIR && pi -r"
      ;;
  esac
  copy_transcript
  echo "activity: $SCRATCH/activity.log"
  echo "events: $SCRATCH/events.jsonl"
  [ -f "$SCRATCH/report.txt" ] && echo "report: $SCRATCH/report.txt" || true
  echo "tail:  $SCRATCH/tail.txt"
  echo "brief: $SCRATCH/brief.md"
  [ -f "$SCRATCH/transcript.jsonl" ] && echo "transcript: $SCRATCH/transcript.jsonl" || true
  echo "resume full transcript: cd $WORKDIR && pi -r"
}

if [ "$RESUME" = 1 ]; then
  # --- resume: re-enter the wait loop for an existing child ---
  [ -f "$SCRATCH/pane.id" ] || { echo "no pane.id in $SCRATCH — nothing to resume" >&2; exit 3; }
  PANE=$(cat "$SCRATCH/pane.id")
  CREATED="pane"; SESS=""
  if [ -f "$SCRATCH/.meta" ]; then . "$SCRATCH/.meta"; fi
  WORKDIR=$(cat "$SCRATCH/.workdir" 2>/dev/null || echo ".")
  tmux list-panes -t "$PANE" >/dev/null 2>&1 \
    || { echo "pane $PANE no longer exists — nothing to resume (diagnostics in $SCRATCH/tail.txt)" >&2; exit 3; }
  lock_is_live || { echo "no live child holds the lock — nothing to resume" >&2; exit 3; }
  read -r OWNER_SLUG OWNER_PID OWNER_PANE < "$LOCK"
  [ "$OWNER_SLUG" = "$SLUG" ] && [ "$OWNER_PANE" = "$PANE" ] \
    || { echo "lock belongs to another child — nothing to resume" >&2; exit 3; }
  if [ -f "$ASKF" ] && [ -z "$SEND" ]; then
    STATUS=asking; EL=0; finish; exit 5
  fi
  if [ -n "$SEND" ]; then
    [ -f "$ASKF" ] || { echo "no pending question to answer" >&2; exit 3; }
    python3 "$SCRIPT_DIR/rpc-task.py" send "$SLUG" "$SEND" || exit 3
  else
    echo "resumed waiting on $SLUG"
  fi
else
  # --- fresh spawn: validate, reset scratch, claim the lock, create the pane ---
  [ -n "$WORKDIR" ] && [ -n "$BRIEF" ] || usage
  [ -d "$WORKDIR" ] || { echo "workdir does not exist: $WORKDIR" >&2; exit 3; }
  [ -f "$BRIEF" ] || { echo "brief file does not exist: $BRIEF" >&2; exit 3; }
  command -v tmux >/dev/null 2>&1 || { echo "tmux is not installed" >&2; exit 3; }
  command -v flock >/dev/null 2>&1 || { echo "flock is not installed" >&2; exit 3; }
  command -v python3 >/dev/null 2>&1 || { echo "python3 is not installed" >&2; exit 3; }
  command -v "${PIBIN:-pi}" >/dev/null 2>&1 || { echo "pi is not on PATH (or --pi-bin is invalid)" >&2; exit 3; }
  # model / pi-bin are typed into the pane's shell: no quoting there, so keep them tame.
  if [ -n "$MODEL" ] && ! [[ "$MODEL" =~ ^[A-Za-z0-9._:/-]+$ ]]; then
    echo "model must match [A-Za-z0-9._:/-]+ (got: $MODEL)" >&2; exit 3
  fi
  if [ -n "$PIBIN" ] && ! [[ "$PIBIN" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
    echo "--pi-bin must be an absolute path (got: $PIBIN)" >&2; exit 3
  fi

  # Claim the single-child lock before touching scratch. The guard serializes
  # concurrent spawns and the wrapper's ownership handoff/release.
  mkdir -p /tmp/pi-tasks
  lock_guard
  if lock_is_live; then
    echo "another child is already running (lock: $(cat "$LOCK" 2>/dev/null)) — wait for it, or remove $LOCK if you are sure" >&2
    unlock_guard
    exit 3
  fi
  echo "$SLUG $$ pending" > "$LOCK"
  unlock_guard
  trap 'release_lock_if_owned "$$"' EXIT

  rm -rf "$SCRATCH"
  mkdir -p "$SCRATCH"
  cp "$BRIEF" "$SCRATCH/brief.md"
  echo "$WORKDIR" > "$SCRATCH/.workdir"

  # --- create the pane (or session) ---
  if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
    if [ "$WINDOW" = 1 ]; then
      read -r WIN PANE <<< "$(tmux new-window -t "$TMUX" -c "$WORKDIR" -P -F '#{window_id} #{pane_id}')" \
        || { echo "could not open a new tmux window" >&2; exit 3; }
      CREATED=window
    else
      read -r WIN PANE <<< "$(tmux split-window -t "$TMUX_PANE" -c "$WORKDIR" -P -F '#{window_id} #{pane_id}')" \
        || { echo "could not split the pane (window too small?) — retry with --window" >&2; exit 3; }
      tmux resize-pane -t "$PANE" -p 50 2>/dev/null || true
      CREATED=pane
    fi
    echo "task: $SLUG  pane: $PANE  created: $CREATED  workdir: $WORKDIR  timeout: ${TIMEOUT}s"
  else
    SESS="pi-task-$SLUG"
    if tmux has-session -t "$SESS" 2>/dev/null; then
      echo "tmux session $SESS already exists — pick another slug" >&2; exit 3
    fi
    tmux new-session -d -s "$SESS" -c "$WORKDIR" || { echo "could not create tmux session" >&2; exit 3; }
    read -r WIN PANE <<< "$(tmux list-panes -t "$SESS" -F '#{window_id} #{pane_id}')"
    CREATED=session
    echo "task: $SLUG  session: $SESS  pane: $PANE  workdir: $WORKDIR  timeout: ${TIMEOUT}s"
    echo "watch the task:  tmux attach -t $SESS"
  fi

  lock_guard
  echo "$SLUG $$ $PANE" > "$LOCK"
  unlock_guard
  echo "$PANE" > "$SCRATCH/pane.id"
  printf 'CREATED=%s\nSESS=%s\n' "$CREATED" "${SESS:-}" > "$SCRATCH/.meta"

  # --- launch the pane wrapper (interactive pi inside) ---
  LAUNCH="bash $SCRIPT_DIR/pane-run.sh $SLUG"
  if [ -n "$MODEL" ]; then LAUNCH="$LAUNCH --model $MODEL"; fi
  if [ -n "$PIBIN" ]; then LAUNCH="$LAUNCH --pi-bin $PIBIN"; fi
  tmux send-keys -t "$PANE" "$LAUNCH" Enter

  # --- wait for the wrapper to come up (or an early failure), up to 30s ---
  START=$(date +%s)
  STATUS=""
  STATUSF_CONTENT=""
  STARTED=0
  EARLY=0
  for _ in $(seq 1 30); do
    if [ -f "$MARKER" ] || [ -f "$BLOCKEDF" ]; then STARTED=1; break; fi
    if [ -f "$STATUSF" ]; then EARLY=1; break; fi
    if [ -f "$SCRATCH/pane.pid" ]; then
      WPID=$(cat "$SCRATCH/pane.pid" 2>/dev/null || true)
      if [ -n "$WPID" ] && kill -0 "$WPID" 2>/dev/null; then STARTED=1; break; fi
    fi
    if ! tmux list-panes -t "$PANE" >/dev/null 2>&1; then
      echo "pane died before the task started" >&2
      exit 2
    fi
    sleep 1
  done
  if [ "$EARLY" = 1 ]; then
    # pi failed to start or exited instantly — the wrapper recorded why
    STATUS=exited
    STATUSF_CONTENT=$(cat "$STATUSF" 2>/dev/null || true)
    EL=$(( $(date +%s) - START ))
    finish
    exit 2
  fi
  if [ "$STARTED" != 1 ]; then
    echo "pane-run did not start within 30s (pane: $PANE)" >&2
    tmux kill-pane -t "$PANE" 2>/dev/null || true
    [ "$CREATED" = session ] && tmux kill-session -t "$SESS" 2>/dev/null || true
    exit 2
  fi
fi

# --- wait loop: pure bash, zero inference (a single local model stays safe) ---
START=$(date +%s)
LAST_BEAT=-55
PREV_HASH=""
LAST_CHANGE=$START
while :; do
  if [ -f "$MARKER" ]; then STATUS=done; break; fi
  if [ -f "$BLOCKEDF" ]; then STATUS=blocked; break; fi
  if [ -f "$STATUSF" ]; then
    case "$(head -1 "$STATUSF" 2>/dev/null || true)" in
      blocked) STATUS=blocked;;
      *) STATUS=exited;;
    esac
    STATUSF_CONTENT=$(cat "$STATUSF" 2>/dev/null || true)
    break
  fi
  if [ -f "$ASKF" ]; then STATUS=asking; break; fi
  if ! tmux list-panes -t "$PANE" >/dev/null 2>&1; then STATUS=exited; break; fi
  NOW=$(date +%s); EL=$((NOW - START))
  if [ "$EL" -ge "$TIMEOUT" ]; then STATUS=timeout; break; fi

  capture_tail
  H=$(cksum < "$SCRATCH/tail.txt" 2>/dev/null | awk '{print $1}')
  if [ "$H" != "$PREV_HASH" ]; then LAST_CHANGE=$NOW; PREV_HASH=$H; fi

  if [ $((EL - LAST_BEAT)) -ge 60 ]; then
    msg="still running: $SLUG (${EL}s)"
    STALE=$((NOW - LAST_CHANGE))
    if [ "$STALE" -ge 120 ]; then msg="$msg — no pane change for ${STALE}s (possible stall)"; fi
    echo "$msg"
    LAST_BEAT=$EL
  fi
  sleep 5
done
EL=$(( $(date +%s) - START ))
finish
case "$STATUS" in
  done) exit 0;;
  timeout) exit 1;;
  exited) exit 2;;
  blocked) exit 4;;
  asking) exit 5;;
esac
