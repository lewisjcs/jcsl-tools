# Scenario 21 — External PR (no run folder) bootstraps into the review-feedback flow

## Input
entry_form: /process-review-feedback https://github.com/contentful/<repo>/pull/123
ticket_signals:
  - no {{RUN_FOLDER}} exists for this PR (external/hand-authored)
  - PR diff touches src/ files with a test runner present

## Expected Routing
lane: REVIEW
delegated_to: process-review-feedback
scenario_type: code   # engine re-derived from PR diff paths on bootstrap
gates_fired: [SIFT-GATE]
sifter_dispatched: true
finisher_dispatched: true
diagnostician_dispatched: false
planner_dispatched: false
