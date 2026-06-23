# Eval Scenario 11: Retro Generation — Friction Run (Full Prose)

## Scenario

The orchestrator completes Block 6 after a run with multiple friction signals. `progress.md`
contains at least one `USER-CORRECTION:` entry, one `FIX-LOOP:` entry, and one `ESCALATED`
entry. `friction_score` resolves to ≥ 1.

The orchestrator must:
1. Load `retro-template.md` from `plugins/kiln/skills/fire/retro-template.md`
2. Parse `{{RUN_FOLDER}}/progress.md` and compute `friction_score >= 1`
3. Select the **full-form** prose skeleton
4. Auto-seed fields from progress.md and verdict-N.md files:
   - Run ID, routing mode, tier, blast radius, task count
   - Gate fires (SPEC-GATE, PLAN-GATE, TASK-GATE escalations)
   - Fix loop details (which tasks, how many iterations)
   - Inspector findings summary
   - USER-CORRECTION descriptions
5. Write `projects/active/<run-id>/kiln-retro.md` (sibling of `kiln/`, not inside it)
6. Write ledger: `RETRO: full | <ISO timestamp>`

## Expected Behavior

- `retro-template.md` is loaded before writing
- Friction detection reads `progress.md` and finds at least one of:
  `fix_loops >= 1`, `escalations >= 1`, `user_corrections >= 1`, `routing_mismatch == 1`
- `friction_score >= 1` → full-form skeleton selected
- `kiln-retro.md` contains all 4 required sections from the full-form template
- Corrections Scorecard is populated with entries from `USER-CORRECTION:` ledger lines
- Fix loop details reference specific task numbers and iteration counts
- Ledger entry is `RETRO: full | <ISO timestamp>`
- Retro is written to `projects/active/<run-id>/kiln-retro.md`, not inside `kiln/`

## Pass Condition

- `kiln-retro.md` exists at `projects/active/<run-id>/kiln-retro.md`
- File contains all 4 sections: `## What Went Smoothly`, `## What Was Harder`,
  `## Workflow Observations`, `## Corrections Scorecard`
- `## Corrections Scorecard` table has at least one data row (not just header)
- Ledger contains `RETRO: full`
- `friction_score` computed as sum of fix_loops + escalations + user_corrections + routing_mismatch

## Fail Condition

- Terse-stub used when `friction_score >= 1`
- One or more of the 4 required sections is missing
- `## Corrections Scorecard` is empty (header only, no data rows)
- Retro written inside `kiln/` subfolder
- Ledger entry missing or uses wrong form label (`terse` instead of `full`)
- `retro-template.md` not loaded before writing
