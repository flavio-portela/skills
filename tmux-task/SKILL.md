---
name: tmux-task
description: Run a Pi task in a visible tmux pane as a separate child agent session, block until it finishes, then report. Use whenever the user wants a task run "in a pane", "in a separate session", "in the background", "while I can watch it", or wants a sub-agent to execute a plan phase (e.g. "execute phase 2 in a pane", "run this and tell me when it's done") — even if they never mention tmux. Handles pane/session detection, the brief protocol, completion marker, timeout, and pane cleanup.
---

# Tmux Task

Spawn a separate, visible `pi` session in tmux to run a self-contained task, block in a pure-bash wait until it finishes, then report. The user watches the child's full TUI live — reasoning, tool calls — and can intervene at any time (send a message, `Escape` to stop).

## Why this pattern

- A child session has a clean context for self-contained work (plan phases, big refactors) without polluting the current session's context.
- The orchestrator blocks in a bash-only wait loop: **zero LLM calls while waiting**. With a locally-hosted model (one concurrent instance), this guarantees only the child is inferring. Never run two children at once.
- The child runs as interactive `pi` (never `pi -p` / print mode): the user sees everything and can steer it mid-run.

## Workflow

1. **Write the brief** — one self-contained markdown file (protocol below). Save it anywhere stable, e.g. `/tmp/pi-briefs/<slug>.md`.
2. **Run the spawner** as one blocking bash call. Set the bash timeout to the script timeout plus a margin:

   ```bash
   bash <skill-dir>/scripts/spawn.sh <slug> <workdir> <brief-file> [--timeout SECONDS] [--window] [--model MODEL]
   ```

   - `<slug>`: lowercase alphanumerics + hyphens (e.g. `phase-2-sizing`).
   - Inside a tmux session: new pane in the current window (default), or a new window with `--window`. Outside tmux: a new detached session — the script prints the `tmux attach -t ...` command; give it to the user.
   - `--timeout` seconds (default 1800). `--model` passes through to pi (omit for the user's default).
   - Exit codes: `0` done · `1` timeout (pane left open) · `2` child exited early · `3` setup error (includes: another child already running).
3. **Report to the user**: status, elapsed time, the child's closing report (read `<scratch>/tail.txt`), what you verified, and the log paths. Verify the child's claims yourself (build/test/git) before declaring success — the child's word is not proof.
4. **Multi-step plans** (e.g. phases 2→6): loop — spawn one phase, verify its bookkeeping (checkboxes ticked, status row updated, build green), then spawn the next. Sequential, never overlapping.

## Brief protocol

The child knows nothing except its brief. Self-contained, one job, ≤ ~40 lines:

```markdown
You are executing <task>. Working directory: <workdir>

1. <concrete steps — name files, commands, expected results; no "as discussed">
2. ...
N-1. Verification: <commands/checks that prove the work is correct>
N. As your very last action, run exactly: echo done > /tmp/pi-tasks/<slug>/done
   Then end with a 3–6 line report: what you did, verification result, files touched, any deviations.
```

Rules:

- The marker line (`echo done > /tmp/pi-tasks/<slug>/done`) is **mandatory and last** — the spawner refuses a brief without it and uses the file to detect completion.
- When the task is part of a larger plan, say "Do NOT do work from other phases" and include the bookkeeping (tick the phase checkboxes, update the plan index status row, commit).
- The child starts with `pi --approve` (project-local files are trusted for that run) — fine for your own repos; mention it in the brief if it matters.
- Keep verification explicit and command-level — the child will run it and you will re-run it.

## Single local model rules

- One child at a time. The spawner holds a lock (`/tmp/pi-tasks/.active`) and refuses a second child; if it reports "another child is already running", show the user the lock contents and wait.
- While the child runs, this session does bash-only work (the wait). Don't start other LLM-heavy work in it in the meantime.
- On timeout the pane is **left open**: tell the user the task may still be running, give the pane/attach info, and do not spawn another child until it's confirmed finished. The lock is released, so a second spawn is possible — deliberately avoid it.

## Failure handling

- **Exit 2 (exited early)**: read `<scratch>/tail.txt` to distinguish crash / user-quit / pi-exit. Report what the tail shows; do not silently retry. If the user deliberately quit, treat it as cancelled.
- **Exit 1 (timeout)**: as above — report, leave the pane, suggest `cd <workdir> && pi -r` to resume the child's saved session (or re-run the spawner with a longer timeout after confirming it's dead).
- **The child's full transcript always survives**: pi saves sessions; `cd <workdir> && pi -r` resumes.
- Scratch lives in `/tmp/pi-tasks/<slug>/` (`brief.md`, `tail.txt`, `done`). Clean it up when the task is fully reported and no longer needed.
