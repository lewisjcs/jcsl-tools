# core/knowledge/ — Index

TL;DR: every file here carries a short inline marker only. Full quotes,
longer rationale, and multi-source support live in `core/references/`,
loaded on demand — never inline in this tier.

## Files indexed

- [readme-section-necessity.md](./readme-section-necessity.md) — the
  necessity litmus rule for which drafted README sections earn inclusion.
- [evidentiary-marker-conventions.md](./evidentiary-marker-conventions.md)
  — the sole source of truth for the two evidentiary marker forms.
- [authoring-conventions.md](./authoring-conventions.md) — structural and
  size heuristics for content the core drafts.

## The terse-tier contract

A file in this directory carries a short inline marker only — a citation
key or a documented-rationale tag. A full citation block inline here
reintroduces the always-loaded cost that repository-context files carry
as a class. <!-- see: references/context-file-effectiveness.md#agentsmd-and-context-files-a-null-result-on-task-success -->

## Marker path resolution (RC-4)

A marker's target path resolves relative to `core/`, never relative to
the directory of the file containing the marker. A `see:` value written
in any file under `core/knowledge/` always resolves against
`core/references/`. <!-- rationale: documented internal decision, no external research available -->

## Verification check

Before adding a file here, confirm its basename appears in "Files
indexed" above, then run
`bash <skill-root>/scripts/check-knowledge-grounding.sh` and
confirm it exits 0.
