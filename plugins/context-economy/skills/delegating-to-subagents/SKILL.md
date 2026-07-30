---
name: delegating-to-subagents
description: Use when about to hand work to a subagent, write a dispatch prompt, or correct a subagent that drifted or returned wrong output. Triggers include worth a subagent, delegate to Sonnet, should I use a subagent, write a dispatch prompt, subagent gave wrong output, subagent drifted, how do I delegate this, Task tool, explore agent, parallel search, broad codebase search.
---

# Delegating to Subagents

## When NOT to use

Skip when the task requires synthesis, judgment, or cross-cutting decisions — keep those on the main thread. Don't delegate an under-specified goal; specify it first.

This skill is the **cost/context-economy lens** on delegation — tier-cost math, the dispatch-quality gate, and the structured return contract. For *executing an implementation plan's* independent tasks, use `superpowers:subagent-driven-development` instead; reach for this one when the question is whether delegation *saves context/cost* and how to specify the dispatch so quality holds.

## Overview

When and how to push bounded work off the main thread to a cheaper subagent, and how to correct one that drifts. This serves the `context-economy` doctrine: delegation keeps the main thread lean — the subagent's noisy work runs in its own fresh context — while a cheaper tier does the bounded do-ing.

Called from `context-assembly` when the load decision is "delegate to subagent."

## When to delegate (main thread thinks, subagent does)

Keep the main thread as the brain. Push bounded *do-ing* — find, parse, execute, transform — to cheaper subagents. Two stacked levers: the cheaper tier costs materially less per token, AND the noisy work runs in the subagent's own fresh context, so it never bloats the main prefix that gets re-read every turn.

| Signal | Action |
|---|---|
| Bounded find/parse/exec with structured output | Delegate |
| Parallel independent searches | Delegate (one subagent each) |
| Synthesis, judgment, cross-cutting decisions | Keep on main |
| Under-specified goal | Do not delegate — specify first |

**Check:** before delegating, confirm the task fits a Delegate row above.

## Dispatch-quality gate (hard)

A subagent earns the delegation only with a well-specified dispatch prompt:

- **Explicit inputs** — what the subagent receives; assume no shared context.
- **Ordered steps** — the procedure, not just the goal.
- **Output contract** — the exact shape/format it returns.
- **Concrete done-check** — how it confirms it finished correctly (a command or a structured comparison).

Under-specified Sonnet is the "feels really dumb" failure mode. Delegation is a win only if quality holds — measure that it did, do not assume it.

**Check:** before dispatching a subagent, confirm the prompt hits all four checklist items.

> **Evidence status: mixed.** Tier cost math — cited (live per-tier pricing). One measured internal session showed a large total cost saving via Sonnet-subagent offload (directional on magnitude). "Sonnet needs explicit prompts" — practitioner consensus across multiple engineers, directional, not a controlled eval.

## Return contract

The parent thread receives a **structured summary** from the subagent: relevant file paths, extracted findings, and the result of the done-check. It does NOT receive raw tool dumps, pasted file bodies, or unfiltered command output — those stay in the subagent's context and are never forwarded up.

**Check:** subagent's output contract specifies what it returns, not just what it does.

## Worked example

> **Note:** Simplified illustration — not a live dispatch.

**Task:** Find every call site of `createEnvironmentAlias` in a monorepo.

**Inputs supplied to subagent:**
- `repo_path`: `/path/to/repo`
- `search_pattern`: `createEnvironmentAlias`

**Steps (ordered):**
1. `grep -rn "createEnvironmentAlias" <repo_path> --include="*.ts" --include="*.js"` → collect raw matches.
2. For each match, read 5 lines of enclosing context to confirm it is a call site (not a type declaration).
3. Assemble findings into the output shape below.
4. Run done-check.

**Output shape:**
```json
{
  "findings": [
    { "file": "src/api/alias.ts", "line": 42, "summary": "call in createAlias handler" }
  ],
  "total": 3
}
```

**Done-check:** `grep -c "createEnvironmentAlias" <repo_path> -r --include="*.ts" --include="*.js"` must equal `findings.total`.

## Correcting a subagent that drifts

Re-steer with specific, direct feedback — name the failed assertion, point at the stacktrace — instead of polite hedging paragraphs.

**Guardrail:** direct is not the same as frustrated. Emotional pressure ("desperation") tends to *increase* hallucination; the lever is specificity and bluntness about the problem, not venting.

**Check:** a correction names the specific defect (assertion / file / line), not a feeling.

> **Evidence status: house heuristic, anecdotal.** Practitioner observation that blunt, specific correction re-steers faster than polite hedging (seen in reasoning traces), with a counterpoint that desperation-framed prompts raise hallucination. Team-practice heuristic, not a controlled eval — flagged as such.

## Research Sources (measured studies only)

| Study | Key finding |
|---|---|
| Live per-tier pricing (platform.claude.com) | Opus → Sonnet is a deterministic per-token cut on input/output/cache-read. |

Practitioner/vendor heuristics live in the inline Evidence-status callouts above, never in this table.
