# Skill Audit — Layer 2: Staleness Signals

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then cross-reference each skill's claims against current system state.

---

## Signals

| Signal | What to Check |
|--------|---------------|
| File paths | Does every referenced path still exist? (`grep` for paths, verify with `ls`) |
| Function/variable names | Does every referenced symbol still exist? (`grep` in the target repo) |
| Tool/command names | Are referenced CLI tools still installed and current? |
| Skill cross-references | Do referenced skills still exist by that name? |
| Template variables | Are there unresolved `{{placeholder}}` values that should have been replaced by setup? |
| Repo structure | If the skill references a directory layout, does it match? |
| Numeric claims | Does the skill cite a count (file count, line count, threshold) that matches reality? Counts rot when content changes. |

---

## Output Shape

For each contradiction, capture:

| Field | Content |
|-------|---------|
| `claim` | Exact quote from the skill |
| `reality` | What the repo/system actually shows (with verification command) |
| `suggestion` | Proposed correction |

Prefer corrections that remove the rotting claim entirely (e.g., drop a numeric count) over corrections that update it to a new value.
