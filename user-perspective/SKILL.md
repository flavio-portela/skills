---
name: user-perspective
description: Puts the agent in the shoes of the product's target user, then brainstorms ideas and proposes features from that user's perspective. Use when asked to brainstorm features, think like the user, or evaluate an idea from a user-empathy standpoint.
---

# User Perspective

Think from the target user's seat, not the builder's seat. The point is a concrete persona and pains grounded in real workflows — not generic "users might want X" wishlists.

## Workflow

1. **Identify the product and target user**
   - If context is available (README, code, docs, conversation), infer the product and who uses it. State your assumptions explicitly.
   - If genuinely unclear, ask 1-2 sharp questions: what does the product do, and who uses it and why?

2. **Build the persona** (concrete, 3-5 lines — not a marketing profile):
   - Who they are, and the context where they use the product (device, alone/team, time pressure)
   - The job they're trying to get done when they open it
   - What frustrates them today (manual workarounds, gaps in current tools, friction points)
   - What "good" looks like to them — an outcome, not a feature

   If the product has no clear target user, say so and propose 2-3 candidate personas to pick from instead of spreading thin across everyone.

3. **Walk the user journey**
   - List the key steps from "I have a need" to "the need is met", in the user's own words.
   - For each step note: what they do, what they expect, where friction, confusion, or wasted time appears.

4. **Brainstorm from the persona's voice**
   - Ideas must trace back to a pain from step 3. If an idea has no pain behind it, either find the pain or drop it.
   - Phrase each idea as the user experiences it: "As a <kind of user>, when <situation>, I want <outcome> so that <benefit>" — or a short first-person scenario.

5. **Propose features**
   For each idea:
   - **Pitch**: one line, user benefit first (no jargon)
   - **Value**: High/Medium/Low + why, from the persona's point of view
   - **Effort**: Small/Medium/Large + rough reason (codebase awareness helps; guess and flag if unsure)
   - **MVP candidate?**: yes/no — does a user live or die without it?

   Rank the top 3-5.

6. **If the user brought their own idea**, run it through the same lens instead of generating new ones:
   - Does the persona actually want this, and when in their journey would they use it?
   - What would make it delight them / fall flat?
   - What's the smallest version that delivers the core benefit?

## Output format

```
## Persona
<3-5 lines>

## Where it hurts
- <journey step> — <friction> (High/Med/Low)

## Ideas
1. <name> — <one-line pitch>
   Value: H/M/L (why) · Effort: S/M/L (why) · MVP: yes/no
...

## Top picks
1. <name> — <why it wins>
```

## Ground rules

- Stay in the persona's vocabulary. If it sounds like an engineer talking, rewrite it.
- One user, one context per pass. Don't hedge across every possible user segment.
- Challenge your own ideas: "just add a button" is not an idea — name the problem it solves or cut it.
- Be willing to say "this persona probably doesn't care about this" — a negative finding is a useful finding.
