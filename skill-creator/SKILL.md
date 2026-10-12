---
name: skill-creator
description: Create new skills, modify and improve existing skills, and test them with an evaluation loop. Use whenever the user wants to create, write, or turn a workflow into a skill; improve, refine, or restructure an existing skill; or test a skill against sample prompts — even when they just say "let's make a skill for X" without details.
---

# Skill Creator

Guide the user through the loop: **capture intent → draft the skill → run test prompts → review results together → improve → repeat** until the user is satisfied. The order is flexible — figure out where the user is (a fresh idea, a half-finished draft, "optimize my skill") and jump in there.

Match the user's technical level. If they don't know terms like "evaluation" or "assertion", say so briefly once and keep the language plain.

## Stage 1 — Capture intent

If the user says "turn this into a skill", mine the current conversation first: the tools used, the sequence of steps, corrections they made, and input/output formats observed. Confirm with the user before drafting.

Otherwise ask:

1. What should this skill enable Pi to do?
2. When should it trigger — what user phrasings or contexts?
3. What's the expected output (format, files, structure)?
4. Should it be testable? Skills with objectively verifiable output (file transforms, extraction, fixed workflows) benefit from test cases; subjective skills (writing style, design) are better judged by eye. Suggest the default, let the user decide.

Then interview about edge cases, input formats, example files, success criteria, and dependencies. Do lightweight research (docs, existing skills, similar workflows) so you arrive with context instead of burdening the user.

## Stage 2 — Write the skill

### Where Pi skills live

| Location | Scope |
|---|---|
| `~/.pi/agent/skills/` | All projects (discovered recursively) |
| `<project>/.agents/skills/` | One project (discovered from the working directory up to the repo root) |

The `name` frontmatter field becomes the `/skill:name` command; `/reload` picks up edits mid-session. Note: while a skill under development sits in a discoverable location, fresh sessions will see it automatically — keep that in mind for baselines (stage 3).

### Frontmatter

```yaml
---
name: my-skill              # lowercase, digits, hyphens; max 64 chars
description: <what it does> + <when to use it>   # max 1024 chars
---
```

The description is the *only* routing mechanism — it is what's in context when the model decides whether to load the skill. State both what the skill does and concrete contexts for when to use it, and lean slightly pushy to fight under-triggering: prefer "Use this skill whenever the user mentions X or wants Y, even if they don't say 'dashboard'" over a modest description.

Optional fields: `license`, `compatibility`, `metadata`, and `disable-model-invocation: true` (makes the skill available only via `/skill:name`).

### Anatomy

```
skill-name/
├── SKILL.md        # required
├── scripts/        # deterministic/repetitive work the model shouldn't reinvent
├── references/     # docs loaded into context as needed
└── assets/         # templates, files used in the output
```

Progressive disclosure keeps context small: metadata is always in context, the SKILL.md body loads when the skill triggers, and everything else loads only when needed.

- Keep SKILL.md under ~500 lines; beyond that, add a `references/` layer with clear pointers for when to read each file.
- Include a table of contents for reference files over ~300 lines.
- Multiple domains? One reference file per variant, and SKILL.md just explains how to pick.
- Refer to bundled files with paths relative to the skill directory.

### Writing guide

- Use direct imperative instructions.
- Define exact output formats with templates when the output must be precise.
- Include 1–3 short input→output examples where format matters.
- Explain the *why* behind requirements instead of stacking MUST/NEVER. Models generalize better from reasoning than from rigid rules; if a draft is full of all-caps commands, reframe them.
- Keep it general, not narrow to the test prompts you'll run later.
- A skill must not surprise the user: nothing malicious, nothing misleading. Refuse requests to build deceptive skills, or skills that facilitate unauthorized access or data exfiltration.

## Stage 3 — Test prompts

Write 2–3 realistic test prompts — the kind a real user would actually say, with realistic filenames, casual phrasing, and missing details. Save them:

```json
{
  "skill_name": "my-skill",
  "evals": [
    {"id": 0, "name": "descriptive-name", "prompt": "...", "expected": "what good looks like"}
  ]
}
```

Confirm the set with the user before running.

### Run in fresh one-shot sessions

Pi has no subagents; the equivalent is a fresh `pi --print` session. Its context is clean — it doesn't know the skill is being tested — so the results are honest.

For each eval, run two versions: with the skill and a baseline. Launch all runs at once (one bash call with `&` and `wait`) so they finish together:

```bash
mkdir -p <workspace>/iteration-1/eval-<name>/{with_skill,without_skill}

# With-skill: point the session explicitly at the skill (isolates content quality from triggering)
pi --no-session --print "Read <path-to-skill>/SKILL.md and follow it to complete this task:
<eval prompt>
Save any output files to <workspace>/iteration-1/eval-<name>/with_skill/outputs/" \
  > <workspace>/iteration-1/eval-<name>/with_skill/transcript.txt 2>&1 &

# Baseline: same prompt, no skill
pi --no-session --print "<eval prompt>
Save any output files to <workspace>/iteration-1/eval-<name>/without_skill/outputs/" \
  > <workspace>/iteration-1/eval-<name>/without_skill/transcript.txt 2>&1 &

wait
```

Rules:

- Put `<workspace>` in a scratch location (e.g. `~/tmp/`) or as a sibling of the skill directory — outside any project you're testing, so project settings don't skew the runs.
- **New skill**: baseline = no skill. **Improving an existing skill**: snapshot it first (`cp -r` into the workspace) and point the baseline at the snapshot.
- If runs time out, run them in series instead of parallel.
- Where output is objectively checkable (a CSV, extracted text, files that must exist), write and run a small check script — faster and reproducible across iterations than eyeballing.

While the runs are in progress, draft what "good" looks like for each eval and tell the user what they'll see.

## Stage 4 — Review together

There's no browser viewer; review happens in the conversation:

- Per eval, show the prompt, the key output (inline excerpt plus file paths), and the check results for with-skill vs baseline.
- Read the transcripts too, not just final outputs — if a run was slow or confused, the transcript says why.
- Ask for concrete feedback per eval. Empty feedback means it was fine; focus improvements on the evals with real complaints.

## Stage 5 — Iterate

1. **Generalize.** You're iterating on a few examples, but the skill will face many. If an issue is stubborn, try a different explanation or working pattern rather than a tighter MUST.
2. **Keep it lean.** Remove anything not pulling its weight.
3. **Explain the why.** Even terse or frustrated feedback has a reason behind it — figure out what the user actually wanted and transmit that understanding into the instructions.
4. **Find repeated work.** If every test run independently wrote a similar helper script or took the same multi-step approach, that's a signal the skill should bundle that script.

Then: apply the improvements, rerun all evals (with-skill + baseline) into `iteration-<N+1>/`, show results alongside the previous iteration, and ask for feedback again. Keep looping until the user is happy, feedback is empty, or progress stalls.

## Stage 6 — Description tuning (optional)

The description determines whether the skill triggers automatically. Offer this once the skill's content is stable.

1. Generate ~10 should-trigger and ~10 should-not-trigger queries. Realistic and concrete — filenames, jobs, typos, casual speech. The negatives must be near-misses that share keywords but need something else, not obviously irrelevant filler.
2. Review the list with the user; let them edit it.
3. Trigger-test: from a directory where the skill is discoverable (install it to `~/.pi/agent/skills/` or a project `.agents/skills/` if needed), run each query in a fresh session and check whether the model loaded the skill — count it as triggered if the event stream contains a tool call reading the skill's SKILL.md:

   ```bash
   pi --no-session --mode json --print "<query>" | grep -c "<skill-name>/SKILL.md"
   ```

   Run each query 2–3 times for a reliable rate. Note the model won't load a skill for trivial one-step tasks regardless of description — keep the queries substantive.
4. Analyze the misses, rewrite the description, retest. When done, update the frontmatter and show the user before/after with the trigger rates.

## Finishing

- Validate: Pi warns at startup about malformed frontmatter and missing descriptions — check after `/reload`.
- Install: `~/.pi/agent/skills/` for global use, a project's `.agents/skills/` for project-specific skills.
- Share: zip the folder, or publish it as a Pi package (see Pi docs, `packages.md`).
- Clean up: remove the workspace unless the user wants to keep it.
