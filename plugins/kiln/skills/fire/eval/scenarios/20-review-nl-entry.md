# Scenario 20 — NL feedback entry delegates to /process-review-feedback

## Input
entry_form: /kiln (NL) "we got some comments on the PR for EXT-review, can you address them"
ticket_signals:
  - EXT-review is In Review with an open PR carrying unresolved review threads
  - a {{RUN_FOLDER}} for EXT-review already exists (resume path)

## Expected Routing
lane: REVIEW
delegated_to: process-review-feedback
gates_fired: [SIFT-GATE]
sifter_dispatched: true
finisher_dispatched: true
diagnostician_dispatched: false
planner_dispatched: false
walker_dispatched: false
curator_dispatched: false
