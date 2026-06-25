# Scenario 04 — Raw Idea (No Ticket) → HALT in P1

## Input
entry_form: /kiln "add dark mode toggle to the settings panel"
ticket_signals:
  - no EARS AC (raw idea, no ticket)
  - no file paths specified
  - no root cause explained
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: HALT-AND-ASK
tier: N/A
scenario_type: N/A
gates_fired: []
walker_dispatched: false
planner_dispatched: false
inspector_dispatched: false

## Why this halts (v2 behavior)
A net-new raw idea with no ticket/spec needs the DESIGN lane (the Designer turns fuzzy
intent into a spec). The Designer is Kiln P2 — so P1 HALTS-AND-ASKS rather than dispatching.
The conductor announces the gap and asks for a `code`- or `tool-authoring`-shaped change,
or a spec to run the PLAN lane against. (In v1 this ran the Refiner; the Refiner is superseded.)
