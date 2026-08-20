# Authoring Conventions

TL;DR: structural and size heuristics for content Cartographer's core
drafts — its own `core/` files and any generated README section. Every
directive below ends with a concrete check.

## Size budgets are hard constraints

Keep any authored file within the vendor size budget: a body under 500
lines, reference files linked one level deep from the file that loads
them, and any reference file over 100 lines carries a table of contents.
<!-- see: references/authoring-conventions.md#skill-and-reference-file-size-budgets -->

## Active voice, no hedges on directives

Directive sections state decisions in active voice and never hedge with
`might`, `could`, `consider`, or `optionally`. A rule without an owner,
date, or concrete criteria is a specificity failure even when it is
active-voice and non-hedged. <!-- see: references/authoring-conventions.md#active-voice-and-specificity-in-directive-sections -->

## Strip phantom alternatives; keep bright-line prohibitions

Never contrast a chosen behavior against a named alternative the reader
was not going to take (`rather than X`, `not a Y`) — it adds cost without
direction. Keep bright-line prohibitions against real failure modes, and
strip soft hedges (`consider`, `you may want to`, `optionally`) from
load-bearing actions. <!-- see: references/authoring-conventions.md#phantom-alternative-phrasing -->

## Every instruction block ends with a concrete check

Close each instruction block with a command or a structured comparison
against a reference document — both count as first-class validators. A
vague reminder ("make sure you found everything") is never sufficient.
<!-- see: references/authoring-conventions.md#verification-loops-beat-vague-reminders -->

## Citations use descriptive link text

Every URL in an authored file uses descriptive link text — never a bare
URL, never `[here]`. <!-- see: references/authoring-conventions.md#citation-format-descriptive-link-text-never-bare-urls -->

## Focused files beat comprehensive docs, with a lower bound

Several coherent files, each owning a complete topic, outperform one
omnibus file and outperform many narrow fragments that force co-loading
and create ambiguous activation. <!-- see: references/context-file-effectiveness.md#focused-skills-outperform-comprehensive-docs -->

## Examples cite a real path or are labeled simplified

An example in authored content must cite a real path in this repo or be
explicitly labeled a simplified illustration. Never present an
invented-as-real example — version-mismatched guidance measurably
degrades outcomes. <!-- see: references/context-file-effectiveness.md#most-skills-yield-zero-improvement-version-mismatch-is-harmful -->

## Never duplicate what already exists

Generated guidance must never duplicate what README, CONTRIBUTING, or a
skill already states — restate it by reference instead. This is a
bright-line prohibition, not a hedge. <!-- rationale: documented internal decision, no external research available -->

## Verification check

Before committing an authored file, run
`bash <skill-root>/scripts/check-knowledge-grounding.sh` over
`core/` and confirm it exits 0.
