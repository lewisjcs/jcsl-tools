# Crafter Implementation by Engine

The conductor names the `engine:` bound for this run. Apply that engine's `implement` +
`verify` steps (the contract is in `${CLAUDE_PLUGIN_ROOT}/skills/fire/engines.md`). Do not
apply a discipline the bound engine does not call for.

## engine: compounds  (code / — dormant: mcp-agent-app, infra)

1. Read the `### Enriched context` in your brief — the Planner already generated the
   design patterns, testing frameworks, and reference architecture for this task. This is
   your implementation guide; do not re-generate it.
2. Call `implement_task` for this task so Compounds runs its own implementation+test loop.
3. If the brief's `test strategy:` names an E2E/frontend layer, additionally run the
   framework the brief points to before reporting.
4. Confirm the test suite is green (`verify`). Commit (Conventional Commits; include the
   run's key in the title only if the entry supplied one). Write `report-N.md`; list the
   tests Compounds produced under `## Tests Written`.

There is NO mandatory red-green pre-cycle on this engine — red-green is dropped as a hard
Kiln invariant (design D3); the accuracy guardrail is the Inspector's test-adequacy review.

## engine: native  (tool-authoring, doc)

Authoring a skill/agent/directive/doc — there is no Compounds call and no red-green unit
cycle. Author grounded in the brief's injected standards, then run the **deterministic
self-check** (`verify`):

1. **Frontmatter validity:** the file's YAML frontmatter parses and has the required keys
   for its type (skills: `name` + `description`; agents: `name` + `description` + `tools`).
2. **Trigger phrases:** for a skill/agent `description`, confirm concrete trigger phrasing
   (when-to-use language), not just a title.
3. **Forbidden patterns (grep):** no local absolute paths, no `Co-Authored-By`, no individual
   names where a team/CODEOWNERS pointer belongs, no personal-only tooling references.
4. **Calibration fixtures:** if the artifact ships gold scenarios/fixtures, run them and
   confirm green.
5. Do NOT dispatch `skill-audit`/`directive-review` here — that is the PR-time gauntlet pass
   (once, outside the Kiln).
6. Commit (Conventional Commits; run key in title only if supplied). Write `report-N.md` —
   list the self-checks run under `## Tests Written` (e.g. "frontmatter parse: ok",
   "trigger-phrase check: ok") so the Inspector's adequacy check has inputs.
