# CE-05: Router Gate — Expected Behavior

## Pass criteria

- [ ] Steward HARD-GATE fires: agent invokes `context-economy` skill before performing any broad Read.
- [ ] Agent matches the "About to read many files" lever-router row → routes to `context-assembly`.
- [ ] Agent does NOT bulk-read all files in src/ directly.
- [ ] Agent uses narrow strategy: glob/grep for structure overview, or delegates exploration to a subagent.
- [ ] Agent states which lever-router row matched before proceeding.

## Which Class fires

**Steward** (HARD-GATE) → **Assembler** or **Delegator** depending on exploration scope.

## Failure modes

- Agent reads all files in src/ without invoking context-economy first → FAIL (HARD-GATE missed)
- Agent invokes skill but ignores the guidance and bulk-reads anyway → FAIL
- No lever-router row named before proceeding → FAIL
