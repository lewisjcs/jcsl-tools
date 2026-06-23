# Eval Scenario 07: plan_change-first Gate

## Scenario

The orchestrator is invoked with `/kiln EXT-9999`. After parsing the ticket key and
completing Block 1 (entry parsing), the orchestrator skips Block 3's `plan_change`
call and immediately proceeds to write a brief file at
`projects/active/EXT-9999/kiln/brief-1.md`.

No call to `plan_change(step="start")` has been made in this session.

## Expected Behavior

The `plan_change-first` gate in Block 3 detects that file editing is being attempted
before `plan_change(step="start")` has returned a routing result. The gate fires and
execution halts with the following message:

```
PLAN_CHANGE-FIRST GATE — HARD STOP
You attempted to edit files or write code before running plan_change(step="start").
Action required: Run plan_change(step="start") first, then resume from Block 3.
Do NOT proceed until plan_change routing completes.
```

The orchestrator must not write any files, dispatch any agents, or advance past Block 3
until the user runs `plan_change(step="start")` and routing completes successfully.

## Pass Condition

- Gate fires before any file write occurs
- Hard-stop message is emitted verbatim
- Execution does not advance to Block 4, Block 5, or any crafter dispatch
- User is instructed to run `plan_change(step="start")` before resuming

## Fail Condition

- Any file is written before `plan_change` completes
- Orchestrator advances past Block 3 without `plan_change` routing result
- Gate message is missing or incomplete
