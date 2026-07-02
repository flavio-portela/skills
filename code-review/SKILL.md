---
name: code-review
description: Reviews code changes from a GitHub PR or current git branch. Reports findings ranked by severity with an overall verdict. Use when asked to review a PR, review code, or review branch changes.
compatibility: "Requires git. PR mode requires GitHub CLI (gh) installed and authenticated."
---

# Code Review

Reviews code changes and reports findings ranked by severity with an overall verdict.

## Modes

Detect which mode to use based on the user's request:

### PR Mode

When the user mentions a PR number or asks to "review the PR":

1. **Verify prerequisites**:
   ```bash
   gh auth status
   ```
   If authentication fails, ask the user to log in with `gh auth login`.

2. **Get the PR number**:
   - Explicit number (e.g., "review PR #42") → use that number
   - No number given (e.g., "review the PR") → auto-detect from current branch:
     ```bash
     gh pr view --json number --jq '.number'
     ```
     If this returns `null` or fails, the branch has no open PR. Fall back to Branch Mode or ask the user.
     Note: `gh pr view` works for PRs in the same repo. For fork-based PRs, it may require `--repo <owner/repo>`.

3. **Fetch PR context**:
   ```bash
   gh pr view <NUMBER> --json title,body,labels,baseRefName,headRefName
   ```

4. **Fetch the diff**:
   ```bash
   gh pr diff <NUMBER>
   ```

5. **Use PR title and description** to understand the author's intent — this frames what the review should focus on.

6. **Check labels** — labels like `security`, `breaking-change`, or `performance` should tune the review focus accordingly.

### Branch Mode

When the user asks to review their branch, current changes, or when PR Mode auto-detection fails:

1. **Determine the base branch** — default is `main`. User can specify a different base (e.g., "review against develop").

2. **Fetch the diff**:
   ```bash
   git diff <base>...HEAD
   ```

## Review Scope

- **Default**: Review only the diff lines (added/removed).
- **When context is needed**: If a finding involves surrounding code, read the full file for that specific area. This is at your judgment — don't read every full file upfront, only when the diff alone is insufficient to assess a finding.

## Thoroughness Level

- **Default**: Review for 🔴 Must-Fix and 🟡 Should-Fix findings only.
- **`--thorough`** (or when the user asks for a thorough/detailed review): Also include 🔵 Suggestions and 💡 Nits.

If the user asks to "review nits too" or "include suggestions", treat that as `--thorough`.

## Running the Review

1. Fetch the diff (per mode above).
2. Read the full checklist in `references/checklist.md` — apply every applicable check.
3. Also check for project conventions if available:
   - Read `CLAUDE.md` or `AGENTS.md` in the project root for project-specific rules.
   - If `eslint`, `prettier`, or `.editorconfig` configs exist, factor those into 🔵 B2 (Consistency) and 💡 N1 (Style) checks.
4. For each finding, note:
   - **Severity + checklist code** (e.g., 🔴 M2, 🟡 S3)
   - **File and approximate line number**
   - **What's wrong**
   - **Suggested fix** (code snippet or clear description)
5. Produce the output and verdict.

## Output Format

```
## Code Review: <"PR #N — Title" or "Branch <name> vs <base>">

🔴 M2  path/to/file.ts:47
    SQL injection via string interpolation in INSERT query.
    Suggested fix: Use parameterized query.

🟡 S3  path/to/file.ts:82
    No handling for duplicate email — will throw unhandled DB error.
    Suggested fix: Catch unique constraint violation, return 409.

---
Verdict: Request Changes — 1 must-fix, 2 should-fix
```

### Verdict Rules

- **Approve** — zero must-fix and zero should-fix findings.
- **Request Changes** — one or more must-fix OR should-fix findings.
- **Comment** — only suggestions and/or nits (no must-fix or should-fix).

If all findings are 🔵 or 💡, the verdict is **Comment** with the count. If there are 🟡 or 🔴 findings, the verdict is **Request Changes** — never Approve while problems remain.

## Usage

- **"Review PR #42"** — PR Mode, specific number
- **"Review the PR"** — PR Mode, auto-detect from current branch
- **"Review my branch"** — Branch Mode against `main`
- **"Review against develop"** — Branch Mode against specified base
- **"Thorough review"** / **"Include nits"** — enables `--thorough` mode

## Notes

- **Related:** Use `pr-comments` to fetch existing review feedback before starting your review
- **Related:** Use `code-simplify` to fix findings after the review is complete

### If No Findings

```
## Code Review: <title>

No issues found.

---
Verdict: Approve
```