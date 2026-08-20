# Code Quality Audit — Layer 3: Gap Heuristics

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then check each changed file for missing elements that reduce code quality.

---

## Heuristics

| Gap | How to Detect | Impact |
|-----|---------------|--------|
| New public function without test | Function exported in the diff has no corresponding test in `*.spec.ts` / `test_*.py` / etc. | Behavior is unverified; future refactors may regress silently |
| New export without explicit type | Function or class is exported with inferred return type rather than annotated | Public-API contract is implicit; consumers see whatever the inference produces |
| New `throw` without error context | `throw new Error('failed')` with no message detail vs. `throw new Error(\`failed to copy role from ${env}: ${cause}\`)` | Operators triaging incidents have no signal; transient vs. permanent errors indistinguishable |
| New branch without test coverage | New `if`/`else`/`switch`/ternary on a typed value where one or more branches lack a corresponding test case | Heuristic only — auditor surfaces, doesn't mechanically verify; reviewer judges coverage adequacy |
| New public API change without docstring/JSDoc | Modified or added public function/method/class without an accompanying JSDoc / docstring update | Consumers reading the API have to read the implementation to know what changed |
| New error class not extending project base | New error class extends `Error` directly instead of the project-standard base (e.g., `BadRequestError`, `ServerError`, `@contentful/errors`) | Diverges from the team's error-handling convention; loses project-level error metadata |
| New env var without default in config | New `process.env.X` reference without a corresponding entry in `.env.example` / config schema | Deployment surprises; missing var causes silent runtime failures or hard crashes at startup |
| New SNS/event publish without consumer | New `publishEvent(...)` call where no listener / handler / subscriber exists in the repo | Events fire into the void; either the consumer is in another service (document it) or the publish is dead code |

---

## Output Shape

For each gap, capture:

| Field | Content |
|-------|---------|
| `gap` | What's missing (matches a row from the heuristics table) |
| `impact` | Why it matters for code quality in this specific change |
| `proposed-fix` | Concrete edit, not vague guidance. Cite the exact file/line to modify. |
