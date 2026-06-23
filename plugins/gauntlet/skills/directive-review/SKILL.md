---
name: directive-review
description: Use when reviewing agent-instruction prose — a prompt, knowledge file, or reference file that instructs an AI agent how to behave (the kind under .claude/agents/*/prompts/, .claude/agents/*/knowledge/, or .claude/skills/*/references/) — for under-specification, internal contradiction, unenforceable gates, and ambiguity that would mislead a literal executor. Trigger phrases include "review this prompt", "review this agent instruction", "is this directive clear", "directive review", "review this knowledge file", "will an agent follow this correctly".
argument-hint: "[<path-to-instruction.md>]"
---

# Directive Review

Apply 4 directive-review lenses (Under-specification, Internal contradiction, Unenforceable gate, Ambiguity/literal-readability) to an agent-instruction prose artifact via opposed-framing agents. Find → Validate → Adjudicate.

Reviews the instruction artifact at the **prompt level** — on its own terms, for a literal executor — NOT against external code (cartographer-refresh's job) and NOT for human-doc voice (doc-review's job). See `lenses.md` for the substantive criteria and evidence labels.

## Usage

```
/directive-review path/to/prompt.md           — review a specific instruction file
/directive-review                             — review the most recently modified instruction file in $PWD
```

The skill is also invoked by `gauntlet` when the orchestrator detects a `directive` artifact.

**When NOT to use:** Human-facing docs/RFCs/READMEs (use `/doc-review`). SKILL.md or agent.md frontmatter definitions (use `/skill-audit`). Plan review (use `/plan-review`). Code (use `/gauntlet` or `/code-quality-audit`). Checking whether a generated golden-context doc has drifted from repo code (use `/cartograph` refresh). Brainstorming/designing the instruction (use `superpowers:brainstorming`, then review the result).

## Invocation Context Detection

| Context | Artifact source | Output target |
|---|---|---|
| Called from `/gauntlet` (artifact detected as `directive`) | Full file content in context | Surviving findings feed the gauntlet report's Findings section |
| Standalone with `<path>` | Read from path | Standalone report |
| Standalone no args | Most recently modified instruction `.md` in `$PWD` (under a `prompts/`, `knowledge/`, `references/`, `reference/`, or `rules/` dir), excluding `SKILL.md`/`agent.md` and `.plan.md` | Standalone report |
| Called from `gauntlet` orchestrator | Artifact content passed in invocation prompt | Returns surviving findings JSON for orchestrator aggregation |

The gauntlet-orchestrator output JSON has the canonical 10 fields per master spec §4.1, pre-filtered to `verdict = "survives"` AND `confidence ≥ 70` (the Phase 3 cutoff below). Disproved findings are NOT propagated to the orchestrator; they render in the standalone `<details>` block.

---

## Checklist

Create a task for each item (a `TaskCreate` call each); complete in order — `in_progress` before starting, `completed` (via `TaskUpdate`) when done. Do not start a phase while the previous is incomplete.

1. **Phase 1** — Dispatch `directive-finder` and verify JSON shape
2. **Phase 2** — Dispatch `directive-validator` with verbatim findings and verify verdicts
3. **Phase 3** — Adjudicate in main context, verify filtering reduced count, emit report

<HARD-GATE>
Each phase runs in its own subagent dispatch (Phases 1 and 2) or main context (Phase 3). Do NOT collapse phases into a single Agent call. Do NOT skip Phase 2 by adjudicating Finder output directly. The three phases exist because Finder, Validator, and Adjudicator have opposed framings — collapsing them defeats the skill.
</HARD-GATE>

---

## Phase 1 — Dispatch Finder

Dispatch the `directive-finder` subagent (Agent tool, `subagent_type: directive-finder`) with the full artifact content in the prompt body. The agent's persona, 4-lens vocabulary, and emission contract are set by its system prompt; the dispatch prompt supplies the artifact content and its repo-relative path.

**If the dispatch fails with `Agent type 'directive-finder' not found`:** the runtime agent registry has not picked up `.claude/agents/directive-finder.md`. Run `/reload-plugins` (or restart the session), then retry. Same recovery for Phase 2's `directive-validator`.

**Verify before Phase 2:** Parse Finder output as JSON. Confirm it is an array (possibly empty). Each entry MUST have the 10 fields (`skill`, `lens`, `category`, `location`, `claim`, `evidence`, `verdict`, `severity`, `confidence`, `recommendation`). The `lens` value MUST start with `directive-review / ` exactly and be one of the 4 canonical labels (`Under-specification`, `Internal contradiction`, `Unenforceable gate`, `Ambiguity and literal-readability`). The `location` MUST be a bare single-section reference (not file:line, not backtick-wrapped). If parse fails or the contract is violated, re-dispatch Finder once with the contract spelled out. If the second pass still fails, emit a brief "Finder output malformed" report and exit.

If Finder returns `[]`, emit "No directive-review findings against the 4 active lenses." and skip Phase 2.

---

## Phase 2 — Dispatch Validator

Dispatch the `directive-validator` subagent (Agent tool, `subagent_type: directive-validator`) with: (1) the full artifact content, (2) the Finder's raw findings array verbatim, (3) the artifact's repo-relative path. Do NOT summarize or pre-filter the Finder JSON.

**Verify before Phase 3:** Parse Validator output as JSON. Confirm one entry per Finder finding (count must match), each with `verdict ∈ {survives, disproved}`, `evidence`, `confidence ∈ [0,100]`. If counts mismatch, re-dispatch with the missing findings. If a non-canonical verdict string appears (`false_positive`, etc.), re-dispatch once with the contract spelled out. Do not advance until verification passes.

---

## Phase 3 — Adjudicate

In the main context (no subagent):

1. **Drop** findings where `verdict = disproved`.
2. **Drop** findings where `verdict = survives` but `confidence < 70`.
3. **Deduplicate** — same `location` AND same `lens` → keep higher-confidence. Same location under different lenses are NOT duplicates; both survive.
4. **Rank** survivors by severity × confidence.

**Verify before report — single Validator pass is the default; escalate only on a pinned trigger.** The Validator runs exactly once (Phase 2). Re-dispatch it for a **second and final** pass IFF, after the first pass, EITHER pinned condition holds:
1. **Rubber-stamp guard** — the Validator disproved **zero** of the Finder's findings (it killed nothing).
2. **High-stakes borderline** — at least one **surviving** finding has `severity = "High"` AND `confidence ∈ [70, 78]` (a candidate blocker kept on borderline confidence — the band where a second pass can ground it to `confidence ≥ 85` or disprove it).

On re-dispatch: apply disproof strategies 2 (verbosity-bias) and 3 (correctly-optional / correctly-scoped) more aggressively, and confirm code-quality-standards false-positive rules were applied; AND for any High-stakes-borderline finding, instruct the Validator to re-ground its confidence against the artifact (push to a confident `≥ 85` survive with cited evidence, or disprove). Cap at **one** extra pass even if both conditions fire; never loop. If after the second pass a finding is still High at `confidence ∈ [70, 78]`, accept it and note: "high-stakes borderline finding survived a second Validator pass at confidence N." If the rubber-stamp guard fired and the second pass still drops zero, accept the survivors and note: "no false-positive filter triggered — every Finder finding survived two Validator passes."

---

## Output

**Standalone:** Full report with surviving findings (location, claim, evidence, severity, recommendation each), plus a collapsed `<details>` section of disproved findings for transparency.

**From `/gauntlet`:** Surviving findings feed the gauntlet report's Findings section.

**From `gauntlet` orchestrator:** Return surviving findings as a JSON array.

## Calibration

Calibrated against the gauntlet gold-fixture suite (`projects/active/gauntlet/test-dataset/directive/`, 6 fixtures: 4 plants + 2 controls including a long-but-clean verbosity-bias guard). Opus 4.8, 2026-06-03: **TPR 1.0, FPR 0.0, Cohen's κ = φ = 1.0, drift 0.0** — every plant caught at the correct lens, both controls silent. Meets the tightened 0.90/0.05 bar. Re-run via `run-calibration.sh directive-review` on model bumps; the suite is the ongoing discrimination guard, not a one-time certificate.

## Sibling Skills

- `lenses.md` (this skill's directory) — substantive lens definitions + evidence labels. Loaded by both agents at dispatch.
- `code-quality-standards` — defensive-code anti-patterns. Loaded by the Validator for false-positive filtering.
- `doc-review` — reviews human-facing docs (RFCs/READMEs/AGENTS.md). Different audience: doc-review protects human readers and Tundra house voice; directive-review protects a literal agent executor.
- `skill-audit` — reviews SKILL.md/agent.md frontmatter definitions. directive-review covers the non-frontmatter prose those skills reference.
- `gauntlet` — orchestrator; dispatches directive-review for `directive` artifacts.
