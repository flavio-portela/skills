---
name: task-planner
description: Creates and manages structured plan.md files for complex multi-session coding tasks. Investigates the codebase first, resolves ambiguities with the user, then produces a detailed plan where each phase is a self-contained brief for a separate agent session.
---

# Task Planner

Manages `plans/plan-<name>.md` files for complex, multi-session coding tasks. Each plan is designed so that **every phase can be executed by a fresh agent session** with no prior context — all necessary details must be baked into the phase brief.

## Core Principle

**Investigation happens before the plan, not inside it.** The agent must thoroughly explore the codebase and understand the current state before writing the plan. This ensures:

- No phase is named "Investigation and design" — that work is done upfront
- Each phase is actionable and specific, with all file paths, patterns, and context included
- A fresh agent session can pick up any phase and execute it independently

**Ambiguities are resolved with the user before the plan is written.** The agent never guesses — when multiple valid approaches exist or requirements are unclear, it presents options to the user and waits for a decision. The final plan contains only resolved, concrete choices.

## When to Skip This Skill

Simple, single-session tasks don't need a plan. Use your judgement — skip this skill when:

- **Bug fixes** with a clear root cause and fix
- **Small refactors** in a single file or module
- **Adding one feature** with a straightforward implementation path
- **Documentation updates** or minor config changes

Use this skill when the task:
- Spans **multiple agent sessions**
- Has **significant architectural decisions** to make
- Touches **many files or modules**
- Has **dependencies between changes** that must be ordered correctly

## Plan Creation Workflow

When creating a plan, follow this sequence:

### Step 1: Understand the Request

Clarify the task with the user. Ask:
- What is the end goal?
- What parts of the codebase are affected?
- Any constraints (tech stack, style, deadlines, incompatibilities)?

### Step 2: Investigate the Codebase

**Do this before writing anything.** Thoroughly explore:
- **Architecture**: overall project structure, module boundaries, entry points
- **Relevant files**: every file that will be touched or needs to be understood — read them fully
- **Current state**: what exists already, what's missing, what's half-done
- **Patterns & conventions**: naming, code style, testing patterns, error handling
- **Dependencies**: what imports/relies on what; impact radius of changes
- **Tests**: existing test structure, coverage, and how new changes should be tested

While investigating, **collect any ambiguities** — places where:
- Multiple valid implementation approaches exist
- The user's intent is unclear or underspecified
- Existing code patterns conflict or are inconsistent
- A design choice will meaningfully affect multiple phases

### Step 3: Present Open Decisions (If Any)

If Step 2 revealed ambiguities, present them to the user **before writing the plan** using the `questionnaire` tool. For each decision, create a question:

```json
{
  "id": "<short-id>",
  "label": "<short title for tab bar>",
  "prompt": "<context: why this matters, what it affects, your recommendation>",
  "options": [
    { "value": "a", "label": "<option A>", "description": "<pros / cons>" },
    { "value": "b", "label": "<option B>", "description": "<pros / cons>" }
  ],
  "allowOther": true
}
```

**Rules for this step:**

- Always include a **recommendation** in the prompt text — don't just dump choices on the user
- Ground options in the codebase (e.g. "Option A matches the pattern already used in `src/auth/middleware.ts`")
- Set `allowOther: true` so the user can type a custom answer or ask for more discussion
- If there's only one reasonable path, skip this step — don't manufacture decisions
- Wait for the user's response before proceeding. They can accept the recommendation, pick another option, or write something entirely different
- If there are no ambiguities, skip this step and go straight to Step 4

Only after this investigation (and any user decisions) is complete should you start drafting the plan.

### Step 4: Design the Phases

Break the work into sequential phases. For each phase:
- It must be a **concrete implementation step**, not a research step
- It must be **self-contained**: a new agent session reading only this phase brief should be able to execute it
- Include all required context: file paths, current code state, what to change, how to change it, and why
- **All decisions from Step 3 must be resolved** — no placeholders, no "TBD", no "decide later"
- If a plan exceeds **~8 phases**, consider splitting into multiple plans (e.g., "Part A" and "Part B"). This keeps each plan digestible for a single agent session.

### Step 4.5: Review with the User

Before writing the final plan file, present the phase outline to the user:
- List each phase title and goal
- Confirm the scope, ordering, and approach
- Ask if anything needs adjustment

**Wait for the user's go-ahead** before proceeding to Step 5. This catches scope mismatches early — before the plan is committed to a file.

### Step 5: Write the Plan

Use the structure below.

**Never execute the plan after creating it.** The skill produces a plan file only. Execution happens later, on demand, when the user explicitly asks (e.g., "execute Phase 1" or "run the plan").

## Plan Structure

```markdown
# Plan: <name>

## Overview
<task summary and goals — what we're building/changing and why>

## Design Decisions
<resolved decisions that shaped the plan — what was chosen and why.
This gives a fresh agent the rationale behind architectural choices>

## Codebase Context
<key findings from investigation — architecture overview, relevant directories,
conventions, dependencies. Anything a fresh agent needs to know across all phases>

<include a mini file tree for spatial orientation, e.g.:
    src/
    ├── routes/       ← Phase 1 & 2
    ├── middleware/   ← Phase 1
    └── services/     ← Phase 3>

---

## Phase 1: <imperative verb, e.g., "Add authentication middleware">
### Goal
<what this phase achieves>

### Effort
<small / medium / large — rough estimate to help the user prioritize>

### Context
<everything needed to execute: file paths, current state, relevant code snippets,
patterns to follow, gotchas>

### Tasks
- [ ] <specific, actionable task>
- [ ] <specific, actionable task>

### Verification
<how to verify this phase is done correctly — commands to run, manual checks>

### Rollback
<if this phase makes irreversible changes (migrations, public API additions, data changes),
describe how to undo them. Omit if the phase is safely reversible.>

---

## Phase 2: <title>
### Goal
...

### Context
...

### Tasks
...

### Verification
...

---

## Dependencies
- Phase 2 depends on Phase 1
- Phase 3 depends on Phase 2
```

## Usage

Invocation patterns (prompt-based, not scripts):

```
/skill:task-planner create <name>    Create new plan (investigates first, asks questions, then writes)
/skill:task-planner list             List all plans in current project
/skill:task-planner view <name>      Display a specific plan
/skill:task-planner update <name>    Re-investigate and update an existing plan
/skill:task-planner delete <name>    Delete a plan
```

If called without subcommand, defaults to `create`.

## Anti-patterns to Avoid

| ❌ Bad | ✅ Good |
|---|---|
| Phase 1: "Investigate and design the API" | Investigation happens during plan creation; Phase 1 is "Implement API endpoints" |
| Phase task: "Refactor the module" | Phase task: "Extract `validateInput()` from `handlers.ts` into `validators.ts`, update all 4 call sites" |
| Vague context: "Look at the src folder" | Specific context: "Main entry is `src/index.ts`, routes are in `src/routes/`, auth middleware in `src/middleware/auth.ts`" |
| No verification step | "Run `npm test` and `npm run lint`, confirm all pass; manually test `POST /api/users` returns 201" |
| Creating a plan and then executing it immediately | Plan creation is a separate step from execution; the plan is written for a future agent session to consume |
| Passing execution commands from the parent session into phase tasks | Each phase must be fully self-contained — a fresh agent reading only that phase brief must have everything it needs |
| Guessing when the approach is unclear | Use `questionnaire` tool with options and a recommendation, wait for the user to decide |
| A plan containing "TBD" or "decide later" | All decisions are resolved before the plan is written; rationale is captured in the Design Decisions section |
| Presenting choices without context | "Option A matches the pattern in `src/auth/middleware.ts`" — ground options in the actual codebase |
| Presenting decisions as markdown text | Use `questionnaire` tool for interactive tabbed questions with an "Other" option |


## Notes

- Plans are stored in `plans/` directory (created if missing)
- File naming: `plan-<name>.md` (lowercased, spaces → hyphens)
- If plan name already exists, prompts to overwrite or cancel
- When updating a plan, re-investigate the current codebase state — things may have changed since the plan was created
- The **Design Decisions** section in the plan captures *why* choices were made, so a fresh agent executing phases later understands the rationale
- **Mid-plan updates:** If phases have already been executed, an update should preserve completed phases and only re-plan the remaining work. Re-investigate to account for any new context from completed phases.
- **Plan splitting:** If a plan exceeds ~8 phases, split it into multiple plans (e.g., `plan-backend.md` and `plan-frontend.md`) to keep each one digestible.