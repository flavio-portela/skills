---
name: code-review
description: Code review a GitHub pull request. Runs 5 independent review passes, confidence-scores every issue, filters to high-confidence findings, and posts a brief, cited comment on the PR. Use when asked to review a PR, code-review a PR, or comment on a PR's changes.
---

# Code Review

Provide a code review for the given pull request.

First, determine the pull request: use the PR number given by the user (eg. "review PR #42"); if no number is given, detect it from the current branch:

```bash
gh pr view --json number --jq '.number'
```

If the branch has no PR, ask for a PR number.

To do this, follow these steps precisely:

1. Check if the pull request (a) is closed, (b) is a draft, (c) does not need a code review (eg. because it is an automated pull request, or is very simple and obviously ok), or (d) already has a code review from you from earlier (a previous comment starting with "### Code review"). If so, do not proceed.
2. Get a list of file paths to (but not the contents of) any relevant convention files from the codebase. Look for BOTH `CLAUDE.md` and `AGENTS.md` — a project may use either or both: the root file(s) (if any exist), as well as any in the directories whose files the pull request modified. Below, "CLAUDE.md" refers to any of these files; when citing one in the review, use its actual file name (CLAUDE.md or AGENTS.md).
3. View the pull request (`gh pr view <NUMBER> --json title,body,labels` and `gh pr diff <NUMBER>`), and produce a summary of the change.
4. Then, run 5 independent review passes over the change. Each pass should do the following, then return a list of issues and the reason each issue was flagged (eg. CLAUDE.md adherence, bug, historical git context, etc.). Keep the passes independent of each other — do not let findings from one pass bias the others (for large diffs, you may run a pass in an isolated sub-agent via `delegate_task`):
   a. Pass #1: Audit the changes to make sure they comply with the CLAUDE.md. Note that CLAUDE.md is guidance for writing code, so not all instructions will be applicable during code review.
   b. Pass #2: Read the file changes in the pull request, then do a shallow scan for obvious bugs. Avoid reading extra context beyond the changes, focusing just on the changes themselves. Focus on large bugs, and avoid small issues and nitpicks. Ignore likely false positives.
   c. Pass #3: Read the git blame and history of the code modified, to identify any bugs in light of that historical context.
   d. Pass #4: Read previous pull requests that touched these files (eg. `gh search prs --filename <file>` or `git log -- <file>`), and check for any comments on those pull requests that may also apply to the current pull request.
   e. Pass #5: Read code comments in the modified files, and make sure the changes in the pull request comply with any guidance in the comments.
5. For each issue found in #4, score its confidence for whether the issue is real or a false positive. For issues that were flagged due to CLAUDE.md instructions, the score should double check that the CLAUDE.md actually calls out that issue specifically. Score each issue on a scale from 0-100, indicating the level of confidence. The scale is (apply this rubric verbatim):
   a. 0: Not confident at all. This is a false positive that doesn't stand up to light scrutiny, or is a pre-existing issue.
   b. 25: Somewhat confident. This might be a real issue, but may also be a false positive. The issue wasn't able to be verified that it's a real issue. If the issue is stylistic, it is one that was not explicitly called out in the relevant CLAUDE.md.
   c. 50: Moderately confident. This is verified to be a real issue, but it might be a nitpick or not happen very often in practice. Relative to the rest of the PR, it's not very important.
   d. 75: Highly confident. The issue was double checked, and verified to be very likely a real issue that will be hit in practice. The existing approach in the PR is insufficient. The issue is very important and will directly impact the code's functionality, or it is an issue that is directly mentioned in the relevant CLAUDE.md.
   e. 100: Absolutely certain. The issue was double checked, and confirmed to be definitely a real issue, that will happen frequently in practice. The evidence directly confirms this.
6. Filter out any issues with a score less than 80. If there are no issues that meet this criteria, do not proceed.
7. Repeat the eligibility check from #1, to make sure that the pull request is still eligible for code review.
8. Finally, use the `gh` command to comment back on the pull request with the result (`gh pr comment <NUMBER>`). When writing your comment, keep in mind to:
   a. Keep your output brief
   b. Avoid emojis
   c. Link and cite relevant code, files, and URLs

Examples of false positives, for steps 4 and 5:

- Pre-existing issues
- Something that looks like a bug but is not actually a bug
- Pedantic nitpicks that a senior engineer wouldn't call out
- Issues that a linter, typechecker, or compiler would catch (eg. missing or incorrect imports, type errors, broken tests, formatting issues, pedantic style issues like newlines). No need to run these build steps yourself -- it is safe to assume that they will be run separately as part of CI.
- General code quality issues (eg. lack of test coverage, general security issues, poor documentation), unless explicitly required in CLAUDE.md
- Issues that are called out in CLAUDE.md, but explicitly silenced in the code (eg. due to a lint ignore comment)
- Changes in functionality that are likely intentional or are directly related to the broader change
- Real issues, but on lines that the user did not modify in their pull request

Notes:

- Do not check build signal or attempt to build or typecheck the app. These will run separately, and are not relevant to your code review.
- Use `gh` to interact with Github (eg. to fetch a pull request, or to create inline comments), rather than web fetch
- Make a todo list first
- You must cite and link each bug (eg. if referring to a convention file like CLAUDE.md or AGENTS.md, you must link it)
- For your final comment, follow the following format precisely (assuming in this example that you found 3 issues):

---

### Code review

Found 3 issues:

1. <brief description of bug> (CLAUDE.md says "<...>")

<link to file and line with full sha1 + line range for context, note that you MUST provide the full sha and not shell expansion here, eg. https://github.com/owner/repo/blob/1d54823877c4de72b2316a64032a54afc404e619/src/foo.ts#L13-L17>

2. <brief description of bug> (some/other/CLAUDE.md says "<...>")

<link to file and line with full sha1 + line range for context>

3. <brief description of bug> (bug due to <file and code snippet>)

<link to file and line with full sha1 + line range for context>

---

- Or, if you found no issues:

---

### Code review

No issues found. Checked for bugs and CLAUDE.md compliance.

---

- When linking to code, follow the following format precisely, otherwise the Markdown preview won't render correctly: https://github.com/owner/repo/blob/c21d3c10bc8e898b7ac1a2d745bdc9bc4e423afe/package.json#L10-L15
  - Requires full git sha — use the PR's head commit sha (`gh pr view <NUMBER> --json headRefOid --jq '.headRefOid'`) and paste the literal value. Commands like `https://github.com/owner/repo/blob/$(git rev-parse HEAD)/foo/bar` will not work, since your comment will be directly rendered in Markdown.
  - Repo name must match the repo you're code reviewing
  - `#` sign after the file name
  - Line range format is `L[start]-L[end]`
  - Provide at least 1 line of context before and after, centered on the line you are commenting about (eg. if you are commenting about lines 5-6, you should link to `L4-7`)
