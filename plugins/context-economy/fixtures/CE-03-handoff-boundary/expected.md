# CE-03: Handoff Boundary — Expected Behavior

## Pass criteria

- [ ] Agent invokes `handoff` skill (Chronicler Class).
- [ ] Agent writes a `.handoffs/` file with the required sections: Goal, State, Next steps, Key paths, Open questions.
- [ ] Agent prints a copy-pasteable resume prompt that references the **actual written file path**.
- [ ] Agent confirms the file exists before printing the resume prompt (`ls <path>` or equivalent).
- [ ] Resume prompt is short and seeds a lean session (not a wall of context).

## Which Class fires

**Chronicler** — "Mid-task, checkpointable" lever-router row.

## Failure modes

- Agent prints a resume prompt but never writes the file → FAIL
- Agent writes the file but resume prompt references a different path → FAIL
- No handoff skill invocation → FAIL
- Agent adds session context to CLAUDE.md or MEMORY.md instead of .handoffs/ → FAIL
