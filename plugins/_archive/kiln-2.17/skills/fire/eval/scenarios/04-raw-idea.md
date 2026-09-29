# Scenario 04 — Raw Idea (No Ticket) → DESIGN lane

## Input
entry_form: /kiln "add dark mode toggle to the settings panel"
ticket_signals:
  - no EARS AC (raw idea, no ticket)
  - no file paths specified
  - no root cause explained
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: DESIGN
tier: N/A
blast_radius: N/A
scenario_type: N/A
# N/A — Designer synthesizes targets post-SPEC-GATE; blast is Planner-derived, unknown at routing
gates_fired: [SPEC-GATE, PLAN-GATE]
jira_offer: false   # net-new gets a local kebab-slug run-id; NO ticket offer (P2.2)
scout_dispatched: false
designer_dispatched: true
planner_dispatched: true

## Why DESIGN (v2 behavior)
A net-new raw idea with no ticket or spec routes to the DESIGN lane: the Designer runs a
dialogue loop that turns fuzzy intent into a spec draft, SPEC-GATE gates the synthesized
spec, and the Planner takes over from there. (P1 stopped and asked here; P2.1 activates the
Designer.) Scout is skipped — Scout only fires on sparse/thin tickets that need research
before a spec can be drafted, and a net-new quoted string has no ticket to research. No Jira
offer for a net-new, no-ticket entry — the run uses a local kebab-slug run-id only (ticket
creation from a synthesized spec is P2.2).
