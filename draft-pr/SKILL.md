---
name: draft-pr
description: >
  Draft clear, jargon-free pull request descriptions from the current branch's commits and diffs.
  Automatically detects whether the PR is a feature, bug fix, or documentation change and applies
  the matching template. Use this skill whenever the user wants to write, draft, or generate a
  PR description, prepare a pull request, or asks "what should I put in this PR?" — even if they
  don't say "description" explicitly. Also use it when the user says /draft-pr.
compatibility: "Requires git. Creating PRs requires GitHub CLI (gh) installed and authenticated."
---

# Draft PR Description

You help write pull request descriptions that anyone on the team can understand — developers,
designers, PMs, whoever reviews PRs. The goal is clarity: someone reading the description should
quickly understand *what changed* and *why*, without needing to read the code.

## Step 1: Gather context

Run these git commands to understand the branch:

```bash
# Detect the base branch (upstream target)
BASE=$(git merge-base --fork-point HEAD 2>/dev/null || git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo 'main')
# What branch are we on?
git branch --show-current
git log --oneline "$BASE"..HEAD
git diff "$BASE"..HEAD --stat
git diff "$BASE"..HEAD
```

If there are very many changed files (more than ~15), focus on the `--stat` summary and the
most significant files rather than reading every line of diff.

Also check if there's an open issue or ticket number referenced in commit messages (look for
patterns like `#123`, `PROJ-456`, `fixes #`, `closes #`).

## Step 2: Classify the PR type

Based on the commits and changes, determine which type fits best:

- **Feature** — new functionality, new UI, new capability
- **Bug fix** — something was broken and now it works correctly
- **Documentation** — README updates, comments, guides, no behavior change
- **Mixed** — if commits span multiple types, use the Feature template but note the fixes

Signals to look for:
- Commit prefixes like `feat:`, `fix:`, `docs:` (conventional commits)
- New files → likely a feature
- Small, targeted changes to existing logic → likely a fix
- Only `.md` or comment changes → documentation

## Step 3: Write the description

Use the appropriate template below. Write in plain language — imagine explaining the change
to a smart colleague who hasn't seen the code. Avoid jargon like "refactor", "abstraction",
"middleware", "hydration", "polymorphism", etc. If a technical term is truly necessary, briefly
explain what it means.

### Feature template

```markdown
## Why this change

[1-3 sentences: why is this change being made? What problem does it solve or what need does it address?]

## How it works

[Brief, plain-language explanation of the approach. Focus on *behavior*, not implementation.
Use bullet points for multiple changes. Think "what will the user see/experience?" not
"what classes did I modify?"]

## What changed

[Bullet list of the key changes, grouped logically. Each bullet should make sense to someone
who doesn't write code. For example, instead of "Added `useVisibility` hook", say
"Added logic to show or hide form fields based on earlier answers".]

## How to test

[Step-by-step instructions someone can follow to verify the feature works.
Start from a clear starting point, e.g., "1. Open the form builder".]

## Notes

[Optional: anything reviewers should know — trade-offs, follow-up work, areas to look closely at.
Delete this section if there's nothing to add.]
```

### Bug fix template

```markdown
## Why this fix

[1-3 sentences: what was the problem that needed fixing? What did users experience?]

## What caused it

[Brief, plain-language explanation of why it was happening. No need to name specific
variables or functions — describe the *logic* that was off.]

## How it's fixed

[What the fix does, in behavior terms. "Now when X happens, Y works correctly" is better
than "Changed the conditional in handleSubmit".]

## How to test

[Steps to verify the fix. Ideally: how to reproduce the old bug, and what correct
behavior looks like now.]
```

### Documentation template

```markdown
## What's updated

[What documentation changed and why.]

## Key changes

[Bullet list of what was added, removed, or rewritten.]
```

## Step 4: Present and offer to create

Show the drafted description to the user. Then ask:

> "Here's the draft. Want me to adjust anything, or should I go ahead and create the PR with this?"

If the user says to go ahead:

1. **Verify `gh` is authenticated**:
   ```bash
   gh auth status
   ```
   If authentication fails, ask the user to log in with `gh auth login`.

2. Create the PR using `gh pr create` with the title and body.
   Pick a short, clear PR title (under 70 characters) in **conventional-commit format**: `type(scope): description` (e.g. `feat(chat): add message prefill support`, `fix(frontend): prevent crash on empty form`). Derive the type from the PR classification (feat, fix, docs, refactor, etc.) and scope from the primary area of change.

## Usage

- **"Draft a PR"** / **"Write a PR description"** — auto-detect branch and draft
- **"Create the PR"** — draft and immediately create via `gh pr create`
- **"/draft-pr"** — same as above

## Notes

- **Related:** Use `code-review` to review the changes before drafting the PR
- **Related:** Use `pr-comments` to incorporate reviewer feedback into the PR description

## Output Format

Present the drafted description as a markdown block, then ask:

> "Here's the draft. Want me to adjust anything, or should I go ahead and create the PR with this?"

## Writing guidelines

These apply across all templates:

- **Lead with impact, not implementation.** "Users can now filter by date" beats "Added DateFilter component".
- **Use active voice.** "The form now hides irrelevant fields" not "Irrelevant fields are hidden by the form".
- **Be specific.** "Fixed a crash when saving empty forms" is better than "Fixed a bug".
- **Keep it scannable.** Bullet points over paragraphs. Short sentences over long ones.
- **No filler.** Skip "This PR..." openings — just start with what matters.
- **Reference tickets if they exist.** If commits reference issue numbers, include them (e.g., "Closes #42").
