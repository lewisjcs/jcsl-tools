---
name: security-gauntlet
description: Use when reviewing an artifact (code diff, plan, doc, or skill) for security concerns; threat-modeling a change; deciding whether a control is justified; or asked "is this safe", "any security issues", "how could this be exploited". Trigger phrases include "security gauntlet", "security review", "review for security", "is there a vulnerability", "secret leak", "auth bypass".
argument-hint: "[<repo> <pr-number>]"
---

# Security Gauntlet

Apply the 7 security-principles lenses to an artifact (code diff, plan text, doc text, or skill content per master spec §3.3) via opposed-framing agents. Find → Validate → Adjudicate.

**Trust-model scoping:** findings premised on a less-privileged second caller are only valid when such a caller exists in the artifact's threat model. For confirmed single-user / local-trust artifacts (no second principal less trusted than the author can reach the code path), the security-finder suppresses findings that presuppose one — see the trust-model rule in `security-finder.md`. When the artifact's trust context is unstated or ambiguous, the default posture is multi-caller; no findings are suppressed.

This skill is part of the gauntlet skill family. It is named `security-gauntlet` (not `security-review`) to avoid collision with Claude Code's built-in `/security-review` command — that built-in is a generic git-diff security pass with different architecture and no calibration discipline. The gauntlet variant is calibrated against the test dataset at `projects/active/gauntlet/test-dataset/` per master spec §6.

## Usage

```
/security-gauntlet contentful.js 1234   — PR mode (code diff)
/security-gauntlet                       — Local mode (diff against base branch)
```

The skill is also invoked by `/plan-gauntlet`, `/doc-gauntlet`, and `gauntlet` when those skills want a security pass over a non-code artifact (a plan, a doc, a skill).

**When NOT to use:** General code review (use `/gauntlet` for multi-skill review or `/code-quality-audit` for convention-only audit). Adversarial pressure-testing of structural assumptions (use `/adversarial-review`). Generic security pass on git changes without calibration (use Claude Code's built-in `/security-review`). Code or content that has not changed (security review is diff-scoped or change-scoped, not full-codebase audit).

## Invocation Context Detection

| Context | Diff source | Output target |
|---|---|---|
| Called from `/gauntlet` | Already in context | Surviving findings feed into the gauntlet report's Findings section |
| Called from `/create-pr` | Already in context | High-severity findings → `## Security Findings` in PR body |
| Called from `gauntlet` orchestrator | Diff or non-code artifact passed in invocation prompt | Returns surviving findings JSON for orchestrator aggregation |
| Standalone with `<repo> <pr-number>` | `gh pr diff <number> --repo contentful/<repo>` | Standalone report |
| Standalone no args | `git diff main...HEAD` (fall back to `master` only if `main` does not exist) | Standalone report |

The gauntlet-orchestrator output JSON is a findings array per master spec §4.1's canonical 10-field schema (`skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation`), with `verdict = "survives"` only (disproved findings already filtered) AND `confidence ≥ 70` (low-confidence findings already dropped). Phase 7's gauntlet adjudicator should NOT re-apply a confidence filter to findings received from security-gauntlet since the filter has already been applied. Disproved findings are NOT included in the returned JSON; they remain internal to security-gauntlet's execution.

---

## Checklist

Create a task for each item below (a `TaskCreate` call each) and complete them in order — set each to `in_progress` before starting and `completed` (via `TaskUpdate`) when done. Do not start a phase while the previous one is incomplete.

1. **Phase 1** — Dispatch `security-finder` and verify JSON shape
2. **Phase 2** — Dispatch `security-validator` with verbatim findings and verify verdicts
3. **Phase 3** — Adjudicate in main context, verify filtering reduced count, emit report

<HARD-GATE>
Each phase runs in its own subagent dispatch (Phases 1 and 2) or main context (Phase 3). Do NOT collapse phases into a single Agent call. Do NOT skip Phase 2 by adjudicating Finder output directly. The three phases exist because Finder, Validator, and Adjudicator have opposed framings — collapsing them defeats the skill.
</HARD-GATE>

---

## Phase 1 — Dispatch Finder

Dispatch the `security-finder` subagent (Agent tool, `subagent_type: gauntlet:security-finder`) with the full artifact (diff or text) in the prompt body. The agent's security-engineer persona, 7-lens vocabulary, and emission contract are set by its system prompt; the dispatch prompt only supplies the artifact and any context the Finder needs to navigate the repo.

**Verify before Phase 2:** Parse Finder output as JSON. Confirm it is an array (possibly empty). Each entry MUST contain: `skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation` (10 fields per master spec §4.1). The `lens` value MUST start with `security-gauntlet / ` exactly. The `location` value MUST be `<file-path>:<line-number>` for code findings, or a backtick-free narrative section reference for plan/doc/skill text (per master spec §4.1.1). If parse fails, schema mismatches, or emission contract is violated, re-dispatch Finder once with the contract spelled out. If the second pass still fails, emit a brief "Finder output malformed" report and exit. Do not advance to Phase 2 with malformed data.

If Finder returns an empty array (no findings), advance directly to report emission as "No security findings against the 7 lenses." Skip Phase 2.

---

## Phase 2 — Dispatch Validator

Dispatch the `security-validator` subagent (Agent tool, `subagent_type: gauntlet:security-validator`) with:

1. The full diff
2. The Finder's raw findings array

Pass the Finder JSON verbatim — do not summarize, paraphrase, or pre-filter it.

**Verify before Phase 3:** Parse Validator output as JSON. Confirm one entry per Finder finding (count must match), each preserving the input fields plus `verdict` ∈ {survives, disproved}, `evidence`, `confidence` ∈ [0,100]. If counts mismatch, re-dispatch Validator with the missing findings. Do not advance to Phase 3 until verification passes.

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

On re-dispatch: apply false-positive rules from code-quality-standards and security-principles more aggressively; AND for any High-stakes-borderline finding, instruct the Validator to re-ground its confidence against the artifact (push to a confident `≥ 85` survive with cited evidence, or disprove). Cap at **one** extra pass even if both conditions fire; never loop. If after the second pass a finding is still High at `confidence ∈ [70, 78]`, accept it and note: "high-stakes borderline finding survived a second Validator pass at confidence N." If the rubber-stamp guard fired and the second pass still drops zero, accept the survivors and note: "no false-positive filter triggered — every Finder finding survived two Validator passes."

---

## Output

Format based on invocation context:

**Standalone:** Full report with surviving findings (location, claim, evidence, severity, recommendation for each). Include a collapsed `<details>` section of disproved findings for transparency.

**From `/gauntlet`:** Surviving findings feed directly into the gauntlet report's Findings section. No separate report.

**From `/create-pr`:** High-severity findings → `## Security Findings` section in the PR body. Medium and low severity → mention count only (e.g., "2 medium-severity findings noted during security review"). Advisory only — never blocking.

## Sibling Skills

- `security-principles` — reference content for the 7 lenses. Loaded by both `security-finder` (lens definitions) and `security-validator` (mitigation patterns + false-positive rules).
- `code-quality-standards` — defensive-code anti-patterns. Loaded by the Validator for false-positive filtering.
- `adversarial-review` — pressure-tests structural assumptions. Different scope; security-gauntlet is threat-model-scoped, adversarial-review is failure-mode-scoped.
- (review-pr archived 2026-05-27 per Phase 9 — see `.claude/_archive/skills/review-pr/`. security-gauntlet is now invoked by gauntlet, not review-pr.)
