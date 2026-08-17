# Reference Index — `core/references/`

Records every source checked in this task's research sweep (RC-14) and the
heading slugs (RC-4) that `core/knowledge/` `see:` markers may cite. This
file is the index rule (d) checks against (RC-1) — it is not itself an
indexed entry, so it does not list itself below.

## Files indexed

- [readme-scope.md](./readme-scope.md)
- [context-file-effectiveness.md](./context-file-effectiveness.md)
- [authoring-conventions.md](./authoring-conventions.md)

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

2. **Glean search over Slack and PR-review history** — unavailable:
   Glean not accessible to this agent.

3. **Reuse: arXiv:2602.11988, already written up in `kiln/design.md` §
   "Research basis"** — yielded: 3 entries (`readme-scope.md` §§
   Repository-context files: null result on task success, positive
   cost, Concrete instructions succeed; generic overviews do not;
   `context-file-effectiveness.md` § AGENTS.md and context files: a
   null result on task success).

4. **Fresh external web search (last resort)** — yielded: nothing. No
   gap remained after sources 1–3, so per the sweep order's "only for a
   gap sources 1–3 leave open" scoping rule no query was attempted —
   this is a distinct outcome from a search that ran and returned no
   results.

## Heading slugs by file (RC-4)

### readme-scope.md

- `#repository-context-files-null-result-on-task-success-positive-cost`
- `#concrete-instructions-succeed-generic-overviews-do-not`
- `#the-agentsmd-inclusion-litmus-test`
- `#bloat-and-misplaced-content-are-hard-failure-classes-not-style-choices`

### context-file-effectiveness.md

- `#agentsmd-and-context-files-a-null-result-on-task-success`
- `#focused-skills-outperform-comprehensive-docs`
- `#most-skills-yield-zero-improvement-version-mismatch-is-harmful`
- `#instruction-count-degrades-performance-monotonically`
- `#long-context-buries-mid-context-information`
- `#doc-patterns-cites-cartographers-files-cartographer-cites-nothing-back`

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
