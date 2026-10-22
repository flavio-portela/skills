---
name: tmux-task
description: Delegate self-contained, substantial work to a Pi child agent in a visible tmux pane, keeping the orchestrator's context lean; the parent waits and verifies the result. Use for token-intensive tasks such as codebase research, code review, or executing a plan phase, even when the user does not ask for a sub-agent. Also use when the user asks for work in a pane, separate session, or background, or wants to watch it live. Supports questions, timeouts, and pane cleanup.
---

# Tmux Task

Run a Pi child through RPC in a tmux pane. A small controller displays the child's streaming text, thinking (when available), and tool activity in the pane; it also saves the full RPC stream to `/tmp/pi-tasks/<slug>/events.jsonl`. The parent blocks in a bash-only wait, so a single local model never runs two agents at once. This is an activity viewer, not Pi's native TUI; answer questions through `--resume --send`, not by typing into the pane. Requires `tmux`, `flock`, and Python 3.

## When to delegate

Use this skill when a substantial, self-contained task would consume significant orchestrator context but can be summarized in a brief and returned as a concise, verifiable report. Examples include exploring a codebase to answer a question, reviewing a large change, and implementing a plan phase. Explicit requests for a sub-agent or visible/separate execution also trigger it. The pane provides visibility; preserving the parent's context is the main reason to delegate. "Background" here means a separate child process, not that the parent continues working concurrently.

Do the work directly when it is small, needs frequent decisions from the user, or requires the orchestrator to retain the full intermediate reasoning. Delegate one bounded job at a time and independently verify the child's conclusions before reporting them.

## Workflow

1. Write a self-contained brief (see below) to a stable file, e.g. `/tmp/pi-briefs/<slug>.md`.
2. Run the spawner as one blocking bash call. Allow its timeout plus a margin for the bash tool:

   ```bash
   bash <skill-dir>/scripts/spawn.sh <slug> <workdir> <brief-file> [--timeout SECONDS] [--window] [--model MODEL] [--pi-bin PATH]
   bash <skill-dir>/scripts/spawn.sh --resume <slug> [--send ANSWER] [--timeout SECONDS]
   ```

   - `<slug>`: lowercase alphanumerics and hyphens. `--timeout`: positive seconds (default 1800). `--model` selects the child's model; `--pi-bin` selects an absolute Pi binary path.
   - Inside tmux, the viewer starts in a split pane (or a window with `--window`). Outside tmux, it starts in a detached session; give the user the printed `tmux attach` command.
   - The pane shows streaming assistant text, thinking when emitted, and tool starts/finishes. Scratch contains `activity.log` (readable), `events.jsonl` (raw RPC responses and events), `view.json` (small live status snapshot), and `stderr.log` (Pi diagnostics). These logs are temporary; do not copy them elsewhere unless asked.
   - In the orchestrator's Pi TUI, `~/.pi/agent/extensions/tmux-task-status.ts` displays the active child's latest action and context usage below the editor (reload Pi after installing it). Usage comes from RPC `get_session_stats` after turns; before the first measurement or just after compaction it may be unavailable. The pane remains the detailed view.
   - Exit codes: `0` done, `1` timeout (child/pane left running), `2` exited early, `3` setup error (including another child running), `4` blocked, `5` question pending (child/pane left running). The spawner prints a heartbeat every ~60s.
3. Read `<scratch>/report.txt` on done or blocked. Verify the child's claims yourself (build/test/git) before declaring success; do not treat its `task_report` as proof. Report status, elapsed time, verification, report and log paths. The saved Pi session is also copied to `<scratch>/transcript.jsonl` when available.
4. For multi-step plans, spawn one phase at a time. Verify its bookkeeping and build before the next phase. Never overlap children.

## Brief protocol

The child receives the brief plus instructions to use the `task_report` tool. The controller loads that tool only in the child process. Write one self-contained job, ideally ≤ ~40 lines:

```markdown
You are executing <task>. Working directory: <workdir>.

1. <concrete steps; name files, commands, expected results; no "as discussed">
2. ...
3. Verification: <commands/checks that prove the work is correct>
4. If a decision is needed, use task_report with status="question" and the question
   as message. End your turn; the answer arrives in your next user message.
5. If you cannot proceed and an answer would not help, use task_report with
   status="blocked", a concise reason as message, and details in report.
6. When verified, use task_report with status="done", a one-line summary as
   message, and the full result (verification, files touched, deviations) in report.
   task_report must be your last tool action. Then end your turn.
```

No shell markers or literal `echo` commands are needed. The controller accepts a task outcome only after Pi emits `agent_settled`, so the report is complete before the orchestrator wakes. If the child stops without calling `task_report`, that is an early exit, **not** success. The report is still a claim; verify it independently.

## Questions and recovery

1. When the child reports a question, the spawner exits 5, prints the question, and leaves the viewer and Pi RPC process running. The controller assigns the question a unique ID.
2. Decide on an answer, then run `bash <skill-dir>/scripts/spawn.sh --resume <slug> --send '<answer>'`. The controller validates the question ID, submits the answer as a Pi RPC `prompt`, waits for Pi to accept it, and only then clears the pending question. Answers can contain newlines; quote them for your shell.
3. If you do not have an answer, ask the user and stop. `--resume <slug>` without `--send` reprints a pending question; after a timeout with no question, it resumes waiting. Repeat for later questions.

Do not send tmux keystrokes to the viewer; it is not the child's input. On timeout, the pane and single-child lock stay active; `--resume` can re-wait. If the child has died, read `<scratch>/activity.log`, `stderr.log`, and `tail.txt` before deciding what to do. Killing the pane is a manual override. If blocked, the pane closes and the reason and report stay in scratch; ask the user before re-spawning. Reusing a slug resets that task's scratch files **only after** the previous child has stopped.

## Single local model

The spawner and pane-side wrapper transfer ownership of `/tmp/pi-tasks/.active` under a `flock` guard. One live child is allowed, including while waiting for an answer or after a parent timeout. The orchestrator waits with bash only: no competing inference while the child runs. A dead owner is treated as stale at the next spawn.

Clean `/tmp/pi-tasks/<slug>/` up when the task has been fully reported and its logs are no longer needed.
