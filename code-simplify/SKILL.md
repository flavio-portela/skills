---
name: code-simplify
description: Simplifies and refactors code while preserving behavior. Identifies opportunities to reduce complexity, eliminate redundancy, and improve readability. Use when asked to simplify, clean up, or refactor code.
compatibility: "Requires git for codebase search. Works with any language/framework."
---

# Code Simplify

Refactor code to be cleaner, more concise, and easier to maintain — without changing behavior.

## Principles

1. **Preserve behavior** — the refactored code must do exactly the same thing
2. **Prefer readability** — clear beats clever; simplicity is the goal, not brevity
3. **Reuse before reinventing** — search the codebase for existing utilities before writing new logic
4. **Remove dead code** — eliminate unused variables, imports, functions, unreachable branches
5. **Reduce nesting** — flatten deeply nested conditionals with early returns, guard clauses
6. **Use language idioms** — leverage built-ins, standard library features, and common patterns
7. **Keep intent visible** — if simplification obscures *why* something is done, don't do it

## Workflow

### 1. Analyze the code

- Identify complexity hotspots: nested loops, long functions, repeated logic, deep nesting
- Find opportunities: redundant conditionals, unnecessary variables, verbose patterns, dead code
- Note edge cases, side effects, and invariants that must be preserved
- Check for existing tests — they define the behavioral contract

#### Check for existing utilities

Before extracting new helpers, search the codebase for existing utilities that could replace inline logic:

```bash
# Search for similar functions or utilities
rg "function.*<pattern>" --type-add
rg "export.*<keyword>" src/utils src/lib src/helpers
```

Common locations to check: utility directories, shared modules, files adjacent to the changed code. Flag any inline logic that duplicates existing functionality — hand-rolled string manipulation, manual path handling, custom environment checks, ad-hoc type guards, and similar patterns are frequent candidates.

### 2. Plan simplifications

Prioritize by impact. High-impact simplifications include:

- **Reuse existing utilities** — replace hand-rolled logic with functions already in the codebase
- Extract repeated logic into named helper functions
- Replace verbose conditionals with early returns / guard clauses
- Use language idioms (ternaries, destructuring, comprehensions, method chaining)
- Chain array methods (`filter`, `map`, `reduce`) instead of manual loops where clearer
- Remove intermediate variables that add no value or clarity
- Collapse redundant type checks or truthiness comparisons
- Merge adjacent similar branches

#### Efficiency review

While simplifying, also check for:

- **Unnecessary work** — redundant computations, repeated file reads, duplicate API calls, N+1 patterns
- **Missed concurrency** — independent operations run sequentially when they could be parallel
- **Hot-path bloat** — blocking work added to startup, per-request, or per-render paths
- **Recurring no-op updates** — state updates in polling loops or event handlers firing unconditionally; add change-detection guards
- **Unnecessary existence checks** — pre-checking file/resource existence before operating (TOCTOU anti-pattern); operate directly and handle the error
- **Memory concerns** — unbounded data structures, missing cleanup, event listener leaks
- **Overly broad operations** — reading entire files when only a portion is needed, loading all items when filtering for one

#### Architectural review

Watch for these patterns that signal deeper issues:

- **Redundant state** — state that duplicates existing state, cached values that could be derived, observers/effects that could be direct calls
- **Parameter sprawl** — adding new parameters instead of generalizing or restructuring
- **Copy-paste with variation** — near-duplicate blocks that should be unified with a shared abstraction
- **Leaky abstractions** — exposing internals that should be encapsulated, or breaking existing abstraction boundaries
- **Stringly-typed code** — raw strings where constants, enums, or branded types already exist
- **Unnecessary JSX nesting** — wrapper elements adding no layout value; check if inner component props suffice

### 3. Apply changes

Group related changes together. For each change:
- Show the before/after (diff or side-by-side)
- Briefly explain the improvement in one line
- Ensure the change is self-contained and doesn't break on its own

### 4. Verify

- Run existing tests if available (`npm test`, `pytest`, `cargo test`, etc.)
- Run the project linter/formatter if configured
- Flag any changes that might need additional test coverage
- Confirm no introduced bugs or changed behavior

## Reference Materials

- **Common patterns**: See `references/patterns.md` for before/after examples
- **Anti-patterns**: See `references/anti-patterns.md` for what to avoid

## Output Format

Present changes grouped by file (or function, if scoped). For each simplification:

```
### <File or function name>

**<Short description of change>**

```diff
- old code
+ new code
```
<One-line explanation of why this is better>
```

At the end, include a brief summary:

```
## Summary

- <N> simplifications across <M> file(s)
- <Key improvements, e.g., "removed 3 unused imports", "flattened 4 levels of nesting">
- Existing tests pass / No tests found — recommend adding coverage for <X>
```

## Usage

- **"Simplify this file"** — analyze and refactor the given file
- **"Simplify this function"** — focus on a single function or method
- **"Simplify the whole project"** — scan for patterns across multiple files
- **"Clean up dead code"** — focus on removing unused code only
- **"Make this more readable"** — prioritize clarity over brevity

For simple cases, a one-pass refactor is fine. For complex code, present the full simplified version and explain each change.

## Notes

- If the codebase has a style guide or linting config, follow it
- When in doubt, err on the side of clarity — over-simplification is a real risk
- If tests exist, run them after changes and report results
- If no tests exist and the code has complex behavior, flag it as a risk
- **Related:** Use `code-review` to validate that simplifications haven't introduced issues
