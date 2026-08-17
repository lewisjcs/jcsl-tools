# Reference: Authoring Conventions — Structure, Voice, and Size Constraints

Full-tier evidence for the structural, voice, and size-constraint rules
that govern authored guidance files (skills, knowledge files, ADRs,
READMEs). Loaded on demand from `core/knowledge/` `see:` markers (RC-4).

## Table of contents

- [Active voice and specificity in directive sections](#active-voice-and-specificity-in-directive-sections)
- [Citation format: descriptive link text, never bare URLs](#citation-format-descriptive-link-text-never-bare-urls)
- [Skill and reference file size budgets](#skill-and-reference-file-size-budgets)
- [Verification loops beat vague reminders](#verification-loops-beat-vague-reminders)
- [Description field: trigger nouns and verbs](#description-field-trigger-nouns-and-verbs)
- [Description field: workflow summaries suppress body-reading](#description-field-workflow-summaries-suppress-body-reading)
- [Phantom-alternative phrasing](#phantom-alternative-phrasing)
- [Omitting a requirement drops instruction-following](#omitting-a-requirement-drops-instruction-following)
- [Meaning-preserving rephrasing swings accuracy](#meaning-preserving-rephrasing-swings-accuracy)
- [Prompt-level evaluation and conflicting instructions](#prompt-level-evaluation-and-conflicting-instructions)
- [MADR and the community agents.md spec](#madr-and-the-community-agentsmd-spec)

## Active voice and specificity in directive sections

Nygard, "Documenting Architecture Decisions"
([source](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)),
2011: the ADR Decision section is a hard rule for active voice — "We
will…", never "It was decided that…" Larson, "Writing Engineering
Strategy" ([source](https://staffeng.com/guides/engineering-strategy/)):
"Specific statements create alignment; generic statements create the
illusion of alignment." Applied together in `voice-and-structure.md`:
directive sections state decisions without hedges (`might`, `could`,
`consider`, `optionally` are directive killers), and a milestone or rule
without an owner, date, or concrete criteria is a specificity failure
even when it is active-voice and non-hedged.

Locator: `plugins/gauntlet/skills/doc-patterns/voice-and-structure.md#active-voice-for-directives`
and `#larsons-specificity-principle`.
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/voice-and-structure.md

## Citation format: descriptive link text, never bare URLs

Convention, stated in `voice-and-structure.md` § Citation Conventions:
every URL uses `[descriptive text](url)` — never a bare URL, never
`[here]`. Example given in the source: `See [Writing Engineering
Strategy](https://staffeng.com/guides/engineering-strategy/) for the
specificity principle.` This governs every URL in this reference file
and its siblings.

Locator: `plugins/gauntlet/skills/doc-patterns/voice-and-structure.md#citation-conventions`
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/voice-and-structure.md

## Skill and reference file size budgets

`skill-authoring-principles` states the vendor size budget as a hard
constraint, not a preference: SKILL.md under 500 lines and under
roughly 5,000 tokens of body; reference files linked one level deep from
SKILL.md; a reference file over 100 lines needs a table of contents.
`description` frontmatter is capped at 1024 characters (vendor spec);
`name` at 64 characters. This is the direct source of this file's own
table-of-contents requirement above.

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#verification-checklist`
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## Verification loops beat vague reminders

`skill-authoring-principles` Finding 3: a concrete, checkable step
produces stronger quality outcomes than a vague reminder. The check does
not have to be a shell command — a structured comparison against a
reference document counts as a first-class validator. Example pairing
from the source: "Make sure you found all the PRs" (vague) versus "List
every PR found with number, repo, state. If none found, explicitly state
this." (checkable). The source also warns against over-gating: a
verifier that rejects correct output over cosmetic differences trains
the model to fight the check rather than meet it.

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#3-verification-loops-over-vague-reminders`
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## Description field: trigger nouns and verbs

`skill-authoring-principles` § 5, Rule A: include the specific trigger
words a developer would actually type in a skill's `description` field.
A generic description ("Use when beginning development work") misses
invocations; a description with concrete trigger nouns/verbs ("Use when
starting a new task, beginning work on a ticket, kicking off a Jira
story, or given an EXT- issue key") is invoked correctly. Vendor guidance
confirms this trigger-keyword half of the rule and the ≤1024-character
limit.

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#5-description-field-token-window`
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## Description field: workflow summaries suppress body-reading

`skill-authoring-principles` § 5, Rule B: if a skill's `description`
summarizes its workflow, agents follow the summary instead of reading the
full skill body. The source's own direct observation: a description
reading "code review between tasks" caused one review pass instead of
the intended two-stage process; removing the workflow summary restored
correct two-stage behavior. The source explicitly labels this rule's
evidentiary status: "the 'workflow summary causes body-skipping' effect
is our own direct observation, not externally corroborated... Keep Rule B
as a strong local finding, flagged as such."

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#5-description-field-token-window`
Status: house-heuristic

## Phantom-alternative phrasing

`skill-authoring-principles` Finding 4: phrasing that contrasts a chosen
behavior with a named alternative the model was never going to take
("Do X rather than Y") adds token cost without direction — a
phantom-alternative. Bright-line prohibitions against a real model
temptation ("Never invent facts") are kept; comparisons that merely
justify the author's own design decision are dropped. The source labels
this rule explicitly: "this rule rests on internal observation + the
`code-quality-standards` analogy, NOT external research — no cited study
tests phantom-alternative phrasing. Treat it as a house heuristic; it has
held in practice but isn't independently corroborated."

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#4-avoid-phantom-alternatives`
Status: house-heuristic

## Omitting a requirement drops instruction-following

Study: CMU, "What Prompts Don't Say"
([arXiv:2505.13360](https://arxiv.org/abs/2505.13360)). Finding: omitting
an essential requirement from a prompt drops the model's chance of
satisfying that requirement by 22.6% on average, up to 93.1% in the worst
case; models self-resolve an omission only 41.1% of the time. Cited in
`directive-review/lenses.md` as "Evidence: STRONG" for its
Under-specification lens — the strongest-graded evidence class among that
file's four lenses.

Locator: `plugins/gauntlet/skills/directive-review/lenses.md#lens-1-under-specification-apply-first`
Status: transcribed-from plugins/gauntlet/skills/directive-review/lenses.md

## Meaning-preserving rephrasing swings accuracy

Two studies, cited together in `directive-review/lenses.md` as
"Evidence: proxy" (no study isolates soft-vs-firm directive register
specifically): FormatSpread (ICLR 2024) found meaning-preserving
rephrasings of the same prompt swing accuracy by up to 76 points;
IFEval++ found reliable@10 (the fraction of instructions reliably
satisfied across 10 resamples) drops 18–62%. Together they support
treating a hedge word on a load-bearing directive as a defect distinct
from missing content.

Locator: `plugins/gauntlet/skills/directive-review/lenses.md#lens-4-ambiguity-literal-readability`
Status: transcribed-from plugins/gauntlet/skills/directive-review/lenses.md

## Prompt-level evaluation and conflicting instructions

Tian et al. ([arXiv:2509.14404](https://arxiv.org/abs/2509.14404))
establishes prompt-level evaluation — judging an instruction artifact on
its own terms (clarity, internal consistency, completeness) rather than
against external code or human-doc voice — and includes a taxonomy of
conflicting instructions. `directive-review/lenses.md` grounds its own
Lens 2 (Internal contradiction) in this taxonomy, combined with an
in-house observed case: a split citation-downgrade rule where one section
said "all unresolvable citations → MISLEADING" and another carved out an
exception, producing two verdicts for the same scenario.

Locator: `plugins/gauntlet/skills/directive-review/lenses.md#lens-2-internal-contradiction`
Status: transcribed-from plugins/gauntlet/skills/directive-review/lenses.md

## MADR and the community agents.md spec

Two structural specs cited in `doc-types.md`: MADR 4.0
([spec](https://adr.github.io/madr/)), the modern ADR adaptation adding
an explicit Considered-Options comparison and
`decision-makers`/`consulted`/`informed` frontmatter, used as the
optional-extension reference for ADRs; and the community AGENTS.md
standard ([agents.md](https://agents.md/)), which lists setup/build
commands as a "popular choice" to include — a choice `doc-types.md`
records that Contentful's internal doctrine deliberately narrows away
(setup commands are `bloat` in that doctrine's AGENTS.md, not the
community spec's).

Locator: `plugins/gauntlet/skills/doc-patterns/doc-types.md#4-adr-architecture-decision-record`
and `#6-agentsmd-and-claudemd-by-extension`.
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/doc-types.md
