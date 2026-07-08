# Kiln Scenario Registry

Loaded on-demand by `SKILL.md` at the classify step. The scenario is the **second**
classification dimension, orthogonal to the complexity tier (TRIVIAL/STANDARD) and the
blast radius (LOW/HIGH). It selects (a) the Crafter's per-task verification discipline and
(b) the patterns/standards source injected into the brief. The conductor passes the resolved
scenario into every Crafter and Inspector dispatch.

## Detection — first match wins, top to bottom

| Scenario | Detection signal (checked against the change's file targets) | Status |
|---|---|---|
| **tool-authoring** | target path matches `**/skills/**`, `**/agents/**`, a `SKILL.md`, an agent `*.md`, or directive prose under `prompts/`/`knowledge/`/`references/` — EXCLUDING `src/`/`lib/`/`test/` subtrees (those are `code` even when nested under `plugins/`) | **P1** |
| **code** | source files under `src/`/`packages/`/`apps/`/`lib/` with a real test runner present (`package.json` test script, `pytest`, etc.) | **P1** |
| mcp/agent-app | building a FastMCP server, ADK/SDK agent, or LLM app in code | NOT-YET (P2) |
| doc/RFC | target is an RFC/ADR/README/design `.md` (prose, not a skill) | NOT-YET (P2) |
| infra | terraform/k8s/serverless manifests | NOT-YET (P2) |

**A target that matches a `NOT-YET (P2)` row → HALT-AND-ASK.** Do not fall through to `code`.
Announce: "This looks like a <scenario> task — that scenario lands in Kiln P2. For now, provide
a `code` or `tool-authoring`-shaped change, or run the steps manually." Silent mis-routing onto
`code` (forcing red-green TDD onto prose) is the exact current-Kiln failure this registry exists to prevent.

**Ambiguous between the two P1 scenarios** (e.g. a PR that edits both `src/` code and a `SKILL.md`):
treat as `code` for its code targets and `tool-authoring` for its prose targets — the Crafter receives
the scenario per-task, and a task's scenario follows its own file targets, not the run's.

## Per-scenario verification + patterns source (P1 rows)

| Scenario | Per-task Crafter verification | Patterns / standards injected at authoring time |
|---|---|---|
| **code** | `superpowers:test-driven-development` (red-green, hard invoke). If a task touches a browser/iOS frontend, ALSO run Compounds' E2E "use-it-like-a-user" framework via `get_testing_frameworks(test_layers=["e2e"])`, gated by that framework's own `apply_when`/`do_not_apply`. | Compounds `get_design_patterns` + `get_testing_frameworks` + `code-quality-standards` skill |
| **tool-authoring** | **Deterministic self-check only** (NO per-task adversarial agent dispatch): frontmatter parses; `description` has trigger phrases; no forbidden patterns (grep); calibration fixtures green IF the artifact has them. Full `skill-audit`/`directive-review` is deferred to PR-time (once, via the gauntlet). | `skill-authoring-principles` + `directive-review` reference files + the owner's harness research |

## Three-layer verification (why tool-authoring is NOT per-task adversarial)

1. **Authoring-time** (injected into the brief): the *principles* above — so the artifact is written to spec the first time. ~free.
2. **Per-task** (Crafter self-check + bounded Inspector read): deterministic checks only, per the table. Cheap.
3. **PR-time** (once, on the whole diff, outside the Kiln): full `skill-audit`/`directive-review`/`doc-review` via `/gauntlet`. The one heavyweight pass.

Running the heavyweight finder+validator skills per task would duplicate the PR gauntlet N times — forbidden.
