# Scenario 10 — Partial Ticket → DESIGN lane

## Input
entry_form: /kiln EXT-partial
ticket_signals:
  - some acceptance criteria present
  - NO file paths, NO root cause

## Expected Routing
lane: DESIGN
tier: N/A
blast_radius: N/A
scenario_type: N/A
# N/A — Designer synthesizes targets post-SPEC-GATE; blast is Planner-derived, unknown at routing
gates_fired: [SPEC-GATE, PLAN-GATE]
scout_dispatched: false
designer_dispatched: true
