# Reference: README Section Necessity — the Litmus Test

Full-tier evidence for what a generated README section must earn its place
with before Cartographer drafts it. Loaded on demand from `core/knowledge/`
`see:` markers (RC-4); never loaded by default.

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

Locator: arXiv:2602.11988, transcribed via `kiln/design.md` § "Research
basis: not every README section is worth its cost by default".
Status: transcribed-from kiln/design.md

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

Locator: arXiv:2602.11988, transcribed via `kiln/design.md` § "Research
basis: not every README section is worth its cost by default".
Status: transcribed-from kiln/design.md

## The AGENTS.md inclusion litmus test

`contentful-update-agents-md` conventions' litmus test, cited in
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
~100 lines as a content-discipline target, not a soft guideline, "to
ensure the routing table remains scannable and does not degrade agent
performance." This size and category discipline is a direct antecedent
for a generated README section's own necessity test.

Locator: `plugins/gauntlet/skills/doc-patterns/doc-types.md#6-agentsmd-and-claudemd-by-extension`
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/doc-types.md
