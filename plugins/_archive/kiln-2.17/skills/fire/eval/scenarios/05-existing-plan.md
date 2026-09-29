# Scenario 05 — Existing Plan (EXECUTE lane)

## Input
entry_form: /kiln EXT-7394 projects/active/ext-7394/plans/impl.plan.md
ticket_signals:
  - EARS AC present
  - file paths specified
  - root cause explained
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: EXECUTE
tier: STANDARD
scenario_type: code
gates_fired: [PLAN-GATE]
walker_dispatched: false
planner_dispatched: true       # v2: Planner REGISTERS the existing plan (generate_tasks over it), not skipped
inspector_dispatched: true

## Why the Planner runs here (v2 behavior)
The entry is an implementation-plan file → EXECUTE lane. After the drift-check confirms the
plan is fresh, the Planner registers it as the Compounds project and generates its task
breakdown (writing tasklist.md) rather than re-planning from scratch. In v1 the Planner was
skipped on EXECUTE; in v2 it owns all Compounds interaction (the conductor cannot call Compounds).
