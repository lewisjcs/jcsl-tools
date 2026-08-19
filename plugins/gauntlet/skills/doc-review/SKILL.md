---
name: doc-review
description: Use when reviewing a markdown documentation artifact (RFC, ADR, README, AGENTS.md, design doc, ownership doc, or any structured prose for an internal audience) for evergreen-ness, personal tooling leaks, individual-name owner pointers, ADR filename convention, AGENTS.md bloat, internal consistency, accuracy of references, or voice/writing-style alignment. Trigger phrases include "review this doc", "is this doc clean", "doc review", "what's wrong with this RFC", "audit this README", "check this AGENTS.md".
argument-hint: "[<path-to-doc.md>]"
---

# Doc Review

Apply 4 doc-review lenses (Memory-encoded rules with 6 sub-lenses, Internal consistency, Accuracy of references, Voice and writing-style) to a markdown documentation artifact via opposed-framing agents. Find → Validate → Adjudicate.

Hidden assumptions lens (per master spec §3.5 lens 5) fires only when doc-review is invoked from gauntlet (Phase 7 §9 resolution, 2026-05-27). gauntlet additionally dispatches `adversarial-review` with family `doc-text` and relabels its findings to `doc-review / Hidden assumptions` per the cross-skill canonical-lens mapping. When doc-review runs standalone (direct invocation), Hidden-assumptions findings are NOT produced — the lens requires gauntlet's separate adversarial-review dispatch to fire.

## Usage

```
/doc-review path/to/doc.md                    — review a specific doc
/doc-review                                   — review the most recently modified .md doc in the current repo
```

The skill is also invoked by `gauntlet` when the gauntlet orchestrator runs a doc review pass.

**When NOT to use:** Code review (use `/gauntlet` for multi-skill review or `/code-quality-audit` for convention-only audit). Plan review (use `/plan-review`). Adversarial pressure-testing of code changes (use `/adversarial-review`). Skill markdown review (use `/skill-audit`). Brainstorming or designing a doc (use `superpowers:brainstorming` to design the doc, then run doc-review on the result).

## Invocation Context Detection

| Context | Doc source | Output target |
|---|---|---|
| Called from `/gauntlet` (artifact contains a doc-shaped `.md`) | Already in context — full file content (Finder needs the whole doc for Accuracy of references and Internal consistency lenses) | Surviving findings feed into the gauntlet report's Findings section |
| Standalone with `<path>` | Read from path | Standalone report |
| Standalone no args | Most recently modified `.md` doc in `$PWD`, excluding files the doc-finder would reject as non-docs: `.plan.md` files and `SKILL.md` files. When `$PWD` is the jcslOS workspace root, also exclude its `README.md`; when `$PWD` is inside a cloned repo, `README.md` is a valid target and is NOT excluded. | Standalone report |
| Called from `gauntlet` orchestrator | Doc content passed in invocation prompt | Returns surviving findings JSON for orchestrator aggregation |
| Called from `/create-pr` | Not triggered in v1 — doc review runs only on artifacts dispatched via `/gauntlet`, not on PR creation. May revisit if doc findings should appear in PR descriptions at creation time. | (none) |

The gauntlet-orchestrator output JSON has the same schema as the Phase 3 adjudicated findings array: each entry has the 10 fields per master spec §4.1 (`skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation`), with `verdict = "survives"` only (disproved findings already filtered) **and `confidence ≥ 70`** (low-confidence findings already dropped). The 70-confidence threshold is the Phase 3 cutoff (see Phase 3 step 2 below). Phase 7 should NOT re-apply a confidence filter to findings received from doc-review since the filter has already been applied. Disproved findings are NOT included in the returned JSON — they remain internal to the doc-review execution and are not propagated to the gauntlet orchestrator. If Phase 7 needs disproved-finding visibility, it should invoke doc-review in standalone mode (which renders them in a `<details>` block).

---

## Checklist

Create a task for each item below (a `TaskCreate` call each) and complete them in order — set each to `in_progress` before starting and `completed` (via `TaskUpdate`) when done. Do not start a phase while the previous one is incomplete.

1. **Phase 1** — Dispatch `doc-finder` and verify JSON shape
2. **Phase 2** — Dispatch `doc-validator` with verbatim findings and verify verdicts
3. **Phase 3** — Adjudicate in main context, verify filtering reduced count, emit report

<HARD-GATE>
Each phase runs in its own subagent dispatch (Phases 1 and 2) or main context (Phase 3). Do NOT collapse phases into a single Agent call. Do NOT skip Phase 2 by adjudicating Finder output directly. The three phases exist because Finder, Validator, and Adjudicator have opposed framings — collapsing them defeats the skill.
</HARD-GATE>

---

## Phase 1 — Dispatch Finder

Dispatch the `doc-finder` subagent (Agent tool, `subagent_type: gauntlet:doc-finder`) with the full doc content in the prompt body. The agent's senior-engineer persona, 4-lens vocabulary (with 6 Memory-rules sub-lenses), and emission contract are set by its system prompt; the dispatch prompt only supplies the doc content and any context (e.g., the doc's repo-relative path, surrounding repo signals if known).

**If the dispatch fails with `Agent type 'gauntlet:doc-finder' not found`:** the runtime agent registry has not picked up the plugin's agents. Run `/reload-plugins` (or restart the session) to refresh the registry, then retry with the `gauntlet:`-prefixed name. The same recovery applies to Phase 2's `gauntlet:doc-validator` dispatch.

**Verify before Phase 2:** Parse Finder output as JSON. Confirm it is an array (possibly empty). Each entry MUST contain: `skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation` (10 fields per master spec §4.1). The `lens` value MUST start with `doc-review / ` exactly and MUST be one of the 10 canonical labels per §3.5 lines 219-228 (with the U+2014 em-dash separator on Memory-rules sub-lenses). The `location` value MUST be a bare narrative section reference (not a file:line reference, not backtick-wrapped — per master spec §4.1.1). If parse fails, schema mismatches, or emission contract is violated (especially: hyphen-minus or en-dash instead of em-dash on Memory-rules sub-lenses), re-dispatch Finder once with the contract spelled out (per master spec §4.1.1 retry policy). If the second pass still fails, emit a brief "Finder output malformed" report and exit.

If Finder returns an empty array (no findings), emit "No doc-review findings against the 4 active lenses." and skip Phase 2.

---

## Phase 2 — Dispatch Validator

Dispatch the `doc-validator` subagent (Agent tool, `subagent_type: gauntlet:doc-validator`) with:

1. The full doc content
2. The Finder's raw findings array
3. The doc's repo-relative path (so the Validator can verify surrounding repo context for the ADR filename convention sub-lens)

Pass the Finder JSON verbatim — do not summarize, paraphrase, or pre-filter it.

**Verify before Phase 3:** Parse Validator output as JSON. Confirm one entry per Finder finding (count must match), each preserving the input fields plus `verdict` ∈ {survives, disproved}, `evidence`, `confidence` ∈ [0,100]. If counts mismatch, re-dispatch Validator with the missing findings. If the Validator emits a non-canonical verdict string (e.g., `false_positive`, `valid`, `confirmed`, `refuted`), re-dispatch once with the contract spelled out (per master spec §4.1.1 retry policy). Do not advance to Phase 3 until verification passes; if the second pass still fails, emit the report noting which findings could not be validated and exclude unvalidated entries from Phase 3.

---

## Phase 3 — Adjudicate

In the main context (no subagent), process the validated findings:

1. **Drop** findings where `verdict = disproved`
2. **Drop** findings where `verdict = survives` but `confidence < 70`
3. **Deduplicate** overlapping findings — defined as: same `location` AND same `lens`. Keep the higher-confidence version. Two findings at the same location but under different lenses (independent defects per doc-finder's "one finding per root cause" rule) are NOT duplicates and MUST both survive.
4. **Rank** surviving findings by severity × confidence

**Verify before report — single Validator pass is the default; escalate only on a pinned trigger.** The Validator runs exactly once (Phase 2). Re-dispatch it for a **second and final** pass IFF, after the first pass, EITHER pinned condition holds:
1. **Rubber-stamp guard** — the Validator disproved **zero** of the Finder's findings (it killed nothing).
2. **High-stakes borderline** — at least one **surviving** finding has `severity = "High"` AND `confidence ∈ [70, 78]` (a candidate blocker kept on borderline confidence — the band where a second pass can ground it to `confidence ≥ 85` or disprove it).

On re-dispatch: apply disproof strategies 2 (personal-OS-workspace check) and 3 (speculative-vs-grounded check) from doc-validator more aggressively, and verify that code-quality-standards false-positive rules and the doc-as-living-artifact rule were applied to any findings under correctness, accuracy, or maintainability lenses; AND for any High-stakes-borderline finding, instruct the Validator to re-ground its confidence against the artifact (push to a confident `≥ 85` survive with cited evidence, or disprove). Cap at **one** extra pass even if both conditions fire; never loop. If after the second pass a finding is still High at `confidence ∈ [70, 78]`, accept it and note: "high-stakes borderline finding survived a second Validator pass at confidence N." If the rubber-stamp guard fired and the second pass still drops zero, accept the survivors and note: "no false-positive filter triggered — every Finder finding survived two Validator passes."

---

## Output

Format based on invocation context:

**Standalone:** Full report with surviving findings (location, claim, evidence, severity, recommendation for each). Include a collapsed `<details>` section of disproved findings for transparency.

**From `/gauntlet`:** Surviving findings feed directly into the gauntlet report's Findings section. No separate report.

**From `gauntlet` orchestrator:** Return surviving findings as a JSON array for orchestrator aggregation.

## Sibling Skills

- `doc-patterns` — substantive lens definitions and Contentful house rules. Loaded by both Finder and Validator at dispatch time.
- `code-quality-standards` — defensive-code anti-patterns. Loaded by the Validator for false-positive filtering.
- `adversarial-review` — pressure-tests structural assumptions in code diffs. Different scope; doc-review checks doc correctness, adversarial-review checks code correctness. Hidden assumptions lens will invoke this in Phase 7+.
- `security-gauntlet` — security review skill, also Finder/Validator pattern. Sibling within the gauntlet review-skill family.
- `plan-review` — plan-quality review skill, also Finder/Validator pattern. Sibling within the gauntlet review-skill family.
- (review-pr archived 2026-05-27 per Phase 9 — see `.claude/_archive/skills/review-pr/`. doc-review is now invoked by gauntlet, not review-pr.)
- `gauntlet` — Phase 7 orchestrator; calls doc-review for the doc-quality pass.
