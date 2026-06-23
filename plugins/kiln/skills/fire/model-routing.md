# Kiln Model Routing

Loaded on-demand by `SKILL.md` at first Crafter dispatch. Cache result in-context for remaining tasks — do not reload per task.

---

## Model Assignment Table

| Class | Default model | Override condition | Rationale |
|---|---|---|---|
| refiner | sonnet | None | Dialogue and spec authoring require judgment but not deep codebase reasoning. Sonnet balances quality and cost for iterative Q&A. |
| planner | opus | None | Impact analysis and plan authoring require multi-file codebase reasoning. Opus provides the highest reasoning quality for scope classification. |
| crafter | sonnet | v2: see below | v1 constraint: Claude Code `model:` frontmatter is author-time only. Dynamic per-task routing (Haiku for mechanical, Sonnet for multi-file) requires the AI Classes compiler, which is a v2 concern (ADR-6). All crafter dispatches use sonnet in v1. |
| inspector | sonnet | None | Reviewer judgment on a per-task diff. Diff is small; Sonnet provides consistent adversarial evaluation without Opus overhead. |
| final code-quality-audit | sonnet | None | Full-branch diff review against code-quality-audit patterns. Consistent pattern evaluation at Sonnet quality. |

---

## Temperature Guidelines

| Class | Temperature | Reason |
|---|---|---|
| crafter | 0.0 | Deterministic tool-calling and TDD implementation; exact output required |
| inspector | 0.0 | Structured verdict format (`spec:`/`quality:`/`findings:`) must be machine-parseable |
| refiner | 0.3 | Iterative dialogue; some variation acceptable, mostly factual spec authoring |
| planner | 0.3 | Plan authoring; analysis-heavy, moderate creativity for narrative clarity |
| final code-quality-audit | 0.0 | Pattern evaluation against fixed rules; deterministic output preferred |

---

## v2 Intent: Dynamic Crafter Routing

The design spec (§7.3) describes complexity-driven crafter model selection:

| Compounds tier | Blast radius | v2 target model |
|---|---|---|
| TRIVIAL | N/A | haiku |
| STANDARD | LOW | haiku |
| STANDARD | HIGH | sonnet |

This routing is **not implemented in v1** because Claude Code agent `model:` frontmatter is set at author time, not dispatch time. The AI Classes compiler (v2) will generate agent files with the appropriate model per dispatch context.

Until v2 ships: all crafter dispatches use `model: sonnet`. The cost premium over Haiku on TRIVIAL/LOW-blast tasks is the accepted v1 tradeoff (ADR-6).
