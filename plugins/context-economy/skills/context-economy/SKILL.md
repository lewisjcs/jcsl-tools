---
name: context-economy
description: Use when a session is long, context is filling up, steady-state context exceeds ~100K tokens, or you are about to load large file dumps, broad grep results, or MCP payloads into the main thread. Triggers include clear or compact, should I clear, session long, session getting long, context filling up, context rot, token budget, too much context, context too expensive, is a compressor worth it, prefix bloat, cache read compounding, about to grep, read many files, MCP dump, explore codebase, parallel search.
---

<HARD-GATE>
Before any Read of more than one file, Grep without a path, MCP fetch of full documents, or Task/explore dispatch: read this skill, match a lever-router row, invoke the sibling skill or action, and state the match in one line.
</HARD-GATE>

# Context Economy

## When NOT to use

Skip for a single targeted file read or a lookup already scoped to one symbol — no lever decision needed.

<!-- Shared trigger phrases with context-assembly ("about to grep", "read many files", "MCP dump") are intentional: this skill fires first and routes to context-assembly via the lever router. -->

## Overview

Spend main-thread context deliberately. ~86.6% of measured spend is the cached prefix re-read every turn; subagent tier routing alone caps at ~3% savings. The levers that matter: reset long sessions, scope what you load, delegate noisy work, return only summaries to the parent.

Lean context is also higher-accuracy context — multi-fact reasoning degrades well before the window fills ([NoLiMa](https://arxiv.org/abs/2502.05167), [Lost in the Middle](https://arxiv.org/abs/2307.03172)).

**Sibling skills in this plugin:** `context-assembly` (what to load), `delegating-to-subagents` (what to push off-thread), `handoff` (checkpoint before reset). Deep research: [references/research-corpus.md](../references/research-corpus.md). Stack map: [references/agentic-stack-map.md](../references/agentic-stack-map.md).

## Lever router

Before a high-token action, name which lever applies:

| Signal | Skill / action |
|---|---|
| Task finished or switching tickets | **`/clear`** |
| Mid-task, checkpointable | **`handoff` → `/clear` → resume** |
| Mid-task, uncheckpointable | **`/compact <focus>`** (last resort) |
| About to read many files, large logs, or broad grep | **`context-assembly`** |
| Noisy find/parse/exec that returns a summary | **`delegating-to-subagents`** |
| Turn count high, same ticket continues | Apply clear-vs-compact row below |

**Check:** state which row you matched and which skill you invoked before proceeding.

## Clear vs. compact

| Situation | Action |
|---|---|
| Task boundary / unrelated next work | **`/clear`** — fully resets the prefix |
| Mid-task, need continuity, cannot checkpoint | **`/compact <focus>`** — lossy summary, last resort |
| Mid-task but checkpointable | **`handoff` → `/clear` → resume from file** (preferred default) |

`/clear` is the default. Compaction invalidates the conversation-layer prompt cache; compaction without `/clear` lets `cache_read` compound across a long session.

**Important:** assistant turn count alone is not a task boundary. High turn count in an agentic session (subagent fan-out, workflow loops) is not a signal to `/clear` mid-task — match the lever-router row first.

**Check:** name which row applies, then act.

> **Evidence status: cited.** CC `prompt-caching.md`; internal baseline ~86.6% of $ is cache-read; marathon sessions (>100 turns) ≈ 92% of tokens (Tyler analysis).

## Context budget (static / dynamic / enforced)

| Class | What | Rule |
|---|---|---|
| **Static** | CLAUDE.md, always-on rules, skill descriptions | Minimize — every token every turn |
| **Dynamic** | Skill bodies, file reads, MCP results, tool output | Load on demand; scope before read |
| **Enforced** | Hooks (reset-nudge), checkpoint files | Runs regardless of model memory |

Treat steady-state working context above **~50% of the effective window** as a danger signal; **200K+** on a turn is a split-session signal (hygiene + accuracy).

**Check:** before adding context to the main thread, classify it static/dynamic/enforced and confirm dynamic loads are scoped.

> **Evidence status: mixed.** Google SDLC harness paper (static vs dynamic); internal per-turn context distribution (median ~7% of 1M window, p99 ~52%, marathon tail dominates spend).

## Anti-levers (settled)

No third-party compressors/routers, no external gateways for cost on source code. They risk cache-prefix invalidation and require third-party egress approval.

**Check:** if evaluating a compressor, stop — use native levers in the lever router instead.

> **Evidence status: cited.** 2,100-measurement RTK benchmark; in-org refutation of vendor savings claims.

## Research Sources (measured studies only)

| Study | Key finding |
|---|---|
| NoLiMa (arXiv 2502.05167) | Multi-fact reasoning degrades before the window fills — lean context is more accurate, not just cheaper. |
| Lost in the Middle (arXiv 2307.03172) | U-shaped retrieval — critical rules belong at context boundaries. |
| Internal ccusage baseline (deduped v20) | ~86.6% of $ is cache-read; Opus ~97%; sessions >100 turns ≈ 92% of tokens. |
| Third-party-compression benchmark | Vendor claims not reproduced; enabling doubled tokens on a terminal benchmark. |

Practitioner heuristics live in inline Evidence-status callouts and [references/research-corpus.md](../references/research-corpus.md).
