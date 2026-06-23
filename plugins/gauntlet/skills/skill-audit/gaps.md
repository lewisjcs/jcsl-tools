# Skill Audit — Layer 3: Gap Heuristics

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then check each skill for missing elements that reduce effectiveness.

---

## Heuristics

| Gap | How to Detect | Impact |
|-----|---------------|--------|
| Missing trigger phrases in description | Description is <50 chars or doesn't start with "Use when" | Skill won't be auto-invoked |
| No verification step | Skill has instructions but no "confirm X before proceeding" | Agent may silently fail |
| No "when NOT to use" | Skill has "when to use" but no exclusion criteria | Over-invocation, wrong context |
| No error handling guidance | Skill describes happy path only | Agent stuck on first failure |
| Missing `argument-hint` | Skill accepts arguments but no hint for the user | User doesn't know what to pass |
| Oversized skill | `wc -l SKILL.md` > 500 lines OR body > ~5k tokens (the vendor budget — NOT a word count). Frequently-loaded/auto-triggered skills should be far tighter; split reference material into on-demand files (one level deep) when approaching the limit. | Context bloat, slower invocation |
| No evaluation baseline | Skill ships without evidence it beats Claude-without-the-skill on representative tasks (most skills yield zero improvement per the benchmarks). | Skill may add tokens with no measurable benefit |
| Duplicate content | Same guidance exists in another skill or CLAUDE.md | Maintenance burden, drift risk |
| No sibling cross-references | Related evaluation/process skills exist but aren't signposted | Model picks one based on description-match, missing the others |
| Missing workflow discipline scaffold | Skill has 2+ subagent dispatches OR 3+ ordered steps not enforced by file/output structure, but lacks `<HARD-GATE>` block or task-list instruction (`TaskCreate`/`TaskUpdate`). See `skill-authoring-principles` "Workflow Discipline: Hardgates and task lists" for criteria. | Phase collapse — model treats sequential phases as one step, skipping evaluators or verifiers |
| Review skill lacks calibration test set | Skill is in the review-skill family (Finder/Validator pattern, evaluative orchestrator, or any skill whose primary output is findings/verdicts) and has no associated `test-dataset/` directory or `thresholds.yaml`. Examples: `adversarial-review`, `security-review`, `plan-review`, `doc-review`, `full-review`, `skill-audit`. The shared dataset for the gauntlet skill family lives at `projects/active/gauntlet/test-dataset/`. | Reviewer correctness is unverified. Findings ship without empirical validation against known-good/known-bad fixtures. Eval discipline (per Mike Kivisto's mandate) requires calibration. |

Note on "Duplicate content": some duplication is *correct* validation at a layer boundary (e.g., a SKILL.md "When NOT to use" section duplicating an agent.md one is fine if the SKILL.md fires before the agent.md loads). Only flag duplication where both copies serve the same load-time role.

---

## Output Shape

For each gap, capture:

| Field | Content |
|-------|---------|
| `gap` | What's missing (matches a row from the heuristics table) |
| `impact` | Why it matters for skill effectiveness in this specific skill |
| `proposed-fix` | Concrete edit, not vague guidance. Cite the exact lines or sections to add. |
