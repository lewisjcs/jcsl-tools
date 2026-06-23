---
name: skill-authoring-principles
description: Use when writing, editing, or reviewing any skill file. Supplements superpowers:writing-skills with empirical research findings on description field behavior, focus vs comprehensiveness trade-offs, and verification loop effectiveness.
---

# Skill Authoring Principles

## Overview

Empirical research findings that shape how skills should be written. Load alongside `superpowers:writing-skills` — this covers what the research says, that skill covers the TDD process.

**Required background:** `superpowers:writing-skills`

> **Kept in sync with `skill-audit`.** This skill (the standard) and `skill-audit` (the auditor that enforces it) encode the SAME rules — size budget, focus, verification, phantom-alternatives. Change both in the same pass or the auditor drifts from the standard.

---

## The Findings

### 1. Accuracy Over Comprehensiveness

Version-mismatched guidance — code examples that don't match the actual repo — caused **~10% performance degradation** in SWE-Skills-Bench (565 tasks, 49 skills).

**Rule:** Either pull real code from actual files and cite the path, or label examples explicitly:
> `# Simplified illustration — read the actual service code for production patterns`

Never write invented code examples as if they are real.

### 2. Focus Beats Breadth (with a lower bound)

- SkillsBench (86 tasks, 11 domains): focused skills with 2–3 modules outperformed comprehensive documentation by **+16.2pp avg**
- SWE-Skills-Bench: **80% of skills yielded zero improvement**; the 7 that worked were narrow and domain-specific
- Independent corroboration beyond the skills benchmarks: *When Instructions Multiply* (arXiv 2509.21051) finds performance degrades monotonically with instruction count (predictable to ~10% error from count alone); *Lost in the Middle* (arXiv 2307.03172) shows long context buries mid-context information — both argue for short, front-loaded skills.

**Rule:** A skill should do one thing. If it covers more than 2–3 distinct modules, split it. Match the scope of AGENTS.md findings: non-discoverable content only.

**Lower bound (don't over-narrow):** the standard's authors and multiple vendors warn that skills scoped *too* narrowly force several to co-load and create ambiguous activation. Aim for coherent units — a skill should own a complete task, not a fragment of one. The failure mode is bidirectional: too broad dilutes, too narrow fragments.

### 3. Verification Loops Over Vague Reminders

A concrete, checkable step produces stronger quality outcomes than a vague reminder. The check does NOT have to be a shell command — a structured comparison against a reference doc counts (Anthropic explicitly blesses a `STYLE_GUIDE.md` the model reads and compares against as a first-class "validator"). What loses is the vague reminder, not prose itself.

**Rule:** End every agent instruction block with an explicit check — a command OR a structured comparison:

| Instead of | Write |
|---|---|
| "Make sure you found all the PRs" | "List every PR found with number, repo, state. If none found, explicitly state this." |
| "Check that the ticket exists" | "Confirm ticket key resolves before reporting. If not found, stop and report immediately." |

**Don't over-gate the verifier.** Avoid checks so strict they reject correct output over spurious differences (formatting, punctuation, valid alternative phrasing). A verifier that fails on cosmetics trains the model to fight the check instead of meeting it.

### 4. Avoid Phantom Alternatives

Skill bodies are read by models with no comparative state. Phrasing that contrasts the chosen behavior with another *named* alternative the model wasn't going to do creates phantom-alternative inflation: token cost without direction. The same failure shape `code-quality-standards` calls out in code (defensive guards against impossible states; fallback wrappers around new behavior).

**Three cases, only one is the trap:**

| Case | Example | Verdict |
|---|---|---|
| Bright-line prohibition (real model temptation) | `Never invent facts` / `Do not modify source code` | Keep — the model defaults to the failure mode; explicit interdict is load-bearing. |
| Default-behavior directive | `Read the prompt first` (vs. `Don't skip the prompt`) | Prefer the positive directive when the action stands alone. |
| Phantom-alternative comparison (the trap) | `Do X rather than Y` / `This is a hard stop, not a degraded mode` / `Do not pre-load` (when "read on demand" already directs the model) | Drop. Y wasn't the model's intention; the comparison is justifying *your* design decision, not directing the model. |

**Rule:** Strip phantom-alternative phrasings (`rather than X`, `not a Y`, negations of phantom defaults). Keep bright-line negations against real failure modes. When in doubt, ask: would removing the comparison weaken the directive? If no, drop it.

> **Evidence status:** this rule rests on internal observation + the `code-quality-standards` analogy, NOT external research — no cited study tests phantom-alternative phrasing. Treat it as a house heuristic; it has held in practice but isn't independently corroborated.

**Opus 4.7 corollary.** 4.7 follows directives more literally than 4.5/4.6. Soft hedges that worked before ("consider re-dispatching", "you may want to", "it might be worth") now read as optional and get skipped. For actions you actually want taken, prefer firm directives ("re-dispatch", "skip this step", "do X"). The flip side: bright-line prohibitions are enforced more rigidly, so make sure X in `do not X` is a real model temptation — Rule 6's phantom-alternative trap is more expensive on 4.7 than on prior models.

### 5. Description Field Token Window

The description is the only content read to decide whether to invoke a skill at all. It has a small effective token window.

**Two rules that conflict if ignored:**

**Rule A — Trigger nouns and verbs:** Include the specific words a developer would type. Generic descriptions miss invocations.
```yaml
# ❌ Too abstract
description: Use when beginning development work

# ✅ Includes trigger phrases
description: Use when starting a new task, beginning work on a ticket, kicking off a Jira story, or given an EXT- issue key
```

**Rule B — No workflow summary:** If the description summarizes the skill's process, agents follow the summary instead of reading the full skill body. This was observed directly: a description saying "code review between tasks" caused one review; removing the workflow summary caused correct two-stage behavior.

```yaml
# ❌ Summarizes workflow — agents skip the body
description: Use when starting a task — dispatches parallel agents for Jira, Docs, and Codebase context then hands off to brainstorm

# ✅ Triggers only, no workflow
description: Use when starting a new task, beginning work on a ticket, kicking off a Jira story, or given an EXT- issue key
```

> **Evidence status (Rule B):** the "workflow summary causes body-skipping" effect is our own direct observation, not externally corroborated. Vendor guidance confirms the *trigger-keyword* half (Rule A) and the ≤1024-char limit, but is silent on whether a process summary suppresses body-reading. Keep Rule B as a strong local finding, flagged as such.

**Hard constraints (vendor spec):** `description` max **1024 characters**; `name` max 64 chars (no `anthropic`/`claude`). **Open convention question — voice:** the cross-vendor Agent Skills standard recommends **imperative** ("Use this skill when…", "err on the side of being pushy"); some Anthropic guidance says **third person**. Both agree on ≤1024 chars and "what + when." Our existing skills mostly use the imperative "Use when…" form — so prefer imperative for consistency unless a house decision says otherwise. This is an unresolved convention, not a correctness rule.

---

## Workflow Discipline: Hardgates and task lists

Some skills need explicit discipline scaffolding — `<HARD-GATE>` blocks and task lists (built with the `TaskCreate`/`TaskUpdate` tools) — to keep the model on rails. Most don't. Adding scaffolding mechanically wastes tokens (Rule 6); omitting it where the failure mode is real ships broken behavior. The decision is conditional, not universal.

### When to add a `<HARD-GATE>` block

- Skill dispatches 2+ subagents with structured handoffs between phases — phase-collapse is a single-token decision the model makes without friction
- Phases require opposed framings (Finder vs Validator, hostile vs defensive) where collapsing defeats the skill's purpose
- Skipping a phase has high downstream cost — false positives shipped as fact, lost evaluator perspective, broken safety properties
- A bright-line prohibition is needed against a real model failure mode you've actually observed in this skill or one structurally similar

### When to add a task list

- 3+ ordered steps that must complete in sequence and the ordering matters
- Multi-item iteration (audit each skill, review each finding, process each commit) where the model must track which items are done
- The ordering isn't already enforced by file structure or output template

### When NOT to add either (anti-signals)

- File structure already enforces order — each phase reads its own file in sequence (the loading order does the discipline work)
- Output template demands structure — the model can't skip a section without producing visibly wrong output
- Linear single-pass workflow with no branching and ≤2 steps
- The "phases" are really stylistic headers, not distinct cognitive moves

### Common failure mode

Mechanically adding hardgates to every multi-step skill. Per Rule 6, `Do NOT skip step 2` against a model that wasn't going to skip it adds tokens without direction. Hardgates earn their weight only when the prohibited behavior is a real model temptation — confirm the failure has been observed, then write the gate against that specific failure.

---

## Verification Checklist

Before committing any skill:

- [ ] All code examples either cite a real file path or are labeled as simplified illustrations
- [ ] Skill covers ≤3 distinct modules — if more, split it
- [ ] Each agent/step instruction ends with a concrete check — a command OR a structured comparison — not a vague reminder
- [ ] No phantom-alternative phrasings (`rather than X`, `not a Y`, `do not <phantom default>`) — bright-line negations against real failure modes are fine; comparisons to behaviors the model wasn't going to do are not
- [ ] No soft hedges on load-bearing actions (`consider X`, `you may want to X`, `optionally X`) — Opus 4.7 reads these as optional and skips them; use firm directives for actions you want taken
- [ ] Description contains specific trigger nouns/verbs developers would actually type; ≤1024 chars
- [ ] Description does NOT summarize the skill's workflow or process steps
- [ ] **Size: `wc -l SKILL.md` < 500 lines AND body < ~5k tokens** (the vendor budget — NOT a word count). Frequently-loaded/auto-triggered skills should be far tighter. If a SKILL.md approaches the limit, split reference material into on-demand files (progressive disclosure), linked **one level deep** from SKILL.md.
- [ ] Reference files > 100 lines have a table of contents; references are at most one level deep from SKILL.md
- [ ] **Evaluation-first:** before writing extensive instructions, baseline the task *without* the skill on ≥3 representative cases — the skill must measurably beat baseline (per the skills benchmarks: most skills yield zero improvement, so prove yours doesn't)

---

## Research Sources

| Study | Sample | Key Finding |
|---|---|---|
| [SWE-Skills-Bench](https://arxiv.org/pdf/2603.15401) | 49 skills, 565 tasks | 80% zero improvement; 7 effective; 3 harmful via version mismatch (-10%) |
| [SkillsBench](https://arxiv.org/pdf/2602.12670) | 86 tasks, 11 domains | Focused 2–3 module skills +16.2pp; self-generated = zero benefit |
| [SKILL.md Best Practices](https://www.mdskills.ai/docs/skill-best-practices) | — | Verification loops most effective; match freedom to fragility; progressive disclosure |
| [SKILL.md Specification](https://agentskills.io) | — (Anthropic-originated open standard; not independent corroboration) | Three-phase loading: discovery, activation, execution. `allowed-tools` field is status: Experimental (support varies by client). |
| [When Instructions Multiply](https://arxiv.org/abs/2509.21051) | ManyIFEval / StyleMBPP | Performance degrades monotonically with instruction count (predictable to ~10% error from count alone) — independent backing for Focus (Finding 2) |
| [Lost in the Middle](https://arxiv.org/abs/2307.03172) | Liu et al., Stanford/Berkeley | Long context buries mid-context info; front-load load-bearing instructions, keep skills short |
