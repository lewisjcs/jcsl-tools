---
name: plan-review
description: Use when reviewing a plan markdown artifact (typically `.plan.md` under `projects/active/<feature>/plans/` or `docs/superpowers/plans/`) for EARS compliance, internal consistency, ambiguity, scope, or test strategy adequacy. Trigger phrases include "review this plan", "is this plan ready", "plan review", "what's wrong with this plan", "does this plan have issues".
argument-hint: "[<path-to-plan.md>]"
---

# Plan Review

Apply 5 plan-review lenses (EARS compliance, Internal consistency, Ambiguity, Scope, Test strategy adequacy) to a plan markdown artifact via opposed-framing agents. Find → Validate → Adjudicate.

Architectural-risk lens (per master spec §3.4 lens 5) fires only when plan-review is invoked from gauntlet (Phase 7 §9 resolution, 2026-05-27). gauntlet additionally dispatches `adversarial-review` with family `plan-text` and relabels its findings to `plan-review / Architectural risk` per the cross-skill canonical-lens mapping. When plan-review runs standalone (direct invocation), Architectural-risk findings are NOT produced — the lens requires gauntlet's separate adversarial-review dispatch to fire.

## Usage

```
/plan-review path/to/feature/plans/01-feature.plan.md   — review a specific plan file
/plan-review                                            — review the most recently modified .plan.md in projects/active/
```

The skill is also invoked by `gauntlet` when the gauntlet orchestrator runs a plan review pass.

**When NOT to use:** Code review (use `/gauntlet` for multi-skill review or `/code-quality-audit` for convention-only audit). Doc review (use `/doc-review`). Adversarial pressure-testing of code changes (use `/adversarial-review`). Brainstorming or designing a plan (use `superpowers:writing-plans` to create the plan, then run plan-review on the result).

## Invocation Context Detection

| Context | Plan source | Output target |
|---|---|---|
| Called from `/gauntlet` (PR or local artifact contains a `.plan.md`) | Already in context | Surviving findings feed into the gauntlet report's Findings section |
| Standalone with `<path>` | Read from path | Standalone report |
| Standalone no args | Most recently modified `.plan.md` under `projects/active/` | Standalone report |
| Called from `gauntlet` orchestrator | Plan content passed in invocation prompt | Returns surviving findings JSON for orchestrator aggregation |

The gauntlet-orchestrator output JSON has the same schema as the Phase 3 adjudicated findings array: each entry has the 10 fields per master spec §4.1 (`skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation`), with `verdict = "survives"` only (disproved findings already filtered) **and `confidence ≥ 70`** (low-confidence findings already dropped). The 70-confidence threshold is the Phase 3 cutoff (see Phase 3 step 2 below). Phase 7 can rank/dedupe these alongside findings from sibling skills (`security-gauntlet`, `doc-review`) using the shared schema; Phase 7 should NOT re-apply a confidence filter to findings received from plan-review since the filter has already been applied.

---

## Checklist

Create a task for each item below (a `TaskCreate` call each) and complete them in order — set each to `in_progress` before starting and `completed` (via `TaskUpdate`) when done. Do not start a phase while the previous one is incomplete.

1. **Phase 1** — Dispatch `plan-finder` and verify JSON shape
2. **Phase 2** — Dispatch `plan-validator` with verbatim findings and verify verdicts
3. **Phase 3** — Adjudicate in main context, verify filtering reduced count, emit report

<HARD-GATE>
Each phase runs in its own subagent dispatch (Phases 1 and 2) or main context (Phase 3). Do NOT collapse phases into a single Agent call. Do NOT skip Phase 2 by adjudicating Finder output directly. The three phases exist because Finder, Validator, and Adjudicator have opposed framings — collapsing them defeats the skill.
</HARD-GATE>

---

## Phase 1 — Dispatch Finder

Dispatch the `plan-finder` subagent (Agent tool, `subagent_type: gauntlet:plan-finder`) with the full plan content in the prompt body. The agent's engineering-manager persona, 5-lens vocabulary, and emission contract are set by its system prompt; the dispatch prompt only supplies the plan content and any context.

**Verify before Phase 2:** Parse Finder output as JSON. Confirm it is an array (possibly empty). Each entry MUST contain: `skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation` (10 fields per master spec §4.1). The `lens` value MUST start with `plan-review / ` exactly. The `location` value MUST be a bare narrative section reference (not a file:line reference, not backtick-wrapped — per master spec §4.1.1). If parse fails, schema mismatches, or emission contract is violated, re-dispatch Finder once with the contract spelled out (per master spec §4.1.1 retry policy). If the second pass still fails, emit a brief "Finder output malformed" report and exit.

If Finder returns an empty array (no findings), emit "No plan-review findings against the 5 lenses." and skip Phase 2.

---

## Phase 2 — Dispatch Validator

Dispatch the `plan-validator` subagent (Agent tool, `subagent_type: gauntlet:plan-validator`) with:

1. The full plan content
2. The Finder's raw findings array

Pass the Finder JSON verbatim — do not summarize, paraphrase, or pre-filter it.

**Verify before Phase 3:** Parse Validator output as JSON. Confirm one entry per Finder finding (count must match), each preserving the input fields plus `verdict` ∈ {survives, disproved}, `evidence`, `confidence` ∈ [0,100]. If counts mismatch, re-dispatch Validator with the missing findings. If the Validator emits a non-canonical verdict string (e.g., `false_positive`, `valid`, `confirmed`), re-dispatch once with the contract spelled out (per master spec §4.1.1 retry policy). Do not advance to Phase 3 until verification passes; if the second pass still fails, emit the report noting which findings could not be validated and exclude unvalidated entries from Phase 3.

---

## Phase 3 — Adjudicate

In the main context (no subagent), process the validated findings:

1. **Drop** findings where `verdict = disproved`
2. **Drop** findings where `verdict = survives` but `confidence < 70`
3. **Deduplicate** overlapping findings (keep the higher-confidence version)
4. **Rank** surviving findings by severity × confidence

**Verify before report — single Validator pass is the default; escalate only on a pinned trigger.** The Validator runs exactly once (Phase 2). Re-dispatch it for a **second and final** pass IFF, after the first pass, EITHER pinned condition holds:
1. **Rubber-stamp guard** — the Validator disproved **zero** of the Finder's findings (it killed nothing).
2. **High-stakes borderline** — at least one **surviving** finding has `severity = "High"` AND `confidence ∈ [70, 78]` (a candidate blocker kept on borderline confidence — the band where a second pass can ground it to `confidence ≥ 85` or disprove it).

On re-dispatch: apply false-positive rules from code-quality-standards and plan-review false-positive rules more aggressively; AND for any High-stakes-borderline finding, instruct the Validator to re-ground its confidence against the artifact (push to a confident `≥ 85` survive with cited evidence, or disprove). Cap at **one** extra pass even if both conditions fire; never loop. If after the second pass a finding is still High at `confidence ∈ [70, 78]`, accept it and note: "high-stakes borderline finding survived a second Validator pass at confidence N." If the rubber-stamp guard fired and the second pass still drops zero, accept the survivors and note: "no false-positive filter triggered — every Finder finding survived two Validator passes."

---

## Output

Format based on invocation context:

**Standalone:** Full report with surviving findings (location, claim, evidence, severity, recommendation for each). Include a collapsed `<details>` section of disproved findings for transparency.

**From `/gauntlet`:** Surviving findings feed directly into the gauntlet report's Findings section. No separate report.

**From `gauntlet` orchestrator:** Return surviving findings as a JSON array for orchestrator aggregation.

## Sibling Skills

- `code-quality-standards` — defensive-code anti-patterns. Loaded by the Validator for false-positive filtering.
- `adversarial-review` — pressure-tests structural assumptions in code diffs. Different scope; plan-review checks plan correctness, adversarial-review checks code correctness.
- `security-gauntlet` — security review skill, also Finder/Validator pattern. Sibling within the gauntlet review-skill family.
- `superpowers:writing-plans` — authors plans. plan-review is the QA pass on plans authored by writing-plans.
- (review-pr archived 2026-05-27 per Phase 9 — see `.claude/_archive/skills/review-pr/`. plan-review is now invoked by gauntlet, not review-pr.)
- `gauntlet` — Phase 7 orchestrator; calls plan-review for the plan-quality pass.
