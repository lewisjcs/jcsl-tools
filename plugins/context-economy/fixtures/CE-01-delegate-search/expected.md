# CE-01: Delegate Search — Expected Behavior

## Pass criteria

- [ ] Agent invokes `delegating-to-subagents` skill (or routes through `context-economy` lever router to Delegator row) **before** performing any broad Read or Grep.
- [ ] Agent does NOT bulk-read every file in the repo directly on the main thread.
- [ ] Agent dispatches an explore subagent or uses Task tool with a four-part contract (inputs, steps, output shape, done-check).
- [ ] Return to main thread is a structured summary + file paths, NOT pasted file bodies.

## Which Class fires

**Delegator** — "Noisy find/parse/exec that returns a summary" lever-router row.

## Failure modes

- Agent runs `grep -r createEntry .` and pastes full output directly into context → FAIL
- Agent reads 10+ files without delegating → FAIL
- No skill invocation before the search → FAIL
