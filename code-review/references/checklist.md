# Code Review Checklist

## 🔴 Must-Fix — Ship blockers

| # | Check | What to look for |
|---|-------|-----------------|
| M1 | **Logic errors** | Off-by-one, inverted conditions, wrong operator, unreachable code, race conditions |
| M2 | **Security holes** | SQL injection, XSS, CSRF, hardcoded secrets, insecure defaults, missing auth checks |
| M3 | **Data loss / corruption** | Missing transactions, unsafe concurrent writes, cascading deletes without safeguards |
| M4 | **Unhandled failures** | Uncaught exceptions, swallowed errors, missing error boundaries, bare `.catch(() => {})` |
| M5 | **Breaking changes** | Removed/renamed public APIs, changed response shapes, altered DB schemas without migration |

## 🟡 Should-Fix — Real problems, not emergencies

| # | Check | What to look for |
|---|-------|-----------------|
| S1 | **Leaked resources** | Unclosed connections, missing cleanup, event listener leaks, unresolved promises |
| S2 | **Performance traps** | N+1 queries, unnecessary re-renders, O(n²) where O(n) is easy, unbounded result sets |
| S3 | **Missing edge cases** | Empty arrays, null/undefined inputs, concurrent access, large payloads, timeout scenarios |
| S4 | **Incorrect error handling** | Catching too broadly, wrong error type, misleading error messages, errors that hide the real cause |
| S5 | **Missing tests** | Changed logic with no new or updated tests, critical paths untested |
| S6 | **Broken tests** | Tests that pass but don't assert, skipped tests, flaky test patterns |

## 🔵 Suggestions — Better if changed (--thorough only)

| # | Check | What to look for |
|---|-------|-----------------|
| B1 | **Readability** | Unclear naming, deep nesting, long functions, magic numbers, confusing control flow |
| B2 | **Consistency** | Doesn't follow patterns in surrounding code, inconsistent naming/style, mixed paradigms |
| B3 | **Redundancy** | Duplicated logic, unnecessary wrappers, dead code, overly defensive checks |
| B4 | **API ergonomics** | Confusing parameter order, too many arguments, unclear return types, leaky abstractions |
| B5 | **Missing documentation** | Public APIs without docstrings, complex logic without comments, changed behavior not noted |

## 💡 Nits — Style and polish (--thorough only)

| # | Check | What to look for |
|---|-------|-----------------|
| N1 | **Style** | Formatting, trailing commas, import ordering, inconsistent quoting |
| N2 | **Typo / wording** | Variable typos, unclear comments, error message wording |
| N3 | **Small simplifications** | `if/return` that could be guard clause, ternary that could be `||`, verbose condition |