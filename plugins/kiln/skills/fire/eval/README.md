# Kiln Eval Harness

## Harness Purpose

Validates that The Kiln's routing decisions and gate logic match the design spec. Five scenarios cover every routing path and gate combination. A calibration run compares The Kiln's announced decisions against the gold JSON fixtures in `expected/`.

This is v1 scope: human-run, no CI automation. The harness is the ship-gate for any change to `SKILL.md` routing or gate logic.

## Scenario Format

Each scenario file in `scenarios/` follows this structure:

```markdown
## Input
entry_form: /kiln <arg>
ticket_signals:
  - <signal from §5.2 routing table>
compounds_classification: TRIVIAL | STANDARD
blast_radius: LOW | HIGH | N/A

## Expected Routing
mode: ORIENT | REFINE | EXECUTE
tier: TRIVIAL | STANDARD
gates_fired: [SPEC-GATE, PLAN-GATE, TASK-GATE]
refiner_dispatched: true | false
planner_dispatched: true | false
```

## Gold Fixture Format

Each fixture in `expected/` follows this structure:

```json
{
  "scenario": "<filename-without-extension>",
  "routing": {
    "mode": "ORIENT | REFINE | EXECUTE",
    "tier": "TRIVIAL | STANDARD",
    "blast_radius": "LOW | HIGH | N/A"
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

**Pass:** All five scenarios produce routing decisions that exactly match every field in their `expected/*.json` fixture.

**Fail:** Any field mismatch in any scenario. Common failure modes:
- Wrong mode (e.g., ORIENT when REFINE expected)
- Wrong gate fired or gate skipped
- Wrong agent dispatched or skipped
- Tier misclassification (TRIVIAL vs STANDARD)

After any change to `SKILL.md` routing or gate logic, re-run all scenarios before shipping.

## Scenario Classification (`scenario_type`)

The `routing` block in fixtures 07–08 includes a `scenario_type` field. This field asserts which classification branch `SKILL.md` chose for the input:

| `scenario_type` | Meaning | Crafter verification |
|---|---|---|
| `code` | Standard code change | Red-green TDD |
| `tool-authoring` | Target file(s) are under `plugins/**/skills/` | Deterministic self-check (NOT red-green TDD) |

A mismatch on `scenario_type` is a calibration **fail**. Misclassifying `tool-authoring` as `code` forces red-green TDD onto prose (a SKILL.md edit), which is wrong behavior.

Note: `scenario_type` appears under `routing` in the fixture JSON. The top-level `scenario` key holds the fixture's name (e.g. `"07-tool-authoring"`). These are distinct fields; the naming is intentional.

## Scenario 09 — Offline Verification

Scenario 09 (`09-conductor-guard-denies-inline`) is a guard behavior assertion rather than a routing assertion. It cannot be verified by a live `/kiln` run alone.

**Offline:** Run `bash plugins/kiln/hooks/test-kiln-guards.sh` — this script asserts both directions (conductor denied, member allowed) in a synthetic environment.

**Live:** During a real Kiln run with an active sentinel, confirm the conductor never edits source files inline; all source edits appear in the statusline as member-dispatched actions.

Both verification paths must pass for scenario 09 to be considered calibrated.

## Calibration Rule (unchanged)

**Fix `SKILL.md`, not the fixture.**

If The Kiln's output does not match `expected/*.json`, the routing or gate logic in `SKILL.md` is wrong. Edit `SKILL.md` to correct the behavior, then re-run blind.

Never retrofit a fixture to match observed output (gaming). A fixture reflects the correct intended behavior from the design spec — it is the ground truth.
