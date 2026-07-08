# Kiln Lanes (P2.1)

Loaded on-demand at the classify verb. Implements EXECUTE / PLAN / TRIVIAL / RESUME / RESEARCH / DESIGN.
RESEARCH and DESIGN lanes (Scout, Designer, SPEC-GATE) are now live as of P2.1 — a sparse/partial ticket
routes into RESEARCH/DESIGN instead of halting.

## Entry detection (mechanical first, prefix-agnostic `[A-Z]+-\d+`)

| Entry | Detected as | Lane | Members |
|---|---|---|---|
| `<KEY> <path>.md` numbered tasks + file targets | impl-plan | EXECUTE | drift-check → Planner(register) → Build |
| `<KEY> <path>.md` EARS AC + paths, no tasks | spec | PLAN | Planner → Build |
| `<KEY>` ticket: EARS AC + paths + root cause | complete | PLAN | Planner → Build |
| `<KEY>` ticket: some AC, no paths | partial | **DESIGN** | Designer → SPEC-GATE → Planner → Build |
| `<KEY>` ticket: title-only / thin / epic-only | sparse | **RESEARCH** | Scout → Designer → SPEC-GATE → Planner → Build |
| Quoted string, no ticket | net-new | **DESIGN** | Designer → SPEC-GATE → Planner → Build (local kebab-slug run-id; NO Jira offer — P2.2) |
| File = design doc (`## Approaches`/`## Architecture`, no AC) | design-doc | **DESIGN (mid-flow)** | Designer enters with design.md pre-supplied → convert → SPEC-GATE → Planner → Build |
| re-invoke with active run folder + ledger | resume | RESUME | read ledger → Build from first incomplete |
| file shape none-of-the-above | — | HALT-AND-ASK | (don't guess) |

## Doc-shape detection (borrowed from the Gauntlet tiebreaker)

- `## Tasks`/`## Steps` + per-task file targets → impl-plan.
- `When … shall` EARS + file paths, no task list → spec.
- `## Approaches`/`## Architecture`, no AC → design doc → **DESIGN (mid-flow)** — Designer enters with
  design.md pre-supplied and converts it, no HALT.
- none-of-the-above → halt-and-ask.

**Lane vs. scenario are ORTHOGONAL dimensions.** A design-doc ENTRY is an *input to convert into a spec*
→ routes DESIGN (mid-flow); it is NOT the `doc/RFC` *scenario* (which is when the change's DELIVERABLE is
prose to author). The `.md` shape of the ENTRY never triggers a doc/RFC HALT — the scenario is derived
from the SYNTHESIZED file targets after the Designer runs (and stays code/tool-authoring; doc/RFC-as-
deliverable is still P2.2).

## Stale-plan drift-check (EXECUTE only — never blindly run a prior-session plan)

1. **Jira drift:** scope changed, work already started, new blockers on the ticket.
2. **Local file verification:** named files still exist, functions still match, no PR already merged part of it.
- **Material drift → STOP and recommend re-planning** (executing a stale plan compounds wrong work across N tasks).
- Cosmetic/no drift → proceed.
- Also detect: plan is already a Compounds project with tasks (→ resume from task order) vs. a fresh markdown plan (→ Planner registers it + generates tasks).

## Cross-repo detection (EXT-7497 category — out of P1/P2 scope)

If the change spans multiple repos, DO NOT silently mis-route. Announce:
"This spans N repos — the Kiln runs one repo per run. This is N single-repo runs." Then stop and let the user choose.
