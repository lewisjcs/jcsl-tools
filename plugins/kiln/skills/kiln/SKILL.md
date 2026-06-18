---
name: kiln
description: Complexity-proportionate implementation workflow. Use for any development task: Jira ticket, raw idea, or ticket with existing plan. Routes to REFINE/ORIENT/EXECUTE, invokes Compounds for impact analysis and task generation, enforces SPEC-GATE/PLAN-GATE/TASK-GATE, runs TDD implementation via crafter, quality review via inspector, and creates PR. Entry forms: /kiln EXT-NNNN | /kiln "raw idea" | /kiln EXT-NNNN path/to/plan.md
---

# The Kiln — Orchestrator

The Kiln is a complexity-proportionate implementation workflow. It routes, coordinates, and enforces gates. It does not implement code and does not review code — those belong to crafter and inspector.

**Progressive disclosure:** Load on-demand files only when needed:
- `modes.md` — load once during routing decision
- `dispatch-contracts.md` — load once per Class dispatch
- `model-routing.md` — load once at first crafter dispatch, cache in-context

**Ledger:** `$(git rev-parse --git-dir)/kiln-progress.md` — written before every gate transition. On resume after `/clear`, read the ledger and continue from the first incomplete task.

---

## Block 1: Entry Parsing

Parse the `/kiln` invocation argument:

```
/kiln EXT-7394                          → Jira ticket key
/kiln "add env copy to workspaces"      → raw idea string
/kiln EXT-7394 path/to/existing.plan.md → ticket + existing plan (EXECUTE fast-path)
```

Detection rules:
- Arg matches `EXT-\d+` followed by a `.md` path → EXECUTE fast-path
- Arg matches `EXT-\d+` alone → read ticket signals via Jira MCP
- Arg is a quoted string → raw idea → REFINE path

Build routing decision object:
```
entry_form: TICKET | RAW_IDEA | TICKET_WITH_PLAN
jira_key: <key or null>
plan_file: <path or null>
ticket_signals: <list from ticket read or null>
```

---

## Block 2: Routing Decision

Load `modes.md` now. Apply the routing table:

**EXECUTE** — if `plan_file` is present:
- Skip Refiner and Planner
- Proceed to Block 3 (Compounds integration) with plan as context

**ORIENT** — if ALL signals present: EARS AC + file paths + root cause:
- Skip Refiner
- Proceed to Block 3

**REFINE** — if any signal is missing or entry is a raw idea:
- Load `dispatch-contracts.md`, dispatch `refiner` agent using Refiner template
- Wait for `REFINER_DONE: kiln-spec-draft.md written`
- Write ledger: `REFINE: spec drafted | kiln-spec-draft.md`
- Proceed to Block 3

---

## Block 3: Compounds Integration

Call `plan_change(step="start")` and follow the state machine through all steps until routing completes.

After Compounds produces tier + blast radius classification:

**TRIVIAL:**
- No gates fire
- Write `kiln-tasklist.md` from Compounds task (single task)
- Jump to Block 5 (single Crafter dispatch, no Inspector)

**STANDARD + HIGH blast radius:**
- SPEC-GATE fires (see Block 4)
- Then continue to generate tasks

**STANDARD (any blast radius):**
- Call `generate_tasks` to produce the full task list
- Write task list to `kiln-tasklist.md`
- Load `dispatch-contracts.md`, dispatch `planner` using Planner template
- Wait for `PLANNER_DONE: kiln-plan.md written, subtasks: ...`
- Write ledger: `PLAN: kiln-plan.md written | subtasks: <keys>`

**PLAN-GATE** (STANDARD only — fires for both LOW and HIGH blast radius):
```
Present task list from kiln-plan.md to user.
STOP — wait for explicit "approve" before proceeding.
Do not proceed on any other response.
```

After approval: proceed to Block 5 (per-task loop).

---

## Block 4: SPEC-GATE

Fires only for STANDARD + HIGH blast radius, after Refiner completes (REFINE path) or before `plan_change` on ORIENT path with HIGH blast.

```
Present spec summary (kiln-spec-draft.md if REFINE path, or ticket summary).
STOP — wait for explicit "approve" before proceeding.
Do not proceed on any other response. Apply requested edits and re-present.
```

Write ledger: `SPEC-GATE: approved | <ISO timestamp>`

---

## Block 5: Per-Task Loop

Read ledger to find first incomplete task — this is resume support after `/clear`.

For each Compounds task (STANDARD) or the single task (TRIVIAL):

**5a. Write brief**

Extract task N from `kiln-tasklist.md`. Write `kiln-brief-N.md` at repo root.
Required sections: Task title, Acceptance criteria, File targets, Test strategy, Prior-task interfaces.

**5b. Dispatch crafter**

Load `dispatch-contracts.md` (Crafter template) and `model-routing.md` (first dispatch only).
Dispatch `crafter` agent with four-part contract from template.
Wait for `CRAFTER_DONE: kiln-report-N.md written, commit: <SHA>`

**5c. TASK-GATE (STANDARD + HIGH blast radius only)**

Dispatch `inspector` agent using Inspector template from `dispatch-contracts.md`.
Wait for `INSPECTOR_DONE: kiln-verdict-N.md written`

Read `kiln-verdict-N.md`. Evaluate gate condition:
- `spec: ✅` AND `quality: approved` → PASS → write ledger entry, advance to next task
- Any other result → FIX LOOP (see 5d)

**5d. Fix loop (cap: 2 iterations)**

On inspector findings:
1. Dispatch crafter with findings as context (load dispatch-contracts.md Crafter template, append findings)
2. Wait for `CRAFTER_DONE`
3. Re-dispatch inspector, wait for `INSPECTOR_DONE`
4. Read new `kiln-verdict-N.md`
5. If PASS → write ledger, advance
6. If still failing after 2 fix iterations:

```
HARD STOP — TASK-GATE ESCALATION
Task N has failed inspection after 2 fix attempts.
Inspector verdict: kiln-verdict-N.md
Action required: review findings and decide how to proceed.
```

Write ledger: `TASK-N: ESCALATED | fix-loops: 2 | kiln-verdict-N.md`
Stop execution. Do not proceed to next task.

**5e. Ledger entry (on PASS)**

```
DONE task-N: <title> | commits: <sha1>..<sha2> | inspected: ✅
```

(TRIVIAL tasks: `DONE task-1: <title> | commits: <sha> | inspected: N/A`)

---

## Block 6: Final Gate

After all tasks complete:

1. Run `code-quality-audit` skill on `git diff main...HEAD`
2. Invoke `/create-pr` skill — enforces title format and body template

Write ledger: `COMPLETE: PR created | <branch> | <ISO timestamp>`

---

## Block 7: Context-Reset Awareness

If the context-reset nudge fires mid-execution:

1. Write current task position to ledger:
   `PAUSED: task-N in progress | <ISO timestamp>`
2. Surface handoff path to user:
   ```
   Context limit approaching. Run /handoff then /clear.
   Resume with: /kiln <original entry arg>
   The Kiln will read the ledger and continue from task N.
   ```
3. On resume: read ledger, find first entry without DONE status, continue from there.
