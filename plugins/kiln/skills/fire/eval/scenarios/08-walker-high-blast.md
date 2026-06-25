# Scenario 08 — Walker fires at PLAN-GATE on HIGH blast

## Input
entry_form: /kiln EXT-high-blast
ticket_signals:
  - EARS AC present, file paths specified, root cause explained
compounds_classification: STANDARD
blast_radius: HIGH

## Expected Routing
mode: PLAN
scenario_type: code
gates_fired: [PLAN-GATE, TASK-GATE]
walker_dispatched: true   # the new HIGH-blast behavior
