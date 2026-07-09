# Kiln Scenario Registry

Loaded on-demand by `SKILL.md` at the classify step. The scenario is the **second**
classification dimension, orthogonal to the complexity tier (TRIVIAL/STANDARD) and the
blast radius (LOW/HIGH). It selects (a) the Crafter's per-task verification discipline and
(b) the patterns/standards source injected into the brief. The conductor passes the resolved
scenario into every Crafter and Inspector dispatch.

The scenario also selects the **engine** (see `engines.md`): `code` → compounds; `tool-authoring` → native; `doc` → native. The conductor binds it at classify, writes the `engine:` ledger tag, and narrates why.

## Detection — first match wins, top to bottom

| Scenario | Detection signal (checked against the change's file targets) | Status |
|---|---|---|
| **tool-authoring** | target path matches `**/skills/**`, `**/agents/**`, a `SKILL.md`, an agent `*.md`, or directive prose under `prompts/`/`knowledge/`/`references/` — EXCLUDING `src/`/`lib/`/`test/` subtrees (those are `code` even when nested under `plugins/`) | **P1** |
| **code** | source files under `src/`/`packages/`/`apps/`/`lib/` with a real test runner present (`package.json` test script, `pytest`, etc.) | **P1** |
| **doc** | target is an RFC/ADR/README/design `.md` (prose, not a skill) | **P1** |
| mcp/agent-app | building a FastMCP server, ADK/SDK agent, or LLM app in code | NOT-YET (P2) |
| infra | terraform/k8s/serverless manifests | NOT-YET (P2) |

**A target that matches a `NOT-YET (P2)` row → HALT-AND-ASK.** Do not fall through to `code`.
Announce: "This looks like a <scenario> task — that scenario lands in Kiln P2. For now, provide
a `code`, `tool-authoring`, or `doc`-shaped change, or run the steps manually." Silent mis-routing
onto `code` (forcing an unfit verification discipline onto a mismatched target) is the exact
current-Kiln failure this registry exists to prevent.

**Ambiguous between the two P1 scenarios** (e.g. a PR that edits both `src/` code and a `SKILL.md`):
treat as `code` for its code targets and `tool-authoring` for its prose targets — the Crafter receives
the scenario per-task, and a task's scenario follows its own file targets, not the run's.

## Per-scenario verification + patterns source (P1 rows)

| Scenario | Engine | Per-task Crafter verification | Patterns / standards injected at authoring time |
|---|---|---|---|
| **code** | compounds | `implement_task` drives impl+test at craft time (design D3 — no mandatory red-green). If a task touches a browser/iOS frontend, ALSO run Compounds' E2E "use-it-like-a-user" framework via `get_testing_frameworks(test_layers=["e2e"])`, gated by that framework's own `apply_when`/`do_not_apply`. | Compounds `get_design_patterns` + `get_testing_frameworks` + `get_reference_architecture` (Planner-enriched into the brief) + `code-quality-standards` skill |
| **tool-authoring** | native | **Deterministic self-check only** (NO per-task adversarial agent dispatch): frontmatter parses; `description` has trigger phrases; no forbidden patterns (grep); calibration fixtures green IF the artifact has them. Full `skill-audit`/`directive-review` is deferred to PR-time (once, via the gauntlet). | `skill-authoring-principles` + `directive-review` reference files + the owner's harness research |
| **doc** | native | **Deterministic self-check only** (NO per-task adversarial agent dispatch), adapted for prose: structural/frontmatter validity IF the doc has frontmatter; no forbidden patterns (grep) — local absolute paths, `Co-Authored-By`, individual names where a team/CODEOWNERS pointer belongs; internal-reference accuracy (cross-references/links resolve to real sections/files). Full `doc-review` is deferred to PR-time (once, via the gauntlet). | `doc-patterns` (see `engines.md`) |

## Three-layer verification (why tool-authoring/doc are NOT per-task adversarial)

1. **Authoring-time** (injected into the brief): the *principles* above — so the artifact is written to spec the first time. ~free.
2. **Per-task** (Crafter self-check + bounded Inspector read): deterministic checks only, per the table. Cheap.
3. **PR-time** (once, on the whole diff, outside the Kiln): full `skill-audit`/`directive-review`/`doc-review` via `/gauntlet`. The one heavyweight pass.

Running the heavyweight finder+validator skills per task would duplicate the PR gauntlet N times — forbidden.
