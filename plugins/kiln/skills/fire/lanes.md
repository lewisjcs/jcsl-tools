# Kiln Lanes (P1)

Loaded on-demand at the classify verb. P1 implements EXECUTE / PLAN / TRIVIAL / RESUME only.
RESEARCH and DESIGN lanes (Scout, Designer, SPEC-GATE) are P2 — a sparse/partial ticket HALTS.

## Entry detection (mechanical first, prefix-agnostic `[A-Z]+-\d+`)

| Entry | Detected as | Lane | Members run |
|---|---|---|---|
| `/kiln <KEY> <path>.md` where the file has numbered tasks + file targets | impl-plan | **EXECUTE** | drift-check → Planner(register) → Build |
| `/kiln <KEY> <path>.md` where the file is EARS AC + paths, no task list | spec | **PLAN** | Planner → Build |
| `/kiln <KEY>` ticket with EARS AC + file paths + root cause | complete | **PLAN** | Planner → Build |
| `/kiln <KEY>` ticket with some AC, no paths / title-only / thin | partial or sparse | **HALT-AND-ASK** | (DESIGN lane is P2) |
| re-invoke with an active run folder + ledger present | resume | **RESUME** | read ledger → Build from first incomplete task |
| file shape is none-of-the-above | — | **HALT-AND-ASK** | (don't guess) |

## Doc-shape detection (borrowed from the Gauntlet tiebreaker)

- `## Tasks`/`## Steps` + per-task file targets → impl-plan.
- `When … shall` EARS + file paths, no task list → spec.
- `## Approaches`/`## Architecture`, no AC → design doc → **DESIGN lane (P2) → HALT-AND-ASK in P1**.
- none-of-the-above → halt-and-ask.

## Stale-plan drift-check (EXECUTE only — never blindly run a prior-session plan)

1. **Jira drift:** scope changed, work already started, new blockers on the ticket.
2. **Local file verification:** named files still exist, functions still match, no PR already merged part of it.
- **Material drift → STOP and recommend re-planning** (executing a stale plan compounds wrong work across N tasks).
- Cosmetic/no drift → proceed.
- Also detect: plan is already a Compounds project with tasks (→ resume from task order) vs. a fresh markdown plan (→ Planner registers it + generates tasks).

## Cross-repo detection (EXT-7497 category — out of P1/P2 scope)

If the change spans multiple repos, DO NOT silently mis-route. Announce:
"This spans N repos — the Kiln runs one repo per run. This is N single-repo runs." Then stop and let the user choose.
