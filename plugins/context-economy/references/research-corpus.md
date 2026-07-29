# Context Economy — Research Corpus

Measured studies and internal baselines cited by the context-economy plugin skills. Load on demand when grounding a claim or designing an eval.

## Core thesis (both cost and accuracy)

Lean context is not a cost hack — it is an accuracy requirement. Multi-fact retrieval and reasoning degrade well before the context window fills.

| Study | Sample | Key finding |
|---|---|---|
| [Lost in the Middle](https://arxiv.org/abs/2307.03172) (Liu et al.) | Multi-doc QA, key-value retrieval | U-shaped performance: models retrieve best from start/end; middle placement drops accuracy 10–20pp vs boundaries. |
| [NoLiMa](https://arxiv.org/abs/2502.05167) | Long-context eval beyond literal matching | Multi-hop reasoning fails at shorter effective lengths than single-fact NIAH; attention limits dominate over position encoding at scale. |
| [When Instructions Multiply](https://arxiv.org/abs/2509.21051) | ManyIFEval / StyleMBPP | Performance degrades monotonically with instruction count (~10% predictable from count alone). |
| [SWE-Skills-Bench](https://arxiv.org/pdf/2603.15401) | 49 skills, 565 tasks | 80% of skills yield zero improvement; version-mismatched examples caused ~10% harm. |
| [SkillsBench](https://arxiv.org/pdf/2602.12670) | 86 tasks, 11 domains | Focused 2–3 module skills +16.2pp vs comprehensive docs. |

## Agent context compression (research frontier — not our anti-lever)

These study *guided* compression with failure feedback — different from third-party prompt compressors that process source code off-box.

| Study | Key finding |
|---|---|
| [Acon](https://arxiv.org/abs/2510.00615) (Microsoft) | Iteratively refines natural-language compression guidelines from agent failures; 26–54% peak-token reduction on long-horizon benchmarks while preserving task success. |
| [LCLMs / End-to-End Context Compression](https://arxiv.org/html/2606.09659v1) | Latent compression before decoder prefill; agentic expand-on-demand for needle tasks. Production infra, not a Claude Code plugin swap-in. |

## Internal measured baselines (Contentful, deduped ccusage v20)

| Finding | Source |
|---|---|
| ~86.6% of $ is cache-read (prefix re-sent every turn) | Josh + Tyler token analyses; `projects/active/token-optimization/baseline/ccusage-baseline.md` |
| ~97% of spend on Opus tier | Same |
| Sessions >100 turns ≈ 92% of tokens; top ~4% of sessions ≈ 50% | Tyler Confluence analysis |
| Main thread ≈ 88.6% of $ — subagent model routing caps at ~3% savings alone | `docs/superpowers/specs/2026-06-10-context-economy-design.md` |
| Third-party compressor benchmark: ~0 real compression; one run doubled tokens | RTK issue tracker + in-org refutation |

## Practitioner / vendor (graded inline in skills — not in measured table)

- Google SDLC + vibe-coding paper: Agent = Model + Harness; static vs dynamic context; skills as progressive disclosure ([Slack PDF in #ai-driven-dev](https://contentful.slack.com/files/U07J2P4SX62/F0BAU9E851T/the_new_sdlc_with_vibe_coding.pdf), Jun 2026)
- Glean token economy whitepaper: context engineering as financial lever; six context types; Agent Skills pattern ([PDF](https://get.glean.com/rs/626-JWX-444/images/glean-token-economy-whitepaper.pdf?version=1))
- Sunil Pai "Never Waste a Token": infrastructure-layer re-prompt waste on crash ([post](https://sunilpai.dev/posts/never-waste-a-token/)); tracked in `knowledge/article-never-waste-a-token.md`
- Zach Lloyd self-improvement loop: inner loop runs skill, outer loop diffs skill from human feedback ([LinkedIn](https://www.linkedin.com/pulse/how-build-self-improvement-loop-your-skills-zach-lloyd-aandc))

## Eval-first reminder

Before expanding any skill in this plugin, baseline ≥3 representative tasks *without* the skill, then re-run with it. Most skills yield zero improvement in benchmarks — prove yours doesn't. **STOP: do NOT expand the skill if the with-skill run does not beat the baseline. If delta ≤ 0, leave the skill unchanged and record the negative result.**
