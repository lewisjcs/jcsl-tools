# Kiln Eval Harness

## Harness Purpose

Validates that The Kiln's routing decisions and gate logic match the design spec. Twenty-one scenarios (01–21) cover every lane, gate combination, scenario type, and the conductor-guard behavior: 01–09 cover the P1 lanes (TRIVIAL/PLAN/EXECUTE), gates, scenario types, and the guard; 10–12 cover the P2.1 DESIGN/RESEARCH/design-doc-mid-flow routes; 13–14 cover the Compounds-engine behavior (code→Compounds, tool-authoring→native); 15 covers the context-preservation yield at a gate boundary; 16–18 cover the Curator close-out (compounds-engine, verify-fail-blocked, and native-engine skip); 19 covers the MEDIUM-blast rung — TASK-GATE blocks but the Walker does not dispatch; 20–21 cover the REVIEW lane's delegation to `/process-review-feedback` (20: NL feedback phrasing on an in-review ticket, resume path; 21: an external PR URL with no run folder, bootstrap path) — each fires SIFT-GATE, dispatches the Sifter and Finisher, and skips the Planner/Walker/Curator/Diagnostician. A calibration run compares The Kiln's announced decisions against the gold JSON fixtures in `expected/`.

This is human-run, no CI automation. The harness is the ship-gate for any change to `SKILL.md` routing or gate logic.

## Automated consumers (Smith)

Two Smith modes drive this harness by dispatching conductor-role replay subagents instead of a human
running `/kiln` by hand. Both are defined in `skills/smith/references/eval-gate.md` (the operating
procedure) and backed by `skills/smith/smith-eval-gate.sh` (the marker-diff toolkit). They differ in
what they compare against:

- **Differential gate — `/smith --validate <proposal>`.** Per-proposal, on-demand. Replays the harness
  against a candidate edit's prose *and* the current baseline prose under the same scenario input, then
  labels the proposal `RECOMMENDED` or `OBSERVATION-ONLY` from the per-scenario `SAME`/`CHANGED` diff —
  it never reads the gold `expected/` fixtures. This is a *regression* check ("did the proposal move a
  routing output it didn't mean to?"), not a correctness check.
- **Calibration anchor — `/smith --calibrate`.** Periodic (run before each Kiln version bump, or
  on-demand). Replays the current prose only and compares each scenario's `K`-sample majority against
  the gold `expected/` fixtures via the `diff` subcommand, reporting a **drift ratio** (e.g. "15/19
  reproduce gold"). This is the *only* Smith path that reads gold; it detects drift, it does not gate.

Both replay the same 21 scenarios via the same mode table (routing-halt / execution-observed / offline)
and majority-of-`K` sampling documented in `eval-gate.md`. The human-run procedure below remains the
authoritative gold calibration; the Smith modes automate the replay, they do not replace the fixtures
as ground truth.

## Scenario Format

Each scenario file in `scenarios/` follows this structure:

```markdown
## Input
entry_form: /kiln <arg>
ticket_signals:
  - <signal from the lanes.md entry-detection table>
compounds_classification: TRIVIAL | STANDARD
blast_radius: LOW | MEDIUM | HIGH | N/A

## Expected Routing
lane: TRIVIAL | PLAN | EXECUTE | RESUME | DESIGN | RESEARCH | HALT-AND-ASK
tier: TRIVIAL | STANDARD | N/A
scenario_type: code | tool-authoring | N/A
gates_fired: [SPEC-GATE, PLAN-GATE, TASK-GATE]   # SPEC-GATE fires on DESIGN/RESEARCH runs
walker_dispatched: true | false
planner_dispatched: true | false
inspector_dispatched: true | false
scout_dispatched: true | false      # RESEARCH lane only
designer_dispatched: true | false   # DESIGN/RESEARCH lanes
designer_entry: midflow-design-doc  # only when entering DESIGN mid-flow from a design doc
```

## Gold Fixture Format

Each fixture in `expected/` follows this structure:

```json
{
  "scenario": "<filename-without-extension>",
  "routing": {
    "lane": "TRIVIAL | PLAN | EXECUTE | RESUME | DESIGN | RESEARCH | HALT-AND-ASK",
    "tier": "TRIVIAL | STANDARD | N/A",
    "blast_radius": "LOW | MEDIUM | HIGH | N/A",
    "scenario_type": "code | tool-authoring | N/A"
  },
  "gates": {
    "SPEC-GATE": false,
    "PLAN-GATE": false,
    "TASK-GATE": false
  },
  "agents_dispatched": ["..."],
  "agents_skipped": ["..."]
}
```

- `expected_model` (optional): the model the conductor should relay for this scenario's Build-loop
  tasks, per the Planner's routing rubric (`agents/planner.md`). Present only on build-loop fixtures.
- `routing.engine` (build-loop fixtures): the engine the router bound — `compounds` | `native`.
  Asserts the scenario→engine lookup (`code`→compounds, `tool-authoring`/`doc`→native).
- `expected_impl_model` / `expected_verify_model` (build-loop fixtures): the two models the
  conductor relays — Impl-model to the Crafter, Verify-model to the Inspector — replacing the
  former single `expected_model`. Legacy fixtures with a single `expected_model` still assert
  the Crafter's Impl-model.
- `engine_behavior` (scenarios 13, 14): asserts the #0.1 defect fix — that the Planner enriched,
  the enrichment reached the brief, the Crafter did/did-not call `implement_task`, and the
  correct `engine:` tag was written. These are observed during the live run, not from routing alone.

SPEC-GATE is live (P2.1): it fires after the Designer on DESIGN/RESEARCH runs, before the Planner.
Gate keys now include SPEC-GATE alongside PLAN-GATE and TASK-GATE.
A `HALT-AND-ASK` lane (scenario 06) dispatches no members: an out-of-scope or artifact-mismatched
entry halts rather than mis-routing, with a `halt_reason` field. (Scenario 04 no longer HALTs — a
net-new raw idea routes DESIGN in P2.1.)

## How to Run

1. Open a Claude Code session with The Kiln plugin installed and Compounds MCP connected.
2. For each scenario file:
   a. Read the `## Input` section to get the entry form and ticket signals.
   b. Run `/kiln <entry_form>` — provide the ticket signals when The Kiln reads the ticket.
   c. Observe The Kiln's announced routing decision and gate firings.
3. Compare each decision against the corresponding `expected/*.json` fixture.
4. A mismatch on any field is a calibration failure.

## Calibration Rule

**Fix `SKILL.md`, not the fixture.**

If The Kiln's output does not match `expected/*.json`, the routing or gate logic in `SKILL.md` is wrong. Edit `SKILL.md` to correct the behavior, then re-run blind.

Never retrofit a fixture to match observed output (gaming). A fixture reflects the correct intended behavior from the design spec — it is the ground truth.

## Pass/Fail Criteria

**Pass:** All twenty-one scenarios produce routing decisions that exactly match every field in their `expected/*.json` fixture.

**Fail:** Any field mismatch in any scenario. Common failure modes:
- Wrong lane (e.g., routing a sparse ticket to EXECUTE instead of RESEARCH, or skipping SPEC-GATE on a DESIGN run)
- Wrong gate fired or gate skipped
- Wrong agent dispatched or skipped (e.g., Walker missing on HIGH blast)
- Tier misclassification (TRIVIAL vs STANDARD)
- scenario_type misclassification (tool-authoring routed as code)

After any change to `SKILL.md` routing or gate logic, re-run all scenarios before shipping.

## Scenario Classification (`scenario_type`)

The `routing` block in every routing fixture (01–12) includes a `scenario_type` field. This field asserts which classification branch `SKILL.md` chose for the input:

| `scenario_type` | Meaning | Crafter verification |
|---|---|---|
| `code` | Standard code change (source under `src/`/`lib/`/`packages/`/`apps/` with a real test runner) | Red-green TDD |
| `tool-authoring` | Target file(s) match `**/skills/**`, `**/agents/**`, a `SKILL.md`/agent `*.md`, or directive prose — excluding `src/`/`lib/`/`test/` subtrees | Deterministic self-check (NOT red-green TDD) |
| `N/A` | Either the run halts (HALT-AND-ASK) before a scenario is selected, or the run is a design-front lane (DESIGN/RESEARCH — scenarios 04, 10–12) where the scenario is not yet determined at the routing checkpoint (see the N/A-rationale below) | — |

A mismatch on `scenario_type` is a calibration **fail**. Misclassifying `tool-authoring` as `code` forces red-green TDD onto prose (a SKILL.md edit), which is wrong behavior.

Note: `scenario_type` appears under `routing` in the fixture JSON. The top-level `scenario` key holds the fixture's name (e.g. `"07-tool-authoring"`). These are distinct fields; the naming is intentional.

**Why the design-front fixtures assert `N/A` for `tier`/`blast_radius`/`scenario_type`:**
Fixtures 04, 10, 11, and 12 all assert `N/A` for these three fields, not because the run halts, but
because none of them is deterministic at the routing checkpoint. The Designer has not yet synthesized
file targets — `scenario_type` (code vs. tool-authoring) is derived from those targets, which don't
exist yet. `blast_radius` is Planner-derived from Compounds' classify step, which runs AFTER SPEC-GATE
on these lanes — it is unknown at routing time. `tier` follows the same Planner-derived timing.
Asserting a concrete value for any of the three at the routing checkpoint would assert fiction; the
deterministic-at-checkpoint principle is: only assert what the conductor can actually know at the
moment the fixture checks it. `designer_entry` on fixture 12 is the exception that proves the rule — it
IS asserted (`"midflow-design-doc"`) because it's deterministic from the entry file-shape alone (the
`.md` has `## Approaches`/`## Architecture`, no AC), knowable before any member dispatch.

## Scenario 09 — Offline Verification

Scenario 09 (`09-conductor-guard-denies-inline`) is a guard behavior assertion rather than a routing assertion. It cannot be verified by a live `/kiln` run alone.

**Offline:** Run `bash plugins/kiln/hooks/test-kiln-guards.sh` — this script asserts both directions (conductor denied, member allowed) in a synthetic environment.

**Live:** During a real Kiln run with an active sentinel, confirm the conductor never edits source files inline; all source edits appear in the statusline as member-dispatched actions.

Both verification paths must pass for scenario 09 to be considered calibrated.

## P2.1 Design-Front Fixtures

Scenarios 10–12 exercise the P2.1 design-front routes: 10 (`10-partial-ticket-design`) is a partial
ticket (some AC, no file paths) routing DESIGN; 11 (`11-sparse-ticket-research`) is a title-only/thin
ticket routing RESEARCH (Scout runs first); 12 (`12-design-doc-midflow`) is a design-doc entry
(`## Approaches`/`## Architecture`, no AC) entering DESIGN mid-flow via confirm-and-convert. Scenario
04 (`04-raw-idea`) changed behavior in this release: a net-new raw idea with no ticket now routes
DESIGN instead of halting (P1 stopped and asked here; P2.1 activates the Designer).

DESIGN and RESEARCH both route through the externalized Designer dialogue loop rather than a single
dispatch, because the Designer cannot prompt the user directly: dispatch #1 reads the entry (plus
`research.md` on RESEARCH, or a pre-supplied `design.md` on design-doc mid-flow) and batch-returns a
`## Questions` block via its `DESIGNER_NEEDS_INPUT` done-line; the conductor relays that batch verbatim
through `AskUserQuestion` (the ONLY member interaction where the conductor prompts the user) and pastes
the answers into dispatch #2; dispatch #2 writes `design.md` + `spec-draft.md` and returns
`DESIGNER_DONE`. SPEC-GATE then gates the synthesized spec before the Planner runs and PLAN-GATE fires —
so DESIGN/RESEARCH runs assert the `designer`/`scout` dispatch flags plus the SPEC-GATE→PLAN-GATE pair,
not a single-gate PLAN flow.

## Calibration Rule (unchanged)

**Fix `SKILL.md`, not the fixture.**

If The Kiln's output does not match `expected/*.json`, the routing or gate logic in `SKILL.md` is wrong. Edit `SKILL.md` to correct the behavior, then re-run blind.

Never retrofit a fixture to match observed output (gaming). A fixture reflects the correct intended behavior from the design spec — it is the ground truth.
