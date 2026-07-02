---
name: skills-readme
description: Index of available coding agent skills for code review, simplification, PR drafting, frontend design, PR comments, and task planning.
disable-model-invocation: true
---

# Agent Skills

A collection of skills for coding agents — works with Pi, Codex, Claude Code, and others.

## Skills

| Skill | Description | Requires |
|-------|-------------|----------|
| [code-review](code-review/) | Reviews code changes from a GitHub PR or current git branch. Reports findings ranked by severity with an overall verdict. | git; `gh` for PR mode |
| [code-simplify](code-simplify/) | Simplifies and refactors code while preserving behavior. Reduces complexity, eliminates redundancy, and improves readability. | git |
| [draft-pr](draft-pr/) | Drafts clear, jargon-free PR descriptions from the current branch's commits and diffs. Auto-detects feature, bug fix, or documentation changes. | git; `gh` for creating PRs |
| [frontend-design](frontend-design/) | Creates distinctive, production-grade frontend interfaces with high design quality. Avoids generic AI aesthetics. | none |
| [pr-comments](pr-comments/) | Fetches and presents comments from a GitHub PR, organized by file for easy analysis and action planning. | `gh` |
| [task-planner](task-planner/) | Creates structured `plan.md` files for complex multi-session tasks. Investigates the codebase, resolves ambiguities, and produces actionable phase-by-phase plans. | git |

## Workflow Examples

- **Before merging**: `pr-comments` → `code-review` → address findings with `code-simplify`
- **New feature**: `task-planner` → implement → `code-review` → `draft-pr`
- **UI work**: `frontend-design` → `code-review` → `draft-pr`
