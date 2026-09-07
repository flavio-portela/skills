---
name: pr-comments
description: Fetches and presents comments from a GitHub pull request. Use when asked to pull, get, or review PR comments. Organizes review comments by file for easy analysis and action planning.
---

# PR Comments

Fetches all comments from a GitHub pull request and presents them in a structured, file-organized format for analysis and action planning.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`)
- Repository must be a GitHub repo

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
- Reply to review threads (see "Replying to Threads")

If the user asks for analysis, identify:
- Key themes and concerns across comments
- Unresolved threads or open questions
- Actionable items that need code changes
- Priority ordering (blockers first, then suggestions)

## Replying to Threads

Use this when the user asks to answer/reply to specific comments (e.g. review
feedback from a human or a bot like Codex). Always confirm the reply text
with the user before posting to a live PR.

### Review comment threads (inline comments on code)

`in_reply_to` **must be a JSON number**, and `gh api -f` sends every param
as a string — `gh api ... -f in_reply_to=123` is rejected with a cryptic
`oneOf` validation error (it contains `"..." is not a number`; read the
error carefully instead of assuming the param was removed). Send raw JSON
via curl:

```bash
TOKEN=$(gh auth token)

# Payload file avoids shell-escaping markdown bodies
printf '%s' '{"in_reply_to": 123456789, "body": "Reply text (markdown OK)"}' > /tmp/pr-reply.json

# Sanity-check the payload before posting (jq fails on bad JSON/escaping)
jq -c '{in_reply_to, body: .body[0:40]}' /tmp/pr-reply.json

curl -s -X POST "https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/comments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  --data @/tmp/pr-reply.json | jq -c '{id, in_reply_to_id}'
```

- Point `in_reply_to` at the thread's **top-level** comment id (the one
  with `in_reply_to_id: null` from the fetch step) — the reply renders in
  that thread.
- Do NOT use the GraphQL `addComment` / `addPullRequestReviewThreadReply`
  mutations for this: that API surface is in flux (inputs/payload fields
  change between versions) and can fail silently with `comment: null` and
  no error. The REST endpoint above is stable.

### Issue/conversation comments

Flat list, no `in_reply_to` — the plain `gh api` form works here (no
numeric-typed fields):

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments -f body="Reply text"
```

### Hygiene

- Never probe the mechanism with dummy comments on a live PR — validate the
  JSON payload locally (`jq .`) instead.
- If you must delete a comment, verify by HTTP status, not body shape (204
  has an empty body, which is easy to confuse with an error payload):
  ```bash
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE \
    "https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}" \
    -H "Authorization: Bearer $TOKEN"   # expect 204
  ```
- The comments list API can lag a minute or two after a deletion — verify
  with a direct GET of the comment id (404 = gone) if the list still shows it.