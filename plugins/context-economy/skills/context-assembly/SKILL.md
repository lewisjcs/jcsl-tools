---
name: context-assembly
description: Use when about to load files, logs, grep output, or MCP payloads into the main thread. Triggers include read the whole repo, grep everywhere, large test output, too many files, what context do I need, scope this search, narrow the read, output to file then grep, static vs dynamic context, MCP dump, tool output bloat.
---

# Context Assembly

## When NOT to use

Skip when making a single targeted read of a known path — no scoping decision needed.

## Overview

Scope context before it hits the main thread. This is the assembly layer from the agentic stack — domain scoping and entity resolution before serving ([references/agentic-stack-map.md](../../references/agentic-stack-map.md)).

Invoke this skill from `context-economy` whenever you are about to load files, logs, grep output, or MCP payloads into the orchestrator context.

## Load vs retrieve vs delegate

| Need | Action |
|---|---|
| Know *if* something exists | `grep` / semantic search / narrow glob first |
| Need a specific symbol or section | Read only that file (or line range), not the directory |
| Need exploration across many files | **`delegating-to-subagents`** — explore subagent returns a summary + paths |
| Large command output (>~100 lines) | Write to file; grep the relevant lines into context |
| Repeated doc lookup | MCP/search on demand; do not paste full pages |

**Check:** list what you will load (file paths or query) and estimated scope before the first Read. If >3 files or >1 full file, delegate or narrow first.

## Read-narrow patterns

1. **Grep → Read** — locate symbol, then read the enclosing function/module.
2. **Head/tail → grep** — for logs: `tail` or saved file + pattern, not full CI output.
3. **One hop deep** — follow imports one level; do not transitive-read the tree.
4. **Return contract** — when a subagent reads for you, it returns findings + paths, not pasted file bodies.

**Check:** after loading, state what you loaded and what you deliberately excluded.

> **Evidence status: cited.** Tyler token analysis: code reading + MCP are small buckets individually but each call re-reads the full session prefix; narrowing reads attacks context×turns.

## Static prefix discipline

Do not promote task-specific context into always-loaded surfaces (CLAUDE.md, MEMORY.md index, skill descriptions). Task context belongs in dynamic loads or handoff files.

**Check:** confirm the loaded material is not being written to an always-on file unless explicitly requested.

## Research Sources (measured studies only)

| Study | Key finding |
|---|---|
| Lost in the Middle (arXiv 2307.03172) | Middle context is retrieved poorly — smaller high-signal windows beat large noisy ones. |
| When Instructions Multiply (arXiv 2509.21051) | More instructions → predictable quality drop; scope beats volume. |

See also [references/research-corpus.md](../../references/research-corpus.md).
