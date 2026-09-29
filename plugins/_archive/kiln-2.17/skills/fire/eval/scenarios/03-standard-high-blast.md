# Scenario 03 — Standard High Blast

## Input
entry_form: /kiln EXT-standard-high
ticket_signals:
  - EARS AC present
  - file paths specified
  - root cause explained
compounds_classification: STANDARD
blast_radius: HIGH

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: code
gates_fired: [PLAN-GATE, TASK-GATE]   # no SPEC-GATE in P1 (it pairs with the P2 Designer)
walker_dispatched: true                # Walker fires at PLAN-GATE on HIGH blast
planner_dispatched: true
inspector_dispatched: true             # Inspector runs AND TASK-GATE blocks on HIGH blast
