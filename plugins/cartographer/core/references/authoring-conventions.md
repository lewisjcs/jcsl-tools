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
- [File-structure variables show no detectable adherence effect; compliance decays within a session](#file-structure-variables-show-no-detectable-adherence-effect-compliance-decays-within-a-session)
- [Citation-grounded generation reaches high accuracy on code comprehension (single-author, self-reported)](#citation-grounded-generation-reaches-high-accuracy-on-code-comprehension-single-author-self-reported)
- [Long standing-instruction documents are followed poorly over extended horizons](#long-standing-instruction-documents-are-followed-poorly-over-extended-horizons)
- [Single-agent README generation matches multi-agent quality at a fraction of the cost](#single-agent-readme-generation-matches-multi-agent-quality-at-a-fraction-of-the-cost)
- [Repository-doc generation is benchmarked against other generators, not humans](#repository-doc-generation-is-benchmarked-against-other-generators-not-humans)

## Active voice and specificity in directive sections

Nygard, "Documenting Architecture Decisions"
([source](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)),
2011: the ADR Decision section is a hard rule for active voice — "We
will…", never "It was decided that…" `voice-and-structure.md`'s own
prose states the specificity principle it attributes to Larson,
"Writing Engineering Strategy"
([source](https://staffeng.com/guides/engineering-strategy/)) — specific
statements create alignment, generic statements create the illusion of
alignment — as a paraphrase, not a direct quotation from Larson: the
source lists Larson under its Sources section and states the principle
in its own words rather than quoting him verbatim. Applied together in
`voice-and-structure.md`: directive sections state decisions without
hedges (`might`, `could`, `consider`, `optionally` are directive
killers), and a milestone or rule without an owner, date, or concrete
criteria is a specificity failure even when it is active-voice and
non-hedged.

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

Corroborated directly at the primary vendor source: Anthropic, "Skill
authoring best practices" ([Claude Platform Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)):
"Keep SKILL.md body under 500 lines for optimal performance" / "Split
content into separate files when approaching this limit" / "Keep
references one level deep from SKILL.md. All reference files should
link directly from SKILL.md to ensure Claude reads complete files when
needed" / "For reference files longer than 100 lines, include a table of
contents at the top." **Caveat:** this guidance is prescriptive, not
shown to move outcomes — it is in direct tension with arXiv:2605.10039
below, which found no detectable adherence effect from file size after
multiple-testing correction.

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#verification-checklist`;
Anthropic skill-authoring best practices, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 9 /
Findings § "Vendor spec: concrete size and reference-depth limits for
agent knowledge files").
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
IFEval++ found reliable@10 drops 18–62%. Together they support treating
a hedge word on a load-bearing directive as a defect distinct from
missing content.

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

## File-structure variables show no detectable adherence effect; compliance decays within a session

McMillan, "Instruction Adherence in Coding Agent Configuration Files: A
Factorial Study of Four File-Structure Variables"
([arXiv:2605.10039](https://arxiv.org/abs/2605.10039)): a factorial
study across 1,650 Claude Code CLI sessions (16,050 function-level
observations) on two TypeScript codebases and three frontier models
found no detectable adherence effect from file size, instruction
position, file architecture, or contradictions in adjacent files after
multiple-testing correction (size and conflict nulls supported by
affirmative-null Bayes factors, BF10 0.05–0.10); the largest measured
effect was within-session — each additional generated function was
associated with ~5.6% lower odds of compliance (OR = 0.944),
non-monotonic rather than constant. This is in direct tension with the
vendor size guidance above: the numeric limits are prescriptive, not
shown to move adherence in this study.

Locator: arXiv:2605.10039, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 1 /
Findings § "File-structure variables show no detectable effect on
instruction adherence; compliance decays within a session").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Citation-grounded generation reaches high accuracy on code comprehension (single-author, self-reported)

Arafat, "Citation-Grounded Code Comprehension: Preventing LLM
Hallucination Through Hybrid Retrieval and Graph-Augmented Context"
([arXiv:2512.12117](https://arxiv.org/abs/2512.12117)): across 30 Python
repositories and 180 developer queries, a hybrid retrieval plus
graph-expansion architecture reported 92% citation accuracy with zero
hallucinations; cross-file evidence discovery was identified as the
largest contributor to citation completeness, largely overlooked by
systems relying on pure textual similarity. **Caveat, as recorded by the
sweep that transcribed it:** single-author preprint, self-reported "zero
hallucinations," no independent replication.

Locator: arXiv:2512.12117, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 6 /
Findings § "Citation-grounded retrieval reaches 92% citation accuracy on
code comprehension").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Long standing-instruction documents are followed poorly over extended horizons

Panavas, Minus, Monton, Ray, Garre, Mehta, and Chen, "HANDBOOK.md: A
Benchmark for Long-Context Agentic Instruction Following"
([arXiv:2607.25398](https://arxiv.org/abs/2607.25398)): on 65 agentic
tasks governed by 20–124-page expert-written procedure documents with
824 deterministic rubric criteria, the strongest evaluated model passed
36.2% of trials under strict grading and most frontier models stayed
below 25%; failure patterns included letting a plausible but
unauthorized request override standing policy, acting against a required
check's own result, losing rule details over long horizons, and
reporting compliance not actually achieved. Hard-ceiling evidence
against exhaustive, long knowledge files. **Derived consequence, not a
study finding:** the benchmark has no short-context arm, so "short,
high-salience context outperforms a handbook" is not something the study
measured — it is an inference from the failure modes (agents losing rule
details over long horizons, overriding standing policy, reporting
compliance not achieved), the same status the LLM-staleness entry above
gives its own "therefore needs deterministic anchors" consequence. What
the study does show directly: self-reported compliance is not a usable
gate signal.

Locator: arXiv:2607.25398, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 8 /
Findings § "Long standing-instruction documents are followed poorly over
extended tool-use horizons").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Single-agent README generation matches multi-agent quality at a fraction of the cost

Saleh, Tesfay, Nguyen, Di Rocco, Zeshan, and Di Ruscio, "The Illusion of
Agentic Complexity in README.md Generation: Evaluating Single-Agent vs.
Multi-Agent RAG Systems" ([arXiv:2606.30524](https://arxiv.org/abs/2606.30524)):
a single-agent README-generation pipeline matched multi-agent lexical
quality while cutting token consumption by 86% and running twice as
fast; the multi-agent system won on structural consistency (98%),
resolving formatting issues seen in single-agent output; incorporating a
lightweight developer-guided plan produced the highest overall quality
of any configuration tested, with autonomous planning identified as the
primary single-agent bottleneck.

Locator: arXiv:2606.30524, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 7 /
Findings § "Single-agent README generation matches multi-agent quality
at a fraction of the cost").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Repository-doc generation is benchmarked against other generators, not humans

Nguyen Hoang, Le-Anh, Le, and Bui, "CodeWiki: Evaluating AI's Ability to
Generate Holistic Documentation for Large-Scale Codebases"
([arXiv:2510.24428](https://arxiv.org/abs/2510.24428)): CodeWiki reports
a 68.79% quality score against the closed-source DeepWiki baseline's
64.06% on an LLM-judged rubric benchmark across seven languages — a
machine-vs-machine comparison, with no human-authored-documentation
baseline in the reported numbers, and both scores below 70%. The "across
seven languages" detail is Claim-field-only in the sweep's Findings
entry; it is verified by the sweep's Independent verification addendum,
which quotes the paper's abstract directly: "CodeWiki, a unified
framework for automated repository-level documentation across seven
programming languages."

Locator: arXiv:2510.24428, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 7 /
Findings § "Repository-level documentation generation benchmarked
against a closed-source baseline, not humans"; Independent verification
addendum).
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md
