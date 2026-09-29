# Scenario 01 — Trivial Bugfix

## Input
entry_form: /kiln EXT-trivial
ticket_signals:
  - EARS AC present
  - file paths specified
  - root cause explained
compounds_classification: TRIVIAL
blast_radius: N/A

## Expected Routing
lane: TRIVIAL
tier: TRIVIAL
scenario_type: code
gates_fired: []
walker_dispatched: false
planner_dispatched: false
inspector_dispatched: false   # TRIVIAL fast-path: single Crafter, no gates, no Inspector
