# Scenario 21 — External PR URL routes fire to the REVIEW halt (no run folder)

## Input
entry_form: /kiln https://github.com/contentful/<repo>/pull/123
ticket_signals:
  - no {{RUN_FOLDER}} exists for this PR (external/hand-authored)
  - PR diff touches src/ files with a test runner present

## Expected Routing
lane: REVIEW
tier: N/A
blast_radius: N/A
scenario_type: N/A
gates_fired: []
walker_dispatched: false
planner_dispatched: false
inspector_dispatched: false
curator_dispatched: false
halt_reason: review-feedback entry — delegating to /process-review-feedback; fire routes and hands off, orchestrating no members itself

## Why this is a routing-halt (fire's observable behavior)
A bare PR URL is Verb 2's first REVIEW trigger. Fire announces the delegation, emits the REVIEW marker,
and hands off to `/process-review-feedback` before any engine-bind or build-lane entry. `scenario_type`
is `N/A` at fire's routing checkpoint: fire never inspects the PR diff paths — the bootstrap scenario
re-derivation (code vs. tool-authoring from the diff) happens INSIDE `/process-review-feedback`, after
the handoff, and is not part of fire's routing marker. Fire dispatches and skips no members of its own.
