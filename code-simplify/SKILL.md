---
name: code-simplify
description: Simplifies and refactors code while preserving behavior. Identifies opportunities to reduce complexity, eliminate redundancy, and improve readability. Use when asked to simplify, clean up, or refactor code.
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

## Common Simplification Patterns

**Redundant conditional:**
```javascript
// Before
if (isValid === true) {
  return true;
} else {
  return false;
}

// After
return isValid;
```

**Verbose array processing:**
```javascript
// Before
const result = [];
for (const item of items) {
  if (item.active) {
    result.push(item);
  }
}

// After
const result = items.filter(item => item.active);
```

**Deep nesting via early return:**
```python
# Before
def process(user):
    if user:
        if user.is_active:
            if user.has_permission:
                return do_thing(user)
            else:
                return None
        else:
            return None
    else:
        return None

# After
def process(user):
    if not user or not user.is_active or not user.has_permission:
        return None
    return do_thing(user)
```

**Dead code removal:**
```typescript
// Before
import { formatDate, parseCSV, unusedHelper } from './utils';

const MAX_RETRIES = 3;
const DEPRECATED_LIMIT = 100; // no longer used

export function submit(data) {
  const retries = 0; // assigned but never read
  return api.post('/submit', data);
}

// After
import { formatDate, parseCSV } from './utils';

export function submit(data) {
  return api.post('/submit', data);
}
```

**Function extraction for repeated logic:**
```javascript
// Before
if (user.role === 'admin' && user.status === 'active') {
  // 15 lines of permission setup
}
// ... later ...
if (user.role === 'admin' && user.status === 'active') {
  // same 15 lines of permission setup
}

// After
function isAdminActive(user) {
  return user.role === 'admin' && user.status === 'active';
}

function setupAdminPermissions(user) {
  // 15 lines of permission setup
}

if (isAdminActive(user)) {
  setupAdminPermissions(user);
}
// ... later ...
if (isAdminActive(user)) {
  setupAdminPermissions(user);
}
```

**TOCTOU anti-pattern:**
```python
# Before
if os.path.exists(filepath):
    data = open(filepath).read()

# After
try:
    with open(filepath) as f:
        data = f.read()
except FileNotFoundError:
    data = None
```

**Redundant state:**
```javascript
// Before
const [items, setItems] = useState([]);
const [filteredItems, setFilteredItems] = useState([]);

// filteredItems is manually synced whenever items or filter changes
useEffect(() => {
  setFilteredItems(items.filter(item => matchesFilter(item)));
}, [items, filter]);

// After
const [items, setItems] = useState([]);
const filteredItems = useMemo(() => items.filter(item => matchesFilter(item)), [items, filter]);
```

## Anti-patterns

| ❌ Don't | ✅ Do |
|---|---|
| Compress multi-line logic into unreadable one-liners | Keep multi-step logic spread across readable lines |
| Remove explicit type annotations for brevity | Preserve types — they document intent |
| Rename variables to shorter names | Keep descriptive names; rename only if genuinely verbose |
| Remove error handling to "simplify" | Error handling is behavior, not noise |
| Introduce clever operators (`??`, `&&`, `\|\|`) for control flow | Use them only when the intent is immediately clear |
| Simplify code you don't fully understand | If the code's purpose isn't clear, ask first — don't guess |
| Change public APIs or interfaces | Simplify internals only; external contracts stay untouched |
| Write new utilities without checking for existing ones | Search the codebase first — reuse before reinvent |
| Pre-check existence before operating (TOCTOU) | Operate directly, handle the error |
| Duplicate state that can be derived | Derive it at read time or memoize |
| Add parameters to fix a one-off case | Generalize the function or restructure instead |
| Use raw strings where enums/constants exist | Use the typed constants already in the codebase |

### Comments

- **Delete** comments explaining *what* the code does (well-named identifiers already do that), narrating the change, or referencing the task/caller
- **Keep** only non-obvious *why*: hidden constraints, subtle invariants, workarounds for known issues, and non-obvious tradeoffs

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
