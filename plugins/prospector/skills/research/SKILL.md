---
name: research
description: Use when researching a question across our systems, finding where something lives, tracing how a feature/service works, digging into why a decision was made, investigating across repos/Confluence/Slack/Jira, or producing a cited research report or decision memo. Triggers include "research", "how does X work", "where does X live", "why did we", "dig into", "find out across our systems", "look into this for me".
---

# Prospector — Research Method

Discovery-first research: the job is to find **where** an answer lives, then read it, verify it, and synthesize it. Sources and output shape are parameters.

**Progressive disclosure — load on demand:**
- `sources.md` — the source roster and per-domain fidelity ladder (load before Round 1).
- `method.md` — the four phases in detail: discover, deepen, verify, synthesize (load before executing).
- `output-shapes.md` — report / decision-memo / context-handoff section skeletons (load at synthesis).

## Step 1 — Resolve output destination and shape

- If the question names a Jira key (`[A-Z]+-\d+`) or an active project, destination is `projects/active/<key-or-project>/research/<slug>.md`. Otherwise `research/YYYY-MM-DD-<slug>.md`.
- Output shape: honor `--output report|memo|handoff` if given; else infer (a "should we / which" question → memo; "how/where/why" → report; feeds-other-work → handoff).
- State the resolved destination and shape in one line before proceeding.

## Step 2 — Choose the execution path (context detection)

- **Main context:** launch the Layer 2 Workflow (`workflow.js`) via the `Workflow` tool for real parallel fan-out and adversarial verify. See `method.md` §Engine.
- **Inside a subagent** (you were dispatched with a task and cannot spawn a Workflow): follow `method.md` inline, single-threaded. Do the same phases by hand.

Decide by checking whether you can call the `Workflow` tool. If a Workflow launch is unavailable, run inline.

## Step 3 — Execute the four phases

Load `method.md` and follow Discover → Deepen → Verify → Synthesize. Load `sources.md` for the roster and `output-shapes.md` at synthesis.

## Done-check

Before reporting complete, confirm ALL of:
1. The output file exists at the resolved destination.
2. Every load-bearing claim in the answer has a source pointer.
3. A `## Sources` section lists each source with its fidelity tier and any staleness caveat.
If any is missing, complete it before reporting. State the file path and the count of load-bearing claims verified.
