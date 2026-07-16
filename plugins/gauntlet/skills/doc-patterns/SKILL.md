---
name: doc-patterns
description: Use when writing or reviewing documentation — RFCs, PRDs, ADRs, READMEs, AGENTS.md, design docs, or any prose artifact for an internal audience. Also use when asked "is this doc clear?", "what's the right structure for this RFC?", "should this be an ADR?", or when reviewing a doc against Contentful house style.
---

# Doc Patterns

Reference content for doc-relevant work across Contentful engineering. Load when authoring or reviewing structured prose artifacts — RFCs, ADRs, design docs, and operational context files — or when applying Contentful house style to any internal documentation.

## When NOT to use

- **General code review** — use `/gauntlet` for multi-skill review or `/code-quality-audit` for convention-only audit
- **Style, lint, or defensive-code patterns** — use `code-quality-standards`
- **Security-specific review** — use `security-principles` + `security-gauntlet`
- **Slack messages, emails, or casual writing** — doc-patterns covers structured prose artifacts only

## Reference files (load on demand)

| File | Purpose |
|---|---|
| [doc-types.md](doc-types.md) | Structural templates and required sections for six document types: RFC, PRD, ADR, README, AGENTS.md, and design docs. |
| [voice-and-structure.md](voice-and-structure.md) | Cross-cutting prose patterns — headings as TL;DR, paragraph density, active voice, and Larson's specificity rule — that apply across all doc types. |
| [contentful-patterns.md](contentful-patterns.md) | Contentful-specific house rules: evals discipline for AI features, ADR filename conventions, owner pointer standards, and AGENTS.md scope hygiene. |
| [failure-modes.md](failure-modes.md) | Common doc failure patterns mapped to five `doc-review` lenses, with grep-able tells and concrete fixes for each. |

## Lens index

When applying doc review, the five lenses (in the order doc-finder applies them per master spec §3.5) map to reference-file sections as follows:

| # | Lens | Primary file | Secondary references |
|---|---|---|---|
| 1 | Memory-encoded rules | failure-modes.md §Lens 1 | contentful-patterns.md (ADR convention, owner pointers, AGENTS.md bloat); voice-and-structure.md (evergreen language) |
| 2 | Internal consistency | failure-modes.md §Lens 2 | doc-types.md (structural templates per type) |
| 3 | Accuracy of references | failure-modes.md §Lens 3 | voice-and-structure.md (citation conventions); contentful-patterns.md (Jira/Confluence-specific) |
| 4 | Voice / writing-style alignment | failure-modes.md §Lens 4 | voice-and-structure.md (active voice, no hedging, headings as TL;DR, Larson's specificity) |
| 5 | Hidden assumptions | sibling: `adversarial-review` | failure-modes.md §Lens 5 (delegation note) |

## Sibling Skills

- `doc-review` — applies these patterns via Finder/Validator pattern; loads this skill at Validator invocation time.
- `security-principles` — security threat reference content. Different domain; sibling pattern for skill structure.
- `adversarial-review` — pressure-tests hidden assumptions. Lens 5 invokes this; not doc-specific.

## Maintenance

Source verification dates are in `projects/active/gauntlet/research/doc-sources.md`. Re-verify quarterly; update contentful-patterns.md §Evals discipline when Mike Kivisto's evals mandate posts update.
