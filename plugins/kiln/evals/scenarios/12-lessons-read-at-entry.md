# Eval Scenario 12: Lessons Read at Entry — Scope Filtering and Ranking

## Scenario

The orchestrator begins a TRIVIAL-tier run. `kiln-lessons.md` exists with 3 lessons:
- Lesson A: `scope:branch`, `runs:AIS-40,gauntlet-plugin` (2 runs)
- Lesson B: `scope:compounds`, `runs:AIS-40` (1 run)
- Lesson C: `scope:dispatch`, `runs:AIS-40,EXT-7394,EXT-7411` (3 runs)

Block 1.6 must:
1. Read the corpus
2. Apply scope match rules — `branch` and `compounds` always surface; `dispatch` surfaces only for STANDARD tier
3. Suppress Lesson C (dispatch-scoped) because this run is TRIVIAL
4. Rank surviving lessons by `len(runs)` descending: Lesson A (2 runs) before Lesson B (1 run)
5. Emit pre-flight notice with exactly 2 lessons
6. Write ledger entry

## Expected Behavior

- Corpus read without error
- Lesson C (scope:dispatch) is not surfaced
- Pre-flight notice emitted listing 2 lessons ranked by recurrence: branch lesson first (2 runs), compounds lesson second (1 run)
- Ledger entry written: `LESSONS-READ: 2 surfaced | <ISO timestamp>`
- Run proceeds normally — no abort, no gate, no pause

## Pass Condition

- Pre-flight notice contains exactly 2 lessons
- `scope:dispatch` lesson is absent from the notice
- Lessons are ranked by `len(runs)` descending (2-run lesson before 1-run lesson)
- Ledger contains `LESSONS-READ: 2 surfaced`
- Run is not blocked or aborted by the corpus-read step

## Fail Condition

- All 3 lessons surfaced (dispatch lesson not suppressed for TRIVIAL)
- Lessons surfaced in wrong order (not ranked by recurrence)
- No ledger entry written
- Run is aborted or gated on corpus content
- Ledger entry count differs from surfaced count (e.g., `LESSONS-READ: 3 surfaced` when 2 shown)
