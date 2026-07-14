# Scenario 19 — MEDIUM blast blocks TASK-GATE without dispatching the Walker

## Input
entry_form: /kiln EXT-medium-blast
ticket_signals:
  - EARS AC present, file paths specified across two modules, no public/exported contract change
compounds_classification: STANDARD
blast_radius: MEDIUM

## Expected Routing
lane: PLAN
scenario_type: code
gates_fired: [PLAN-GATE, TASK-GATE]
walker_dispatched: false   # MEDIUM blocks but does NOT run the Walker
planner_dispatched: true
inspector_dispatched: true
