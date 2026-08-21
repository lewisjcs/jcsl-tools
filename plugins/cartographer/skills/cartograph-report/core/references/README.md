# Reference Index — `core/references/`

Records every source checked in this task's research sweep (RC-14) and the
heading slugs (RC-4) that `core/knowledge/` `see:` markers may cite. This
file is the index rule (d) checks against (RC-1) — it is not itself an
indexed entry, so it does not list itself below.

## Table of contents

- [Files indexed](#files-indexed)
- [Sweep outcomes (in sweep order)](#sweep-outcomes-in-sweep-order)
- [Heading slugs by file (RC-4)](#heading-slugs-by-file-rc-4)

## Files indexed

- [readme-scope.md](./readme-scope.md)
- [context-file-effectiveness.md](./context-file-effectiveness.md)
- [authoring-conventions.md](./authoring-conventions.md)

A `sources/` subdirectory also exists under `core/references/`, holding
verbatim captures of the release's build-time research record (not
shipped in source form; captured verbatim here as
`sources/design-research-basis-2026-08-17.md` and
`sources/external-sweep-2026-08-17.md`) that the entries above cite by
`Status: transcribed-from`. `sources/` sits at depth 2 under
`core/references/`, outside RC-1's rule-(d) glob (`find "$CORE_DIR/references"
-maxdepth 1 -type f -name '*.md' ! -name 'README.md'`), so it is
deliberately **not** listed as an indexed file above and never trips rule
(d).

## Sweep outcomes (in sweep order)

1a. **Known internal sources —
   `plugins/gauntlet/skills/skill-audit/principles-shared.md` +
   `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md`** —
   yielded: 9 entries (`context-file-effectiveness.md` §§ Focused skills
   outperform comprehensive docs, Most skills yield zero improvement…,
   Instruction count degrades…, Long context buries…;
   `authoring-conventions.md` §§ Skill and reference file size budgets,
   Verification loops beat vague reminders, Description field: trigger
   nouns and verbs, Description field: workflow summaries…,
   Phantom-alternative phrasing).

1b. **Known internal sources —
   `plugins/gauntlet/skills/doc-patterns/doc-types.md` +
   `plugins/gauntlet/skills/doc-patterns/voice-and-structure.md`** —
   yielded: 6 entries (`readme-scope.md` §§ The AGENTS.md inclusion
   litmus test, Bloat and misplaced content…;
   `context-file-effectiveness.md` § doc-patterns cites Cartographer's
   files…; `authoring-conventions.md` §§ Active voice and specificity…,
   Citation format…, MADR and the community agents.md spec).

1c. **Known internal sources —
   `plugins/gauntlet/skills/directive-review/lenses.md`** — yielded: 3
   entries (`authoring-conventions.md` §§ Omitting a requirement drops
   instruction-following, Meaning-preserving rephrasing swings accuracy,
   Prompt-level evaluation and conflicting instructions).

2. **Internal org search over Slack and PR-review history** —
   unavailable: no internal search tool accessible to this agent.

3. **Reuse: arXiv:2602.11988, already written up in the release design
   document § "Research basis" (captured at
   `sources/design-research-basis-2026-08-17.md`)** — yielded: 3 entries
   (`readme-scope.md` §§
   Repository-context files: null result on task success, positive
   cost, Concrete instructions succeed; generic overviews do not;
   `context-file-effectiveness.md` § AGENTS.md and context files: a
   null result on task success).

4. **Fresh external web search — REQUIRED per a scope amendment recorded
   in the release's build-time research record (conducted by a dedicated
   research agent per user directive; superseded the original "last
   resort only" scoping)** — yielded: 17 integrated
   entries across 13 queries (captured at
   `sources/external-sweep-2026-08-17.md` § Query ledger), plus 1
   corroborating
   addition folded into the existing "Skill and reference file size
   budgets" entry in `authoring-conventions.md` rather than duplicated
   (RC-14/RC-13 discipline: a corroborating source is not a new claim).
   New entries landed in `readme-scope.md` (6: README content taxonomy,
   README-popularity correlation, README-update staleness, LLM
   drift-blindness, outdated code-element references, the AGENTS.md
   vendor-spec division of labor), `context-file-effectiveness.md` (6:
   the two-agent correctness-null ablation, the context-file content
   composition study, configuration smells, the probe-and-refine
   counterweight, the rule-update compliance study, the AGENTS.md
   efficiency result), and `authoring-conventions.md` (5: the
   file-structure-adherence null, citation-grounded generation, the
   long-handbook compliance ceiling, single-vs-multi-agent README
   generation, and the CodeWiki-vs-DeepWiki machine baseline). The sweep
   file records 4 gap topics honestly rather than filling them with a
   weaker source: no head-to-head generated-vs-human-authored README
   study with human judges (Topic 6); no published error rate for
   claims in generated repository documentation specifically, distinct
   from scientific-citation hallucination (Topic 4); no causal
   README-content-to-onboarding-outcome study, only descriptive/
   correlational evidence, and one unresolved, uncited 717-repository
   snippet (Topic 2); and the classic Wen et al. ICPC 2019 code-comment
   co-evolution baseline, found relevant but paywalled on every
   accessible copy and therefore not recorded (Topic 3).

## Heading slugs by file (RC-4)

### readme-scope.md

- `#repository-context-files-null-result-on-task-success-positive-cost`
- `#concrete-instructions-succeed-generic-overviews-do-not`
- `#the-agentsmd-inclusion-litmus-test`
- `#bloat-and-misplaced-content-are-hard-failure-classes-not-style-choices`
- `#readme-content-skews-to-what-and-how-purpose-and-status-are-commonly-absent`
- `#readme-structural-features-correlate-with-project-popularity`
- `#readme-updates-almost-never-accompany-code-changes-and-some-should`
- `#llm-staleness-judges-are-blind-to-the-drift-direction-that-matters-most`
- `#outdated-code-element-references-are-near-universal-in-repository-docs`
- `#vendor-spec-agentsmd-is-a-readme-for-agents-not-a-readme-replacement`

### context-file-effectiveness.md

- `#agentsmd-and-context-files-a-null-result-on-task-success`
- `#focused-skills-outperform-comprehensive-docs`
- `#most-skills-yield-zero-improvement-version-mismatch-is-harmful`
- `#instruction-count-degrades-performance-monotonically`
- `#long-context-buries-mid-context-information`
- `#doc-patterns-cites-cartographers-files-cartographer-cites-nothing-back`
- `#context-files-do-not-move-correctness-in-a-two-agent-controlled-ablation`
- `#context-files-are-configuration-like-artifacts-skewed-to-functional-content`
- `#configuration-smells-are-widespread-in-agentsmdclaudemd-files`
- `#iteratively-tuned-repository-guidance-raises-task-resolve-rate`
- `#updating-rule-files-measurably-improves-artifact-compliance`
- `#agentsmd-presence-reduces-agent-runtime-and-output-tokens`

### authoring-conventions.md

- `#active-voice-and-specificity-in-directive-sections`
- `#citation-format-descriptive-link-text-never-bare-urls`
- `#skill-and-reference-file-size-budgets`
- `#verification-loops-beat-vague-reminders`
- `#description-field-trigger-nouns-and-verbs`
- `#description-field-workflow-summaries-suppress-body-reading`
- `#phantom-alternative-phrasing`
- `#omitting-a-requirement-drops-instruction-following`
- `#meaning-preserving-rephrasing-swings-accuracy`
- `#prompt-level-evaluation-and-conflicting-instructions`
- `#madr-and-the-community-agentsmd-spec`
- `#file-structure-variables-show-no-detectable-adherence-effect-compliance-decays-within-a-session`
- `#citation-grounded-generation-reaches-high-accuracy-on-code-comprehension-single-author-self-reported`
- `#long-standing-instruction-documents-are-followed-poorly-over-extended-horizons`
- `#single-agent-readme-generation-matches-multi-agent-quality-at-a-fraction-of-the-cost`
- `#repository-doc-generation-is-benchmarked-against-other-generators-not-humans`
