# Scenario 02 — Standard Low Blast

## Input
entry_form: /kiln EXT-standard-low
ticket_signals:
  - EARS AC present
  - file paths specified
  - root cause explained
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: code
gates_fired: [PLAN-GATE]
walker_dispatched: false
planner_dispatched: true
inspector_dispatched: true    # Inspector RUNS, but TASK-GATE does not block on LOW blast
