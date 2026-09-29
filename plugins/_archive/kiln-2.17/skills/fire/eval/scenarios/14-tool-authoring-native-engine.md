# Scenario 14 — Tool-authoring run, native engine (§6c)

## Input
entry_form: /kiln EXT-tool-native path/to/spec.md
ticket_signals:
  - EARS AC present, file paths specified
  - file targets are under plugins/**/skills/ (a SKILL.md)
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: tool-authoring
engine: native
gates_fired: [PLAN-GATE]
walker_dispatched: false
planner_dispatched: true
inspector_dispatched: true

## Expected Engine Behavior (assert all)
- Planner named the standards source (skill-authoring-principles / directive-review lenses) as
  the enrich output — did NOT call implement_task or the Compounds get_* tools for patterns.
- Crafter did NOT call implement_task; it ran the deterministic self-check.
- Ledger header reads `ENGINE: native | <ISO>` and the DONE line carries `engine: native`.
