---
name: pr-comments
description: Fetches and presents comments from a GitHub pull request. Use when asked to pull, get, or review PR comments. Organizes review comments by file for easy analysis and action planning.
compatibility: "Requires GitHub CLI (gh) installed and authenticated. Repository must be on GitHub."
---

# PR Comments

Fetches all comments from a GitHub pull request and presents them in a structured, file-organized format for analysis and action planning.

## Prerequisites

Verify before proceeding:
```bash
gh auth status
```
If authentication fails, ask the user to log in with `gh auth login`.

## Identifying the PR

1. If the user provides a PR number (e.g. "pull comments for #42"), use that number.
2. If the user provides a full URL, extract the owner, repo, and PR number from it.
3. If the user says "pull the PR comments" without specifying, auto-detect from the current branch:
   ```bash
   gh pr view --json number --jq '.number'
   ```
   If this fails, ask the user for the PR number or URL.

## Fetching Comments

There are 3 types of PR comments. Fetch all of them using these commands:

### 1. Review Comments (inline comments on code)

These are the most valuable — they point to specific lines in specific files.

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate | jq -s 'add'
```

### 2. Issue Comments (top-level conversation comments)

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate | jq -s 'add'
```

### 3. Review Summaries (submitted review bodies)

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate | jq -s 'add'
```

For owner/repo, auto-detect from the current repo:
```bash
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
```

Or extract from `git remote get-url origin`.

## Thread Reconstruction

Group replies under their parent comments. For review comments:
- Comments with `in_reply_to_id: null` are top-level.
- Comments with `in_reply_to_id` set are replies — group them under their parent.

For issue comments:
- Use `reactions` or fetch replies separately if needed.

## Presenting Comments

Present the output organized by file, in this structure:

### Review Comments (by file)

For each file that has review comments, create a section:

```markdown
## 📄 path/to/file.ts

### Thread 1 (Line 42) — @author · 2024-01-15

> The original comment text here

**Reply by @reviewer2:** The reply text here

**Reply by @reviewer3:** Another reply

---
```

Group all threads for a file together. Within each thread, show the top-level comment as a blockquote, then list replies chronologically.

### Issue Comments

After the review comments, present top-level conversation comments:

```markdown
## 💬 Conversation

### @author · 2024-01-15

Comment text here

---
```

### Review Summaries

If any reviews have body text, include them:

```markdown
## 📋 Review Summaries

### @reviewer · Approved · 2024-01-15

Review body text here

---
```

## After Fetching

Once comments are presented, do NOT immediately analyze them. Wait for the user to ask for analysis or action. The user will typically want to:
- Understand the main concerns raised
- Plan fixes based on the feedback
- Discuss specific comments in detail

If the user asks for analysis, identify:
- Key themes and concerns across comments
- Unresolved threads or open questions
- Actionable items that need code changes
- Priority ordering (blockers first, then suggestions)

## Usage

- **"Pull PR comments"** — auto-detect PR from current branch
- **"Pull comments for #42"** — specific PR number
- **"Analyze the PR feedback"** — fetch + analyze
- **"What did reviewers say?"** — fetch + summarize

## Notes

- **Related:** Use `code-review` to independently review the same PR
- **Related:** Use `draft-pr` to update the PR description based on feedback