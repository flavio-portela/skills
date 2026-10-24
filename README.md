---
name: skills-readme
description: Index of available skills. Not a skill itself.
disable-model-invocation: true
---

# Agent Skills

A collection of skills for coding agents — works with Pi, Codex, Claude Code, and others.

## Skills

| Skill | Description |
|-------|-------------|
| [code-review](code-review/) | Reviews code changes from a GitHub PR or current branch. Reports findings ranked by severity with an overall verdict. |
| [code-simplify](code-simplify/) | Simplifies and refactors code while preserving behavior. Reduces complexity, eliminates redundancy, and improves readability. |
| [draft-pr](draft-pr/) | Drafts clear, jargon-free PR descriptions from the current branch's commits and diffs. Auto-detects feature, bug fix, or documentation changes. |
| [frontend-design](frontend-design/) | Creates distinctive, production-grade frontend interfaces with high design quality. Avoids generic AI aesthetics. |
| [pr-comments](pr-comments/) | Fetches and presents comments from a GitHub PR, organized by file for easy analysis. |
| [skill-creator](skill-creator/) | Creates and improves skills through drafting, test prompts, feedback, and iteration. |
| [task-planner](task-planner/) | Creates and manages plan directories for complex multi-session tasks, with an index and a self-contained brief for each phase. |
| [subagent-task](subagent-task/) | Delegates work to an isolated Pi subagent with live progress in the current session; a tmux pane is optional. |
| [user-perspective](user-perspective/) | Brainstorms features from the product's target user's perspective, grounded in their workflow and pain points. |

## Claude Code

Run `./sync-claude-code.sh` to symlink these skills into `~/.claude/skills`. It leaves existing non-matching entries alone and removes stale links it created when a source skill no longer exists.
