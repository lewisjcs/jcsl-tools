# Scenario 12 — Design-Doc Entry → DESIGN (mid-flow)

## Input
entry_form: /kiln EXT-doc path/to/design.md
file_shape:
  - has `## Approaches` and `## Architecture`
  - NO acceptance criteria

## Expected Routing
lane: DESIGN
tier: N/A
blast_radius: N/A
scenario_type: N/A
# N/A — Designer synthesizes targets post-SPEC-GATE; blast is Planner-derived, unknown at routing
gates_fired: [SPEC-GATE, PLAN-GATE]
designer_dispatched: true          # enters mid-flow with design.md pre-supplied (confirm+convert)
scout_dispatched: false
designer_entry: midflow-design-doc
