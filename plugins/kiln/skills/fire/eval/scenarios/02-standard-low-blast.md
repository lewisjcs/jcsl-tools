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
mode: ORIENT
tier: STANDARD
gates_fired: [PLAN-GATE]
refiner_dispatched: false
planner_dispatched: true
