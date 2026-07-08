# Crafter Verification by Scenario

Your brief (`brief-N.md`) names a `scenario:`. Apply that scenario's discipline. Do not
apply a discipline the scenario does not call for (e.g. do not force red-green TDD onto prose).

## scenario: code

1. **MANDATORY:** invoke `superpowers:test-driven-development` via the Skill tool before any implementation code.
2. Write the failing test → run it, confirm it fails for the right reason → minimal implementation → run, confirm green → refactor, keep green.
3. If the brief's `test strategy:` names an E2E/frontend layer, additionally run the framework the brief points to before reporting.
4. Commit (Conventional Commits; include the run's key in the title only if the entry supplied one). Write `report-N.md`.

## scenario: tool-authoring

Authoring a skill/agent/directive — there is no red-green unit cycle. Run the **deterministic self-check**:

1. **Frontmatter validity:** the file's YAML frontmatter parses and has the required keys for its type
   (skills: `name` + `description`; agents: `name` + `description` + `tools`).
2. **Trigger phrases:** for a skill/agent `description`, confirm it contains concrete trigger phrasing
   (when-to-use language), not just a title.
3. **Forbidden patterns (grep):** no local absolute paths, no `Co-Authored-By`, no individual names where a
   team/CODEOWNERS pointer belongs, no personal-only tooling references.
4. **Calibration fixtures:** if the artifact ships gold scenarios/fixtures, run them and confirm green.
5. Do NOT dispatch `skill-audit`/`directive-review` here — that is the PR-time gauntlet pass (once, outside the Kiln).
6. Commit (Conventional Commits; include the run's key in the title only if the entry supplied one). Write `report-N.md` — list the self-checks run under `## Tests Written`
   (e.g. "frontmatter parse: ok", "trigger-phrase check: ok") so the Inspector's test-first check is satisfied.
