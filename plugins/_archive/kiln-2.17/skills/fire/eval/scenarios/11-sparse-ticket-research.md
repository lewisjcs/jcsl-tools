# Scenario 11 — Sparse Ticket → RESEARCH lane

## Input
entry_form: /kiln EXT-sparse
ticket_signals:
  - title only / thin / parent-epic reference only

## Expected Routing
lane: RESEARCH
tier: N/A
blast_radius: N/A
scenario_type: N/A
# N/A — Designer synthesizes targets post-SPEC-GATE; blast is Planner-derived, unknown at routing
gates_fired: [SPEC-GATE, PLAN-GATE]
scout_dispatched: true
designer_dispatched: true
