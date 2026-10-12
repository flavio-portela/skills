---
name: code-simplify
description: Simplify or refactor existing code while preserving behavior. Use when asked to clean up a function, make code more readable, remove dead code, reduce duplication, or simplify a file or project.
---

# Code Simplify

Make the smallest changes that leave the code easier to understand and maintain. Simplicity means clearer intent, not fewer lines at any cost.

## Scope and safety

- Work within the requested function, file, or area. For a project-wide request, identify the best candidates and agree on scope before making sweeping edits. Do not turn a readability task into an optimization or architecture project.
- Follow the repository's instructions and style. Check for uncommitted work before editing; do not overwrite or tidy someone else's changes.
- Preserve observable behavior: return values and types, public contracts, validation, error handling, side effects, evaluation order and frequency, async timing, and externally visible state. A change that only *looks* equivalent is not enough.
- Prefer clear control flow and useful names over compressed expressions. Reuse an existing utility only when its semantics match; avoid creating a helper for a single use unless it makes intent substantially clearer.
- Remove code only when it is demonstrably unused within the requested scope. Check callers, exports, and non-obvious uses before deleting anything. Keep comments that explain hidden constraints or *why* the code works this way; update comments made stale by your edit.
- If behavior is unclear or tests cannot establish a risky transformation's safety, ask or leave that transformation alone. You can report an opportunity without implementing it.

## Workflow

1. **Understand.** Read the target and its callers or neighboring code as needed. Note invariants and side effects. Check relevant tests, types, and existing utilities before inventing replacements. Search with a concrete pattern, e.g. `rg -n 'keyword' path/to/area`.
2. **Choose.** Look for redundant branches, avoidable nesting, repeated logic, and unnecessary intermediates. Favor a few self-contained changes with clear readability benefits; skip stylistic churn. Do not assume that replacing loops with chained array methods, parallelizing operations, or deriving state is equivalent.
3. **Edit.** Make focused changes only. Avoid unrelated formatting, renames, API changes, and pre-existing dead code outside the requested area. Remove any imports or declarations *your* changes make unused.
4. **Verify.** Review the diff for changed behavior and accidental edits. Run relevant tests, typecheck, and lint where available; for complex or poorly covered behavior, add focused characterization tests when practical. If a check fails, distinguish pre-existing failures from regressions. State clearly what you did and did not verify.

## Examples

A redundant branch can be collapsed when the input is already a boolean:

```typescript
// Before
function isEnabled(flag: boolean): boolean {
  if (flag === true) return true;
  return false;
}

// After
function isEnabled(flag: boolean): boolean {
  return flag;
}
```

A guard can make the happy path clearer without changing which conditions run:

```typescript
// Before
function process(user?: User) {
  if (user) {
    if (user.active) return run(user);
  }
  return null;
}

// After
function process(user?: User) {
  if (!user || !user.active) return null;
  return run(user);
}
```

These are patterns, not automatic rewrites. In particular, preserve short-circuiting, coercion, thrown errors, and side-effect order. If an existing `if` checks something other than a boolean, `return value` may not be equivalent.

## Report

Summarize changes by file: what became clearer and why. Include notable risks or opportunities left untouched. Report the exact verification performed and its result; do not claim behavior is unchanged solely because code compiles. Show a diff or before/after excerpt when it helps explain a non-obvious change, not for every trivial edit. If no changes are safe or worthwhile, say so rather than forcing a refactor.
