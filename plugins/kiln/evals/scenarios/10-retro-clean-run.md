# Eval Scenario 10: Retro Generation — Clean Run (Terse)

## Scenario

The orchestrator completes Block 6 after a run with zero friction. `progress.md` contains
no `FIX-LOOP:`, `ESCALATED`, `USER-CORRECTION:`, or unexpected `ROUTING:` entries.
`friction_score` resolves to 0.

The orchestrator must:
1. Load `retro-template.md` from `plugins/kiln/skills/fire/retro-template.md`
2. Parse `{{RUN_FOLDER}}/progress.md` and compute `friction_score = 0`
3. Select the **terse-stub** form
4. Auto-seed fields: run ID, routing, tier, blast radius, task count, PR URL
5. Write `projects/active/<run-id>/kiln-retro.md` (sibling of `kiln/`, not inside it)
6. Write ledger: `RETRO: terse | <ISO timestamp>`

## Expected Behavior

- `retro-template.md` is loaded before writing
- Friction detection reads `progress.md` and finds `fix_loops = 0`, `escalations = 0`,
  `user_corrections = 0`, `routing_mismatch = 0`
- `friction_score == 0` → terse-stub form selected
- `kiln-retro.md` uses the terse skeleton: `## Run Summary`, `## Routing`, `## Outcome`
- Retro file is ≤ 20 lines
- Ledger entry is `RETRO: terse | <ISO timestamp>`
- Retro is written to `projects/active/<run-id>/kiln-retro.md`, not inside `kiln/`

## Pass Condition

- `kiln-retro.md` exists at `projects/active/<run-id>/kiln-retro.md`
- File contains `## Run Summary`, `## Routing`, `## Outcome` sections
- File does NOT contain `## What Went Smoothly` (full-form section)
- File is ≤ 20 lines
- Ledger contains `RETRO: terse`

## Fail Condition

- Full-form skeleton used when `friction_score == 0`
- Retro written inside `kiln/` subfolder
- Retro exceeds 20 lines
- Ledger entry missing or uses wrong form label (`full` instead of `terse`)
- `retro-template.md` not loaded before writing
