# Code Quality Audit — Layer 2: Staleness Signals

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then cross-reference each changed file's patterns against deprecation signals in the codebase.

---

## Signals

| Signal | What to Check |
|--------|---------------|
| `@deprecated` on a modified function | If the diff modifies (not just calls) a function annotated `@deprecated`, flag — extending deprecated code is a smell |
| Stale `// TODO: remove` | Comments marked for removal that are >6 months old (heuristic via `git blame` if available) — flag for review |
| References to `legacy/` or `deprecated/` directories | New code importing from a directory explicitly marked legacy — flag |
| Use of a migrated-away API | If 80%+ of callers use a newer API and this diff uses the older one, flag — likely an unintentional regression |
| New use of a pattern documented as deprecated | CLAUDE.md / ARCHITECTURE.md / similar repo docs explicitly mark the pattern stale; the diff reintroduces it |
| Imports from `@deprecated`-flagged packages | Check `package.json` / `Cargo.toml` / `requirements.txt` for deprecated dependency annotations |

---

## Output Shape

For each contradiction, capture:

| Field | Content |
|-------|---------|
| `claim` | Exact code snippet from the diff (e.g., `import { foo } from '@org/legacy-utils'`) |
| `reality` | What the codebase says (e.g., `package.json marks @org/legacy-utils as deprecated; replacement is @org/utils-v2`) |
| `suggestion` | Proposed correction (concrete: which import to swap to, which API to use instead) |

Prefer corrections that remove the stale claim entirely over corrections that update it. If the diff resurrects deprecated code, the right fix is usually "use the current API" not "update the deprecation notice."
