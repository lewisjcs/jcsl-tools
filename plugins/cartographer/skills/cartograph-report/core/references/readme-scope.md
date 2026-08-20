# Reference: README Section Necessity — the Litmus Test

Full-tier evidence for what a generated README section must earn its place
with before Cartographer drafts it. Loaded on demand from `core/knowledge/`
`see:` markers (RC-4); never loaded by default.

## Table of contents

- [Repository-context files: null result on task success, positive cost](#repository-context-files-null-result-on-task-success-positive-cost)
- [Concrete instructions succeed; generic overviews do not](#concrete-instructions-succeed-generic-overviews-do-not)
- [The AGENTS.md inclusion litmus test](#the-agentsmd-inclusion-litmus-test)
- [Bloat and misplaced content are hard failure classes, not style choices](#bloat-and-misplaced-content-are-hard-failure-classes-not-style-choices)
- [README content skews to "What" and "How"; purpose and status are commonly absent](#readme-content-skews-to-what-and-how-purpose-and-status-are-commonly-absent)
- [README structural features correlate with project popularity](#readme-structural-features-correlate-with-project-popularity)
- [README updates almost never accompany code changes, and some should](#readme-updates-almost-never-accompany-code-changes-and-some-should)
- [LLM staleness judges are blind to the drift direction that matters most](#llm-staleness-judges-are-blind-to-the-drift-direction-that-matters-most)
- [Outdated code-element references are near-universal in repository docs](#outdated-code-element-references-are-near-universal-in-repository-docs)
- [Vendor spec: AGENTS.md is a README for agents, not a README replacement](#vendor-spec-agentsmd-is-a-readme-for-agents-not-a-readme-replacement)

## Repository-context files: null result on task success, positive cost

Gloaguen, Mündler, Müller, Raychev, and Vechev, "Evaluating AGENTS.md: Are
Repository-Level Context Files Helpful for Coding Agents?"
([arXiv:2602.11988](https://arxiv.org/abs/2602.11988)), found that
repository-level context files as a class do not reliably improve
coding-agent task success while raising inference cost by more than 20% on
average. The null result held across models, agents, and both
LLM-generated and developer-committed files. This is the load-bearing
reason a generated README section must justify its own existence rather
than being included because the section name is conventional.

Locator: arXiv:2602.11988, transcribed via
`core/references/sources/design-research-basis-2026-08-17.md` § "Research
basis: not every README section is worth its cost by default".
Status: transcribed-from core/references/sources/design-research-basis-2026-08-17.md

## Concrete instructions succeed; generic overviews do not

The same study (arXiv:2602.11988) found concrete, actionable instructions
in context files are well followed by coding agents, while generic
repository overviews are not helpful despite being popular and recommended
by model providers — context files are best suited to documenting
non-standard practices, not general repository description. This is the
governing distinction between Cartographer's generic-overview-shaped
draft sections (repository at a glance, architecture overview) and its
concrete-instruction-shaped sections (quick start, known constraints, for
AI agents): the former carries the paper's unhelpful-but-costly profile,
the latter its effective profile.

Locator: arXiv:2602.11988, transcribed via
`core/references/sources/design-research-basis-2026-08-17.md` § "Research
basis: not every README section is worth its cost by default".
Status: transcribed-from core/references/sources/design-research-basis-2026-08-17.md

## The AGENTS.md inclusion litmus test

The internal AGENTS.md-conventions doctrine's litmus test, cited in
`doc-patterns/doc-types.md`: "If removing this line would cause an agent
to violate a repo constraint it has no other way to learn, the line
belongs. Otherwise it does not." The same file states the companion
**bloat rule**: content discoverable elsewhere (script enumerations,
build commands already in a manifest, file-structure listings, setup
commands) is bloat, and bloated context files reduce agent task success
rates and increase inference cost. Applied to Cartographer's own drafted
README sections, not only to AGENTS.md, this is the same yes/no test a
"repository at a glance" section must pass before Cartographer emits it.

Locator: `plugins/gauntlet/skills/doc-patterns/doc-types.md#6-agentsmd-and-claudemd-by-extension`
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/doc-types.md

## Bloat and misplaced content are hard failure classes, not style choices

`doc-types.md` § 6 states the bloat rule and the misplaced rule as **hard
rules**, not soft guidance: state-management decision trees, multi-line
code examples, dependency/build/lint tool preferences, and procedural
instructions are `misplaced` in an AGENTS.md-class file and belong in
skills or hooks instead. Root AGENTS.md must additionally stay under
~100 lines as a content-discipline target, not a soft guideline —
"it ensures the routing table remains scannable and does not degrade
agent performance." This size and category discipline is a direct
antecedent for a generated README section's own necessity test.

**Reconciling note (uncorroborated doctrine, per the same discipline the
two `authoring-conventions.md` house-heuristic entries carry):** the
bloat rule's *cost* half is corroborated externally — arXiv:2602.11988
(§ "Repository-context files: null result on task success, positive
cost" above) independently found context files raising inference cost by
over 20% on average. The bloat rule's *task-success* half ("bloated
context files reduce agent task success rates", stated two entries above)
has no external study behind it in this sweep — it is internal house
doctrine (transcribed from `doc-types.md`), and it sits in direct
tension with arXiv:2602.11988's
own null result on task success. Treat the task-success clause as
uncorroborated doctrine transcribed from `doc-types.md`, not as an
independently verified finding.

Locator: `plugins/gauntlet/skills/doc-patterns/doc-types.md#6-agentsmd-and-claudemd-by-extension`
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/doc-types.md

## README content skews to "What" and "How"; purpose and status are commonly absent

Prana, Treude, Thung, Atapattu, and Lo, "Categorizing the Content of
GitHub README Files" ([arXiv:1802.06997](https://arxiv.org/abs/1802.06997)
/ Empirical Software Engineering 2019): manual annotation of 4,226 README
sections from 393 randomly sampled GitHub repositories found "What" and
"How" content very common, while many READMEs lack information regarding
purpose and status; an eight-category multi-label classifier reached F1
0.746, and a majority of 20 surveyed practitioners perceived automated
section labeling as easing information discovery.

Locator: arXiv:1802.06997, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 3 /
Findings § "README content skews to 'What' and 'How'; purpose and status
are commonly absent"; Independent verification addendum).
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## README structural features correlate with project popularity

Venigalla and Chimalakonda, "An Empirical Study On Correlation between
Readme Content and Project Popularity"
([arXiv:2206.10772](https://arxiv.org/abs/2206.10772)): across 1,950
READMEs spanning ten languages, popular projects' READMEs were well
organized with lists and images and linked to external sources;
contribution guidelines and references were associated with higher
popularity. Correlational, not causal — popularity, not onboarding
success, is the measured outcome.

Locator: arXiv:2206.10772, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 2 /
Findings § "README structural features correlate with project
popularity").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## README updates almost never accompany code changes, and some should

Gao, Lin, Treude, Gay, and Zahedi, "Does My README File Need To Be
Updated? Exploring LLM-Based README Maintenance"
([arXiv:2603.00489](https://arxiv.org/abs/2603.00489)): across 27,772
PRs from 714 repositories, only 0.8% of PRs modified the README, and
21.5% of recommendations on PRs that did not update the README were
judged valid updates overlooked during development; the best-performing
agentic detector reached 98.7% specificity but only 28.7% user-facing
accuracy.

Locator: arXiv:2603.00489, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 2 /
Findings § "README updates are rare in PRs and a fifth of 'no-update' PRs
actually warranted one"; Independent verification addendum).
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## LLM staleness judges are blind to the drift direction that matters most

Ulfat, Sabit, and Hossain, "Measuring LLM Trust Allocation Across
Conflicting Software Artifacts"
([arXiv:2604.03447](https://arxiv.org/abs/2604.03447)): across 22,339
responses from seven LLMs on 456 Java method bundles, models detected
documentation faults at 67–94%, but detection fell by 21–43 percentage
points when only the implementation changed and the documentation stayed
intact; model confidence provided little separation between correct and
incorrect judgments for six of seven models. A Cartographer drift check
therefore needs deterministic anchors (symbol/path existence), not model
self-judgment.

Locator: arXiv:2604.03447, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 4 /
Findings § "LLMs detect documentation faults but are blind to
implementation-only drift"; Independent verification addendum).
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Outdated code-element references are near-universal in repository docs

Tan, Wagner, and Treude, "Detecting Outdated Code Element References in
Software Repository Documentation"
([arXiv:2212.01479](https://arxiv.org/abs/2212.01479)): analysis of over
3,000 GitHub projects found that most projects contain at least one
code-element reference that survived in documentation after every source
instance was deleted, at some point in their history.

Locator: arXiv:2212.01479, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 13 /
Findings § "Outdated code element references are near-universal in
repository documentation"; Independent verification addendum).
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Vendor spec: AGENTS.md is a README for agents, not a README replacement

The AGENTS.md open specification positions the file as complementary to
the human README: "a README for agents: a dedicated, predictable place
to provide the context and instructions to help AI coding agents work on
your project," carrying "the extra, sometimes detailed context coding
agents need: build steps, tests, and conventions that might clutter a
README or aren't relevant to human contributors." The spec imposes no
required fields or schema ("AGENTS.md is just standard Markdown. Use any
headings you like"). The spec also claims usage by "over 60k open-source
projects" — a self-reported GitHub code-search count, not an audited
number.

Locator: [agents.md](https://agents.md/) (as of 2026-08-17), transcribed
via `core/references/sources/external-sweep-2026-08-17.md` (Query 9 /
Findings § "Vendor spec: AGENTS.md is positioned as a README for agents,
with adoption scale").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md
