---
name: subagent-task
description: Delegate substantial, self-contained work to an isolated Pi subagent displayed inside the current Pi session. Use for codebase research, reviews, implementation phases, or when the user asks for a subagent; the parent waits, then verifies the result. One child per parent session; different sessions may delegate concurrently. No tmux pane is required.
---

# Delegated task (in-session)

Use the `delegate_task` extension tool to run a Pi child with its **own context window**. Progress appears in the parent's live tool card (no duplicate widget below the editor); expand it with Ctrl+O for recent activity, report, and log path. The child's conversation does not enter the parent's history. The extension uses the existing RPC controller and `task_report` protocol, not a tmux pane. Each parent Pi session has its own one-child lock; other sessions may run children concurrently. It saves an activity log, event stream, report, and separate Pi session under `/tmp/pi-tasks/<slug>/`.

## When to delegate

Delegate a bounded job that would consume substantial parent context but can be summarized in a verifiable report: exploring a codebase, reviewing a large change, or implementing a plan phase. Use it for explicit subagent requests. Work directly when the task is small, requires frequent user decisions, or needs the parent to keep the intermediate reasoning. Run one child at a time **per parent session**; tool calls block that parent while its child works. Other sessions can run children concurrently, though they may compete for the same model server. For an explicitly requested tmux pane/window, use `scripts/spawn.sh` as before; that legacy pane workflow still serializes pane tasks separately.

## Workflow

1. Give `delegate_task` a self-contained `brief` (ideally ≤ 40 lines) with steps, workdir, concrete success criteria, and verification. The child runs in the parent's working directory and inherits its model. No temporary brief file or tmux session is needed.
2. The in-transcript tool card updates with elapsed time, current action, recent output, and context usage when available. Ctrl+O expands the recent activity and final report. Ctrl+C cancels the tool and its child. Do not dispatch another child in the same session while one is running or awaiting an answer.
3. On `done` or `blocked`, read the returned report; verify claims yourself (tests/diff/build). A `task_report` is a claim, not proof. Summarize the outcome, verification, and any remaining issue. For a multi-phase plan, finish and verify one phase before starting the next.
4. If the child asks a question, decide on an answer or ask the user and **stop**. After receiving the answer, call `delegate_task` with the returned `slug` and `answer`. You can call with `slug` alone to wait again after a timeout. Never start a new child to answer a question.
5. On timeout, the child is still running: resume waiting with `slug`. On error, consult the returned activity and event paths before retrying. Clean the scratch directory when its report and logs are no longer needed.

## Brief protocol

The controller instructs the child to call `task_report` once as its last tool action. Include this in the brief for clarity:

```markdown
You are executing <task>. Working directory: <workdir>.
1. <concrete steps; relevant files; expected results>
2. Verification: <checks that prove the work is correct>
3. If you need a decision, call task_report with status="question" and your question
   as message. Stop; the answer arrives in your next user message.
4. If you cannot proceed, call task_report with status="blocked", reason as message,
   and details in report.
5. When verified, call task_report with status="done", a short summary as message,
   and full result (checks, files touched, deviations) in report. This must be your
   last tool action. Then end your turn.
```

The controller only accepts an outcome after `agent_settled`. If the child stops without a successful `task_report`, that is an error, not success. Questions leave the child alive with its context intact. Session shutdown or abort terminates children owned by the current extension; logs remain in scratch for diagnosis. The old pane workflow remains available through `scripts/spawn.sh` for explicit requests for tmux visibility.
