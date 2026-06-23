---
name: skill-audit
description: Use when auditing skills for quality, reviewing skill files, checking if skills follow authoring principles, or "are my skills any good". Also use after creating or editing a skill to verify it meets standards.
argument-hint: "[<skill-name>]"
---

# Skill Audit

Audit SKILL.md files against authoring principles. Reference content is split by layer — load only what each layer needs.

## When NOT to use

- **Code review** — use `code-quality-standards` for evaluating implementations
- **Pressure-testing PRs** — use `adversarial-review` for hidden assumptions and failure modes
- **Newly-created skills with no content yet** — audit needs the SKILL.md body to evaluate; come back after the skill has substantive content

## Scope

Audit skills in these locations (in order):

1. **Project skills**: `.claude/skills/` in the current working directory
2. **User skills**: `~/.claude/skills/`

If `$ARGUMENTS` names a specific skill, audit only that one. If `$ARGUMENTS` names a skill not present in either location, stop and report: `Skill '<name>' not found in project or user skills. Available: <list of skills found>`. Do not audit unrelated skills as a fallback.

## Workflow

Execute all three layers in order. Each layer loads its own reference file; [principles-shared.md](principles-shared.md) (philosophy + severity grading) loads once and applies to all three.

### Layer 1 — Principles Compliance

Read [compliance.md](compliance.md) for the seven rules. For each skill in scope, evaluate against every rule.

Tag each finding:

| Tag | Meaning |
|-----|---------|
| `violation` | Breaks a principle — should be fixed |
| `warning` | Borderline — worth reviewing |
| `ok` | Passes the check |

### Layer 2 — Staleness Detection

Read [staleness.md](staleness.md) for the signal table. For each skill, cross-reference its claims against the current system state.

### Layer 3 — Gap Analysis

Read [gaps.md](gaps.md) for the heuristics table. For each skill, check for missing elements that reduce effectiveness.

## Output

```text
## Skill Audit Report

### [skill-name]
**Compliance:** [findings tagged violation/warning/ok]
**Staleness:** [claim/reality/suggestion for each stale item]
**Gaps:** [gap/impact/proposed-fix for each gap]

### Summary
[total skills audited, violations, warnings, gaps]
[prioritized fix list]
```

If a skill passes all checks, report clean — do not invent issues.

## Verification

After reporting, confirm:
- [ ] Output contains exactly one `### [skill-name]` block per skill in scope, and each block contains all three subsections (`**Compliance:**`, `**Staleness:**`, `**Gaps:**`) — even if marked clean
- [ ] Every skill in scope was audited
- [ ] Every rule from compliance.md, every signal from staleness.md, and every heuristic from gaps.md was checked against every skill
- [ ] Findings include the specific line or content that triggered them
- [ ] Proposed fixes are concrete edits, not vague guidance

## Sibling Skills

- `code-quality-standards` — evaluates code (not skills). Different domain; use when reviewing implementations.
- `adversarial-review` — pressure-tests code changes for hidden assumptions and failure modes. Different domain; use when stress-testing PRs.
