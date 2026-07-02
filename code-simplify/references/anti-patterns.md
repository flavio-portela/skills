# Simplification Anti-Patterns

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

## Comments

- **Delete** comments explaining *what* the code does (well-named identifiers already do that), narrating the change, or referencing the task/caller
- **Keep** only non-obvious *why*: hidden constraints, subtle invariants, workarounds for known issues, and non-obvious tradeoffs
