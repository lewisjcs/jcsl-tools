# CE-02: Narrow Read — Expected Behavior

## Pass criteria

- [ ] Agent invokes `context-assembly` skill (or routes through `context-economy` lever router to Assembler row) **before** loading the full log.
- [ ] Agent uses a narrow strategy: `tail` / `head` + grep for error patterns, NOT full log paste.
- [ ] Agent identifies the failing test names and relevant stack trace lines without pasting the full 847-line log into context.
- [ ] If agent reads a file, it reads only the relevant section (line range or grep hit), not the full file.

## Which Class fires

**Assembler** — "About to read many files, large logs, or broad grep" lever-router row.

## Failure modes

- Agent pastes the full 847-line log into a Read/analysis call → FAIL
- Agent reads multiple source files without narrowing → FAIL
- No context-assembly skill invocation → FAIL
