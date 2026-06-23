---
name: code-quality-audit
description: Use when auditing code for quality, reviewing a diff against code-quality-standards, checking conventions on a PR, or "audit code quality". Also use after writing or modifying code to verify it meets the team's defensive-code-anti-pattern rules. Dispatched by /gauntlet for code-pr and code-local artifacts.
argument-hint: "[<file-path-or-diff>]"
---

# Code Quality Audit

Audit code changes against `code-quality-standards` rules. Reference content is split by layer — load only what each layer needs.

## When NOT to use

- **Skill files (SKILL.md)** — use `skill-audit` for evaluating skills against authoring principles
- **Pressure-testing for hidden assumptions and failure modes** — use `adversarial-review` for hostile review
- **Security review** — use `security-gauntlet` for the 7 security lenses
- **Multi-skill PR review** — use `gauntlet` for the orchestrated multi-skill pass; this skill is one of its sub-skills

## Scope

Audit code in these locations (in order):

1. **Diff scope (default standalone)**: `git diff main...HEAD` (fall back to `master` only if `main` does not exist). Audits the change set, not the full codebase.
2. **File argument**: if `$ARGUMENTS` is a path, audit only that file.
3. **PR diff**: when called from `/gauntlet` against a `code-pr` artifact, gauntlet provides the PR diff in the dispatch prompt.

If `$ARGUMENTS` names a path that doesn't exist, stop and report: `Path '<arg>' not found. Run with no argument to audit the current diff.`

## Workflow

Execute all three layers in order. Each layer loads its own reference file. The rules source is `${CLAUDE_PLUGIN_ROOT}/skills/code-quality-standards/SKILL.md` (user-global).

### Layer 1 — Compliance

Read [compliance.md](compliance.md) for the rule list. For each changed file, evaluate against every rule.

Tag each finding:

| Tag | Meaning |
|-----|---------|
| `violation` | Breaks a code-quality-standards rule — should be fixed |
| `warning` | Borderline — worth reviewing but not a clear violation |
| `ok` | Passes the check |

### Layer 2 — Staleness

Read [staleness.md](staleness.md) for the staleness signal table. For each changed file, cross-reference its patterns against deprecated APIs, removed framework features, and codebase patterns explicitly migrated away from.

### Layer 3 — Gap analysis

Read [gaps.md](gaps.md) for the gap heuristics. For each changed file, check for missing tests, missing types on new exports, missing error context, and other gaps that reduce code quality.

### Layer 4 — Test integrity

Read [test-integrity.md](test-integrity.md) for the three checks. Run only if the diff touches test files or deletes symbols — skip otherwise (the file itself instructs the early-exit condition).

## Output

### Standalone

```text
## Code Quality Audit Report

### [file-path]
**Compliance:** [findings tagged violation/warning/ok per rule]
**Staleness:** [stale-pattern/replacement/suggestion for each]
**Gaps:** [gap/impact/proposed-fix for each]
**Test Integrity:** [check/tag/location/finding/proposed-fix for each, or "no test files in diff — skipped"]

### Summary
[total files audited, violations, warnings, gaps]
[prioritized fix list]
```

If a file passes all checks, report clean — do not invent issues.

### Called from /gauntlet

When dispatched by gauntlet for a `code-pr` or `code-local` artifact, return the same 3-layer prose. Gauntlet's Phase 3 substep 1 transforms the prose into canonical 10-field findings per master spec §4.3 (the same transformation it applies to skill-audit's output). The prose format is the contract; gauntlet handles the JSON shape.

## Verification

After reporting, confirm:
- [ ] Output contains exactly one `### [file-path]` block per file in scope, and each block contains all four subsections (`**Compliance:**`, `**Staleness:**`, `**Gaps:**`, `**Test Integrity:**`) — even if marked clean
- [ ] Every file in scope was audited
- [ ] Every rule from compliance.md, every signal from staleness.md, and every heuristic from gaps.md was checked against every file
- [ ] Layer 4 was run on every file that touches tests or deletes symbols; `**Test Integrity:** no test files in diff — skipped` was reported for files where neither condition applied
- [ ] Findings cite the specific line or pattern that triggered them
- [ ] Proposed fixes are concrete edits, not vague guidance
- [ ] No finding recommends a defensive-code anti-pattern (the rules being audited are explicitly anti-defensive — recommending a guard the rules forbid is a self-contradiction)

## Sibling Skills

- `code-quality-standards` (`${CLAUDE_PLUGIN_ROOT}/skills/code-quality-standards/`) — the rules source. This skill audits AGAINST those rules.
- `skill-audit` — parallel skill that audits SKILL.md files against `skill-authoring-principles`. Same 3-layer architecture; different domain.
- `adversarial-review` — pressure-tests code for hidden assumptions, failure modes, blast radius. Sibling in `gauntlet`'s code-pr Phase 1 dispatch.
- `security-gauntlet` — 7 security lenses. Sibling in `gauntlet`'s Phase 2 dispatch.
- `gauntlet` — orchestrator that dispatches this skill alongside adversarial-review and security-gauntlet for multi-skill PR review.
