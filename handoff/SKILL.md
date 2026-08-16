---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up. Use when asked to hand off, write a handoff doc, summarize the session for a fresh agent, or prepare context for continuing work later.
---

# Handoff

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to the OS temporary directory (e.g. `$TMPDIR`/`/tmp`) — **not** the current workspace.

## Document Structure

1. **Goal** — what the overall task is and the intended outcome.
2. **Current State** — what has been done so far, what works, and where things stand right now (files changed, branches, PRs).
3. **Next Steps** — concrete, ordered actions the next agent should take to continue.
4. **Context & Decisions** — key decisions made and why, constraints discovered, gotchas the next agent must know.
5. **Suggested Skills** — name which skills the next agent should load (e.g. `task-planner`, `code-review`) and what to use each for.
6. **Open Questions** — anything unresolved that needs the user's input.

## Rules

- **Do not duplicate content already captured in other artifacts** (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.
- **Redact sensitive information** — API keys, passwords, tokens, and personally identifiable information must not appear in the document.
- **Tailor to the next session** — if the user passed arguments, treat them as a description of what the next session will focus on and shape the document accordingly (emphasize relevant next steps and context, drop what is not needed).
- **Be concise** — this is a pointer, not a transcript. A fresh agent should be able to start working from it without reading the original conversation.
