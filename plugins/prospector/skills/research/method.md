# Method — The Four Phases

Discovery-first research runs in four phases, in order. Each phase ends in a
concrete, checkable step — a condition a literal executor evaluates as done or
not-done, never a reminder. The prose here IS the contract both execution paths
implement: the Layer 2 `Workflow` (main context) and the inline single-threaded
pass (inside a subagent such as `kiln:scout`).

Load `sources.md` before the Discover phase — it holds the tool roster per round
and the provenance tag strings the Sources section records verbatim. This file
references that fidelity ladder by pointer and does not restate the roster.

## Table of contents
- [Phase 1 — Discover](#phase-1--discover)
- [Phase 2 — Deepen](#phase-2--deepen)
- [Phase 3 — Verify](#phase-3--verify)
- [Phase 4 — Synthesize](#phase-4--synthesize)
- [Load-bearing claim](#load-bearing-claim)
- [§Engine — phases to Workflow controls](#engine--phases-to-workflow-controls)

## Phase 1 — Discover

The job is to find *where* the answer lives before reading it. Cast the
discovery net across the sources that index everything without local setup, run
together — the concrete tools are the Round 1 roster in `sources.md`; do not
re-derive them here.

Rank the hits into specific places: "this lives in `repos/X` at `path/Y`",
"discussed in EXT-NNNN", "decided in <Confluence doc>". A place is a concrete,
addressable target a later read can reach — a file path, an issue key, a
document URL.

**End condition (checkable):** list every place found, each with its source. If
zero places are found, state that and stop.

## Phase 2 — Deepen

For each place Discover surfaced, pull ground truth from the highest-fidelity
rung that reaches it. Which rung reaches which domain is the Source Fidelity
Ladder in `sources.md` — that table is the single source of truth for the
per-domain tools; do not re-list them here. One load-bearing method insight the
ladder doesn't spell out: GitHub MCP reads specific files without cloning, so
the "repo not cloned locally" case dissolves — the harness finds the repo and
reads from it without the name known up front.

Each place is deepened independently — one place failing to resolve does not
block the others.

**End condition (checkable):** each surfaced place yields content, or is marked
unreachable with the reason.

## Phase 3 — Verify

Rigor applies to every load-bearing claim (see [Load-bearing claim](#load-bearing-claim)
below). Each load-bearing claim gets an independent refute-pass: a verifier
prompted to refute the claim against its cited source. A claim survives only if
it cannot be refuted. Read the cited source before trusting the claim — a claim
that reads plausibly is not verified until its source is read.

The refute-passes run independently of one another, one per load-bearing claim.

**End condition (checkable):** every load-bearing claim is marked
`verified-against-<source>` or is dropped.

## Phase 4 — Synthesize

Merge the verified findings into the chosen output shape (load `output-shapes.md`
at this point for the report / decision-memo / context-handoff skeletons). Every
claim carries a source pointer. Provenance lives in a closing `## Sources`
section — each source with its fidelity tier and any staleness caveat — not
inline per claim.

**End condition (checkable):** see `SKILL.md`'s Done-check — the enforceable
authority for whether Synthesize is complete.

## Load-bearing claim

A **load-bearing claim** is a statement that appears in the synthesized answer
and would change the reader's conclusion if it were false — for example "service
X calls Y" or "the team decided Z in EXT-N". Background and navigational
statements ("this lives in repo X") are not load-bearing unless the answer rests
on them.

The Verify phase spawns an independent refute-pass per load-bearing claim; a
claim survives only if it cannot be refuted against its cited source. Read the
cited source before trusting the claim — this is a firm interdict, because
accepting a plausible-sounding claim without reading its source is the exact
failure this harness exists to prevent.

## §Engine — phases to Workflow controls

This section describes the control shape both execution paths honor. Task 6's
`workflow.js` implements it for main context; a subagent follows the same shape
inline, single-threaded (`SKILL.md` Step 2: main context launches the Workflow,
a subagent runs inline). The shape is identical either way — only the executor
differs.

- **Discover → `parallel`.** Round 1 fans out across the locate-agents (Glean,
  GitHub, Jira) at once. The agents share no state; the control gathers their
  ranked places.
- **Discover → Deepen → `pipeline`, no barrier.** Each place Discover surfaces
  flows into its own Deepen read as soon as it is surfaced. Deepen does not wait
  for every locate-agent to finish before starting — this absence of a barrier
  is the deliberate design choice. Each place deepens independently.
- **Verify → `parallel`.** One refute-pass per load-bearing claim, run
  concurrently. Each pass reaches its verdict against its own cited source with
  no dependence on the others.
- **Synthesize → single join.** The verified claims converge into one output
  artifact; this is the barrier where the parallel refute-passes rejoin.
