# Reference: Context-File and Skill-File Effectiveness Evidence

Full-tier evidence on whether repository-level context files and Claude
Code skills measurably improve agent task outcomes. Loaded on demand from
`core/knowledge/` `see:` markers (RC-4).

## Table of contents

- [AGENTS.md and context files: a null result on task success](#agentsmd-and-context-files-a-null-result-on-task-success)
- [Focused skills outperform comprehensive docs](#focused-skills-outperform-comprehensive-docs)
- [Most skills yield zero improvement; version-mismatch is harmful](#most-skills-yield-zero-improvement-version-mismatch-is-harmful)
- [Instruction count degrades performance monotonically](#instruction-count-degrades-performance-monotonically)
- [Long context buries mid-context information](#long-context-buries-mid-context-information)
- [doc-patterns cites Cartographer's files; Cartographer cites nothing back](#doc-patterns-cites-cartographers-files-cartographer-cites-nothing-back)
- [Context files do not move correctness in a two-agent controlled ablation](#context-files-do-not-move-correctness-in-a-two-agent-controlled-ablation)
- [Context files are configuration-like artifacts skewed to functional content](#context-files-are-configuration-like-artifacts-skewed-to-functional-content)
- [Configuration smells are widespread in AGENTS.md/CLAUDE.md files](#configuration-smells-are-widespread-in-agentsmdclaudemd-files)
- [Iteratively tuned repository guidance raises task-resolve rate](#iteratively-tuned-repository-guidance-raises-task-resolve-rate)
- [Updating rule files measurably improves artifact compliance](#updating-rule-files-measurably-improves-artifact-compliance)
- [AGENTS.md presence reduces agent runtime and output tokens](#agentsmd-presence-reduces-agent-runtime-and-output-tokens)

## AGENTS.md and context files: a null result on task success

Gloaguen, Mündler, Müller, Raychev, and Vechev, "Evaluating AGENTS.md: Are
Repository-Level Context Files Helpful for Coding Agents?"
([arXiv:2602.11988](https://arxiv.org/abs/2602.11988)): repository-level
context files as a class do not reliably improve coding-agent task
success while raising inference cost by more than 20% on average; the
null result held across models, agents, and both LLM-generated and
developer-committed files.

Locator: arXiv:2602.11988, transcribed via
`core/references/sources/design-research-basis-2026-08-17.md` § "Research
basis: not every README section is worth its cost by default".
Status: transcribed-from core/references/sources/design-research-basis-2026-08-17.md

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

## Context files do not move correctness in a two-agent controlled ablation

Khatri, "Do Context Files Help Coding Agents? A Two-Agent Ablation Study
on Real Repositories" ([arXiv:2607.27250](https://arxiv.org/abs/2607.27250)):
across 288 evaluated runs on two frontier agents (Claude Code and Codex)
over 17 real tasks from 3 repositories, context-injection strategy
produced no measurable correctness effect on either agent, bounded to
≤10–15 percentage points by equivalence testing; a failure-mode triage
attributed failures to implementation skill — feature design, pattern
selection, exact wiring — not missing repository knowledge a context
file could supply, and a manipulation probe confirmed the real AGENTS.md
never converted a near-miss to a pass on either agent. This directly
constrains what Cartographer can claim: generated context is not shown
to be a correctness lever.

Locator: arXiv:2607.27250, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 1 /
Findings § "Context files do not move correctness in a two-agent
controlled ablation").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Context files are configuration-like artifacts skewed to functional content

Chatlatanagulchai et al., "Agent READMEs: An Empirical Study of Context
Files for Agentic Coding" ([arXiv:2511.12884](https://arxiv.org/abs/2511.12884)):
in 2,303 context files from 1,925 repositories, developers overwhelmingly
document test procedures (75.9%), implementation details (70.8%), and
architecture (68.1%), while non-functional requirements — security
(14.8%) and performance (14.5%) — are rarely specified; the study
characterizes these files as evolving "like configuration code through
frequent, small additions" rather than static documentation.

Locator: arXiv:2511.12884, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 1 /
Findings § "Context files are configuration-like artifacts skewed to
functional content").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Configuration smells are widespread in AGENTS.md/CLAUDE.md files

dos Santos, Costa, Montandon, Silva, and Valente, "Configuration Smells
in AGENTS.md Files: Common Mistakes in Configuring Coding Agents"
([arXiv:2606.15828](https://arxiv.org/abs/2606.15828)): across 100
popular open-source repositories with an AGENTS.md or CLAUDE.md, Lint
Leakage affected 62% of files, Context Bloat 42%, and Skill Leakage 35%;
Context Bloat, Skill Leakage, and Conflicting Instructions frequently
co-occurred. A ready-made, named anti-pattern set with published base
rates for a Cartographer quality check.

Locator: arXiv:2606.15828, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 1 /
Findings § "Configuration smells are widespread in AGENTS.md/CLAUDE.md
files").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Iteratively tuned repository guidance raises task-resolve rate

Shepard and Albrecht, "Probe-and-Refine Tuning of Repository Guidance for
Coding Agents" ([arXiv:2606.20512](https://arxiv.org/abs/2606.20512)):
on SWE-bench Verified across four independent trials with
Qwen3.5-35B-A3B at 200 steps, probe-and-refine tuning of a repository
guidance file reached 33.0% mean resolve rate versus 28.3% for the
static knowledge base used to initialize it and 25.5% for an unguided
baseline (p<0.001 for both contrasts). The strongest counterweight found
to the null-result cluster above: guidance quality produced by an
iterative probe loop, not a single generation pass, does move task
success.

Locator: arXiv:2606.20512, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 1 /
Findings § "Iteratively tuned repository guidance raises SWE-bench
Verified resolve rate").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## Updating rule files measurably improves artifact compliance

Cai, Li, Liang, Li, and Shahin, "Rule Taxonomy and Evolution in AI IDEs:
A Mining and Survey Study" ([arXiv:2606.12231](https://arxiv.org/abs/2606.12231)):
mining 83 open-source projects and 7,310 rules, and assessing 160 rule
evolution events, found average artifact compliance rose from 49.14% to
72.13% (+22.99pp) after a rule update; 99 surveyed practitioners reported
editing rules mainly to correct AI errors (77.78%), typically by adding
new negative constraints. The study also found a mismatch: developers
rate architectural constraints as highly important, but rule files
primarily consist of low-level workflow and formatting constraints.

Locator: arXiv:2606.12231, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 1 /
Findings § "Updating rule files measurably improves artifact
compliance").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md

## AGENTS.md presence reduces agent runtime and output tokens

Lulla, Mohsenimofidi, Galster, Zhang, Baltes, and Treude, "On the Impact
of AGENTS.md Files on the Efficiency of AI Coding Agents"
([arXiv:2601.20404](https://arxiv.org/abs/2601.20404)): across 10
repositories and 124 pull requests, presence of an AGENTS.md was
associated with 28.64% lower median runtime and 16.58% lower output
token consumption, with comparable task completion behavior. Pairs with
the arXiv:2607.27250 null result above: the defensible claim is
efficiency (cost, latency), not correctness.

Locator: arXiv:2601.20404, transcribed via
`core/references/sources/external-sweep-2026-08-17.md` (Query 10 /
Findings § "AGENTS.md presence reduces agent runtime and output
tokens").
Status: transcribed-from core/references/sources/external-sweep-2026-08-17.md
