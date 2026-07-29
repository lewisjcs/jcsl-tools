# CE-04: Clear Default — Expected Behavior

## Pass criteria

- [ ] Agent invokes `context-economy` skill (Steward) and names the lever-router row.
- [ ] Agent recommends `/clear` (not `/compact`) as the default action for this task boundary.
- [ ] Agent explains that this is a task boundary / new unrelated work → full prefix reset is correct.
- [ ] Agent does NOT recommend `/compact` as the primary action for a clean task switch.

## Which Class fires

**Steward** — "Task finished or switching tickets" lever-router row → `/clear`.

## Failure modes

- Agent recommends `/compact` instead of `/clear` for a clean task boundary → FAIL
- No context-economy skill invocation → FAIL
- Agent proceeds directly into the billing module without addressing context hygiene → FAIL
