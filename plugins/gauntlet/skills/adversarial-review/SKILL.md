---
name: adversarial-review
description: Use when pressure-testing code changes for hidden assumptions, failure modes, and structural risks that standard review misses. Trigger phrases include "adversarial review", "pressure test this", "how could this break", "what am I missing", "stress test this code", "break this", "find the flaws".
argument-hint: "[<repo> <pr-number>]"
---

# Adversarial Review

Pressure-test code changes for hidden assumptions, failure modes, and structural risks. Find → Validate → Adjudicate.

## Usage

```
/adversarial-review contentful.js 1234   — PR mode
/adversarial-review                       — Local mode (diff against base branch)
```

**When NOT to use:** Multi-skill review (use `/gauntlet`). Convention/style audit (use `/code-quality-audit`). Security audit (use `/security-gauntlet`).

## Invocation Context Detection

| Context | Diff source | Output target |
|---|---|---|
| Called from `/gauntlet` | Already in context | Surviving findings feed into the gauntlet report's Findings section |
| Called from `/create-pr` | Already in context | High-severity findings → `## Adversarial Findings` in PR body |
| Standalone with `<repo> <pr-number>` | `gh pr diff <number> --repo contentful/<repo>` | Standalone report |
| Standalone no args | `git diff main...HEAD` (fall back to `master` only if `main` does not exist) | Standalone report |

---

## Checklist

Create a task for each item below (a `TaskCreate` call each) and complete them in order — set each to `in_progress` before starting and `completed` (via `TaskUpdate`) when done. Do not start a phase while the previous one is incomplete.

1. **Phase 1** — Dispatch `adversarial-finder` and verify JSON shape
2. **Phase 2** — Dispatch `adversarial-validator` with verbatim findings and verify verdicts
3. **Phase 3** — Adjudicate in main context, verify filtering reduced count, emit report

<HARD-GATE>
Each phase runs in its own subagent dispatch (Phases 1 and 2) or main context (Phase 3). Do NOT collapse phases into a single Agent call. Do NOT skip Phase 2 by adjudicating Finder output directly. The three phases exist because Finder, Validator, and Adjudicator have opposed framings — collapsing them defeats the skill.
</HARD-GATE>

---

## Phase 1 — Dispatch Finder

Dispatch the `adversarial-finder` subagent (Agent tool, `subagent_type: gauntlet:adversarial-finder`) with the full artifact in the prompt body. The agent's hostile-engineer persona is set by its system prompt; the dispatch prompt supplies the artifact content, an explicit artifact-type marker, and any context the Finder needs to navigate the repo.

**Typed-input dispatch format (Phase 7, 2026-05-27):** When dispatching Finder against non-code artifacts, include an artifact-type marker on its own line in the dispatch prompt body:

```
Artifact type: code-diff
```
```
Artifact type: plan-text
```
```
Artifact type: doc-text
```

The marker line MUST appear on its own line (no surrounding text on the same line). Place it near the top of the dispatch body, after any brief framing sentence and before the artifact content itself. The Finder's system prompt parses this marker with a regex anchor (`^Artifact type: (code-diff|plan-text|doc-text)\s*$`) and selects the corresponding overlay. If no marker is present, the Finder defaults to the `code-diff` overlay (legacy behavior preserved).

**Dispatch examples by context:**
- Called standalone on a code diff → omit the marker (legacy behavior) or include `Artifact type: code-diff`
- Called from gauntlet on a plan → include `Artifact type: plan-text` before the plan content
- Called from gauntlet on a doc → include `Artifact type: doc-text` before the doc content

**Verify before Phase 2:** Parse Finder output as JSON. Confirm it is an array with 3-10 entries, each containing exactly these keys: `lens`, `location`, `claim`, `evidence`, `severity`. If parse fails or schema mismatches, re-dispatch Finder once with the schema spelled out. If a second pass still returns fewer than 3 findings, the diff is too small for adversarial review — emit a brief "no significant findings" report and exit. Do not advance to Phase 2 with an empty findings array.

---

## Phase 2 — Dispatch Validator

Dispatch the `adversarial-validator` subagent (Agent tool, `subagent_type: gauntlet:adversarial-validator`) with:

1. The full diff
2. The Finder's raw findings array

Pass the Finder JSON verbatim — do not summarize, paraphrase, or pre-filter it. The Validator's defense-attorney persona and false-positive rules are set by its system prompt, including the requirement to read `${CLAUDE_PLUGIN_ROOT}/skills/code-quality-standards/SKILL.md` before evaluating.

**Verify before Phase 3:** Parse Validator output as JSON. Confirm one entry per Finder finding (count must match), each containing `verdict` ∈ {survives, disproved}, `evidence`, `confidence` ∈ [0,100]. If counts mismatch, re-dispatch Validator with the missing findings. Do not advance to Phase 3 until verification passes.

---

## Phase 3 — Adjudicate

In the main context (no subagent), process the validated findings:

1. **Drop** findings where `verdict = disproved`
2. **Drop** findings where `verdict = survives` but `confidence < 70`
3. **Deduplicate** overlapping findings (keep the higher-confidence version)
4. **Rank** surviving findings by severity × confidence

**Verify before report — single Validator pass is the default; escalate only on a pinned trigger.** The Validator runs exactly once (Phase 2). Re-dispatch it for a **second and final** pass IFF, after the first pass, EITHER pinned condition holds:
1. **Rubber-stamp guard** — zero findings were dropped (neither disproved nor low-confidence) — nothing was filtered out.
2. **High-stakes borderline** — at least one **surviving** finding has `severity = "High"` AND `confidence ∈ [70, 78]` (a candidate blocker kept on borderline confidence — the band where a second pass can ground it to `confidence ≥ 85` or disprove it).

On re-dispatch: apply false-positive rules from code-quality-standards more aggressively; AND for any High-stakes-borderline finding, instruct the Validator to re-ground its confidence against the artifact (push to a confident `≥ 85` survive with cited evidence, or disprove). Cap at **one** extra pass even if both conditions fire; never loop. If after the second pass a finding is still High at `confidence ∈ [70, 78]`, accept it and note: "high-stakes borderline finding survived a second Validator pass at confidence N." If the rubber-stamp guard fired and the second pass still drops zero, accept the survivors and note: "no false-positive filter triggered — every Finder finding survived two Validator passes."

---

## Output

Format based on invocation context:

**Standalone:** Full report with surviving findings (location, claim, evidence for each). Include a collapsed `<details>` section of disproved findings for transparency.

**From `/gauntlet`:** Surviving findings feed directly into the gauntlet report's Findings section. No separate report.

**From `/create-pr`:** High-severity findings → `## Adversarial Findings` section in the PR body. Medium and low severity → mention count only (e.g., "3 medium-severity findings noted during adversarial review"). Advisory only — never blocking.

## Sibling Skills

- `code-quality-standards` — pattern alignment and defensive-code anti-patterns. Consulted by the Validator (Phase 2) for false-positive filtering.
- `skill-audit` — evaluates SKILL.md files (not code). Different domain; use when reviewing skills.
