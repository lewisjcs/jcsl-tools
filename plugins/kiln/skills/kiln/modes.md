# Kiln Modes — Routing Reference

Loaded on-demand by `SKILL.md` during the routing decision. Do not always-load.

---

## Mode Definitions

### REFINE

**Purpose:** Shape fuzzy or underspecified input into a defined implementation requirement before calling Compounds.

**Entry condition:** One or more of the following signals is present:
- Acceptance criteria are fuzzy (vague outcomes, no measurable conditions)
- Title-only ticket (no description body)
- RFC linked but not readable (URL only, content not accessible)
- Figma placeholder (linked but empty or stub)
- Parent epic with thin description (no child-level detail)

**Action:** Dispatch `refiner` agent. Wait for spec approval (SPEC-GATE fires for HIGH blast radius after Refiner completes). Then proceed as ORIENT.

---

### ORIENT

**Purpose:** Proceed directly to Compounds integration when the ticket is well-formed.

**Entry condition:** ALL of the following signals are present:
- EARS acceptance criteria present (When/Then/Shall format)
- File paths specified (concrete implementation targets named)
- Root cause explained (problem statement present, not just symptom)

**Action:** Call `plan_change(step="start")` immediately. No Refiner dispatch needed.

---

### EXECUTE

**Purpose:** Fast-path to implementation when a plan file already exists.

**Entry condition:** A plan file path was passed as the second argument to `/kiln`:
```
/kiln EXT-7394 path/to/existing.plan.md
```

**Action:** Skip Refiner and Planner entirely. Call `plan_change(step="start")` with the existing plan as context. Proceed directly to the per-task loop.

Gate behavior on EXECUTE:
- **SPEC-GATE:** skipped — a plan file was already provided and approved by the caller
- **PLAN-GATE:** skipped — no Planner dispatch means no kiln-plan.md to present
- **TASK-GATE:** fires on each task when `plan_change` returns HIGH blast radius — EXECUTE does not bypass per-task inspection

---

## Routing Signal Table

Full decision tree from design spec §5.2:

| Input Signal | Mode | Agents Skipped |
|---|---|---|
| Plan file path present as second arg | EXECUTE | refiner, planner |
| EARS AC + file paths + root cause | ORIENT | refiner |
| Fuzzy AC | REFINE | (none — refiner dispatched first) |
| Title-only ticket | REFINE | (none — refiner dispatched first) |
| RFC linked but not readable | REFINE | (none — refiner dispatched first) |
| Figma placeholder | REFINE | (none — refiner dispatched first) |
| Parent epic with thin description | REFINE | (none — refiner dispatched first) |

**Precedence:** EXECUTE check runs first. If no plan file arg, score ORIENT signals. If any ORIENT signal is missing, enter REFINE.

---

## Complexity Tier Mapping (post-routing)

After mode selection produces a defined requirement, `plan_change(step="start")` classifies the tier:

| Tier | Blast Radius | Gates Fired | Notes |
|---|---|---|---|
| TRIVIAL | N/A | None | Single Crafter dispatch, no gate pauses |
| STANDARD | LOW | PLAN-GATE | One pause before first Crafter dispatch |
| STANDARD | HIGH | SPEC-GATE + PLAN-GATE + TASK-GATE | SPEC-GATE after Refiner (REFINE path) or after plan_change confirms HIGH blast radius (ORIENT path); TASK-GATE after each Crafter |

**SPEC-GATE fires only for STANDARD + HIGH blast radius.** TRIVIAL and STANDARD + LOW blast bypass SPEC-GATE entirely.

**TASK-GATE fires only for STANDARD + HIGH blast radius.** Crafter/Inspector loop runs once per task; Inspector verdict must return `spec: ✅` AND `quality: approved` before next task starts.
