# Scenario 15 — Context-preservation yield at gate

## Input
entry_form: /kiln EXT-yield-standard --flow hands_free
ticket_signals:
  - EARS AC present
  - file paths specified
compounds_classification: STANDARD
blast_radius: LOW
mid_run_event: the workspace reset-nudge Stop hook fires during the Build loop, injecting the
  "invoke the context-economy skill lever router" message into the conductor's context AFTER task 2
  of 4 has finalized (i.e. between task 2's TASK-GATE and task 3's).

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: code
gates_fired: [PLAN-GATE, TASK-GATE]    # STANDARD+LOW: PLAN-GATE + non-blocking TASK-GATE per task
walker_dispatched: false               # LOW blast — no Walker
planner_dispatched: true
inspector_dispatched: true

## Expected Behavior (context-preservation yield — the assertion under test)
On seeing the reset-nudge message the conductor records `NUDGE-SEEN: <ISO>` in `progress.md` once.
At the NEXT gate boundary — here task 3's TASK-GATE — it performs a forced yield **despite
`hands_free`** (which would otherwise auto-advance a LOW-blast TASK-GATE without pausing):
  - invokes `context-economy:handoff`, writing `{{RUN_FOLDER}}/handoff.md`
  - writes ledger `YIELD: context-preservation at TASK-GATE, task 3/4 | <ISO>`
  - ends the turn with a status line naming the checkpoint and instructing `/clear` then `/kiln EXT-yield-standard`
  - does NOT auto-`/clear`, and does NOT reach `COMPLETE` in this session
The run resumes in a fresh session from task 3 (the first task with no later `DONE`).

## How to verify
This is a behavioral assertion, not a routing-only one: the harness cannot simulate ~100 real turns,
so it asserts the conductor's *rule* given the nudge message appears. Confirm against
`SKILL.md` Verb 5 (the "Context-preservation yield" bullet) and `gates.md`
("Context-preservation yield" section). Live: during a long real run, confirm the conductor writes
`handoff.md` + a `YIELD:` ledger line at the first gate after the nudge and ends its turn.
