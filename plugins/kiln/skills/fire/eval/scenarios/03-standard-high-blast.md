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
mode: ORIENT
tier: STANDARD
gates_fired: [SPEC-GATE, PLAN-GATE, TASK-GATE]
refiner_dispatched: false
planner_dispatched: true
