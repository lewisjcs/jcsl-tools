# Scenario 20 — NL feedback entry routes fire to the REVIEW halt

## Input
entry_form: /kiln (NL) "we got some comments on the PR for EXT-review, can you address them"
ticket_signals:
  - EXT-review is In Review with an open PR carrying unresolved review threads
  - a {{RUN_FOLDER}} for EXT-review already exists (resume path)

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
Verb 2's first branch matches (NL feedback referencing an in-review PR with unresolved threads), so
fire announces the delegation, emits the REVIEW marker, and hands off to `/process-review-feedback`
BEFORE binding an engine, writing a sentinel, or entering a build lane. Fire orchestrates none of the
review flow itself, so it dispatches and skips no members — `agents_dispatched` and `agents_skipped`
are both empty. The Sifter, Finisher, and SIFT-GATE belong to the skill's internal flow, not to fire's
routing vocabulary, so this fire-level fixture never asserts them.
