# Kiln Gates (P1)

Loaded on-demand. Each gate is evaluated by the CONDUCTOR reading a member's typed return field —
never the worker grading itself. P1 has no SPEC-GATE (that pairs with the P2 Designer); P1 gates are PLAN and TASK.

## Gate table

| Gate | Fires when | Reads | Pass condition |
|---|---|---|---|
| **PLAN-GATE** | after Planner, before first Crafter — all STANDARD | `plan.md` (+ `walkthrough.md` on HIGH blast) | user types explicit approval |
| **TASK-GATE** | after each Inspector — blocks on HIGH blast only | `verdict-N.md` typed fields | `spec: ✅` AND `quality: approved` |

## Tier × blast behavior (Inspector-runs vs gate-blocks are SEPARATE decisions)

- **TRIVIAL** (Compounds score 6–9): no gates, NO Inspector. Single Crafter dispatch; the **Crafter** marks the task done via `update_task(status="DONE")` (the conductor cannot call it — the guard forbids it).
- **STANDARD + LOW blast:** PLAN-GATE only. Inspector RUNS every task (verdict feeds `finalize`), but TASK-GATE does NOT block — findings recorded, run advances.
- **STANDARD + HIGH blast:** **Walker at PLAN-GATE** + PLAN-GATE + TASK-GATE per task. Inspector runs AND TASK-GATE blocks: non-passing verdict → fix loop (cap 2) → escalate (revert the task's commits, HARD STOP).

## Flow-styles (configurable gate pausing)

| Flow-style | PLAN-GATE | TASK-GATE |
|---|---|---|
| `guided` (default) | pause for explicit approval | block on findings (HIGH blast) |
| `planning_gate` | pause | auto-advance on clean verdict |
| `implementation_gate` | auto-proceed | block on findings |
| `hands_free` | auto-proceed | auto-advance; escalate only on 2× fix-loop failure |

Default `guided`. Owner sets per-run (`/kiln <KEY> --flow hands_free`). Never pass `flow_style` to Compounds unless the owner explicitly set one.

## Generator-Critic separation (AIS RFC mandate)

Inspector and Walker receive ONLY the output artifact (brief/report/diff, or plan/spec) — never the
Crafter's or author's reasoning trace. The conductor branches mechanically on their typed return field.
