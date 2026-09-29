# Scenario 13 — Code run, Compounds engine drives (§6c)

## Input
entry_form: /kiln EXT-code-compounds path/to/spec.md
ticket_signals:
  - EARS AC present, file paths specified
  - file targets are under src/ with a package.json test script (a real code change)
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: code
engine: compounds
gates_fired: [PLAN-GATE]
walker_dispatched: false
planner_dispatched: true
inspector_dispatched: true

## Expected Engine Behavior (the #0.1 defect fix — assert all)
- Planner called get_design_patterns / get_testing_frameworks / get_reference_architecture and
  wrote an `### Enriched context` subsection into tasklist.md.
- brief-N.md contains that enriched context (the conductor merged it — not discarded).
- Crafter called implement_task at craft time.
- Ledger header reads `ENGINE: compounds | <ISO>` and the DONE line carries `engine: compounds`.
