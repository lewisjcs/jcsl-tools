# Scenario 07 — Tool-authoring (skill edit)

## Input
entry_form: /kiln EXT-tool-auth path/to/spec.md
ticket_signals:
  - EARS AC present, file paths specified
  - file targets are under plugins/**/skills/ (a SKILL.md)
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
mode: PLAN
scenario_type: tool-authoring
crafter_verification: deterministic-self-check  (NOT red-green TDD)
gates_fired: [PLAN-GATE]
walker_dispatched: false
