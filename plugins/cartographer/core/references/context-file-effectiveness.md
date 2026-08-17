# Reference: Context-File and Skill-File Effectiveness Evidence

Full-tier evidence on whether repository-level context files and Claude
Code skills measurably improve agent task outcomes. Loaded on demand from
`core/knowledge/` `see:` markers (RC-4).

## AGENTS.md and context files: a null result on task success

Gloaguen, Mündler, Müller, Raychev, and Vechev, "Evaluating AGENTS.md: Are
Repository-Level Context Files Helpful for Coding Agents?"
([arXiv:2602.11988](https://arxiv.org/abs/2602.11988)): repository-level
context files as a class do not reliably improve coding-agent task
success while raising inference cost by more than 20% on average; the
null result held across models, agents, and both LLM-generated and
developer-committed files.

Locator: arXiv:2602.11988, transcribed via `kiln/design.md` § "Research
basis".
Status: transcribed-from kiln/design.md

## Focused skills outperform comprehensive docs

Study: SkillsBench, 86 tasks across 11 domains. Finding: focused skills
covering 2–3 modules outperformed comprehensive documentation by +16.2pp
average; self-generated skills yielded zero benefit, and over-narrow
fragments hurt too (a bidirectional failure mode, per the source's own
"lower bound" discussion).

Locator: [SkillsBench](https://arxiv.org/pdf/2602.12670), transcribed via
`plugins/gauntlet/skills/skill-audit/principles-shared.md#philosophy` and
`plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#2-focus-beats-breadth-with-a-lower-bound`.
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## Most skills yield zero improvement; version-mismatch is harmful

Study: SWE-Skills-Bench, 49 skills across 565 tasks. Findings: 80% of
skills yielded zero improvement; the 7 that worked were narrow and
domain-specific; 3 skills were actively harmful, causing roughly -10%
performance degradation via version-mismatched guidance (code examples
that no longer matched the actual repo).

Locator: [SWE-Skills-Bench](https://arxiv.org/pdf/2603.15401), transcribed
via `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#1-accuracy-over-comprehensiveness`.
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## Instruction count degrades performance monotonically

Study: "When Instructions Multiply"
([arXiv:2509.21051](https://arxiv.org/abs/2509.21051)), ManyIFEval /
StyleMBPP. Finding: performance degrades monotonically with instruction
count, predictable to within ~10% error from instruction count alone —
independent corroboration for keeping any always-loaded guidance file
short and front-loaded.

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#research-sources`
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## Long context buries mid-context information

Study: "Lost in the Middle"
([arXiv:2307.03172](https://arxiv.org/abs/2307.03172)), Liu et al.,
Stanford/Berkeley. Finding: long context buries mid-context information —
load-bearing instructions placed mid-document are less reliably followed
than instructions at the start or end.

Locator: `plugins/gauntlet/skills/skill-authoring-principles/SKILL.md#research-sources`
Status: transcribed-from plugins/gauntlet/skills/skill-authoring-principles/SKILL.md

## doc-patterns cites Cartographer's files; Cartographer cites nothing back

`doc-types.md` § 6's Source line names Cartographer's own
`file-format-agents-md.md` and `file-format-claude-md.md` (in
`contentful/agents-kit`) as sources for its AGENTS.md structural template.
`doc-patterns` therefore already treats those currently-uncited
Cartographer knowledge files as authoritative, while Cartographer itself
cites nothing back to `doc-patterns` or to any external research. This is
the concrete in-tree instance of the evidentiary gap this slice's
`core/knowledge/` + `core/references/` split exists to close.

Locator: `plugins/gauntlet/skills/doc-patterns/doc-types.md#6-agentsmd-and-claudemd-by-extension`
Status: transcribed-from plugins/gauntlet/skills/doc-patterns/doc-types.md
