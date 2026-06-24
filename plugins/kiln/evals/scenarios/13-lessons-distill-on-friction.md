# Eval Scenario 13: Distill on Friction — Novelty Gate and Bump Logic

## Scenario

The orchestrator completes Block 6 after a friction run (`friction_score >= 1`).
`progress.md` contains friction signals. The friction items are:

1. **Preventable, new**: `scope:branch trigger:committed-to-main-before-branch` — not present in `kiln-lessons.md`
2. **Non-preventable**: a narration note ("progress narration felt sparse") — not a mechanical failure
3. **Preventable, existing**: `scope:compounds trigger:plan_change-skipped` — already in `kiln-lessons.md` with `runs:prior-run`

The distill step must:
1. Evaluate each friction item against the novelty gate
2. Append a new lesson line for item 1 (new + preventable)
3. Skip item 2 entirely (not preventable — stays in retro prose only)
4. Bump the `runs:` field for item 3 (existing), appending this run's ID
5. Write ledger entries for items 1 and 3 only

## Expected Behavior

- Exactly one new lesson line appended to `kiln-lessons.md` (item 1)
- Item 2 (narration note) produces zero corpus writes
- Item 3 produces a `runs:` bump — no duplicate lesson line created
- Two ledger entries written: one `LESSON-WRITE: new ...`, one `LESSON-WRITE: bump ...`
- A distill write failure must not block retro completion or PR creation
- `RETRO:` ledger entry is written regardless of distill outcome

## Pass Condition

- `kiln-lessons.md` gains exactly 1 new lesson line (scope:branch)
- Existing `scope:compounds` lesson has this run's ID appended to `runs:` (not duplicated)
- Zero corpus entries for the narration note
- Ledger contains exactly: `LESSON-WRITE: new scope:branch trigger:committed-to-main-before-branch`
- Ledger contains exactly: `LESSON-WRITE: bump scope:compounds trigger:plan_change-skipped`
- `RETRO: full` ledger entry is written (friction_score >= 1)

## Fail Condition

- Narration note written to corpus (non-preventable item treated as preventable)
- Existing lesson duplicated instead of bumped (new line added alongside existing)
- `runs:` field on bumped lesson not updated with this run's ID
- Zero `LESSON-WRITE:` ledger entries written (distill step not executed)
- Distill failure blocks `RETRO:` ledger entry or PR creation
- `LESSON-WRITE:` count != 2 (one new + one bump)
