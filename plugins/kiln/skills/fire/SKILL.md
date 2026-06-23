---
name: kiln
description: Complexity-proportionate implementation workflow. Use for any development task: Jira ticket, raw idea, or ticket with existing plan. Entry forms: /kiln EXT-NNNN | /kiln "raw idea" | /kiln EXT-NNNN path/to/plan.md
---

# The Kiln — Orchestrator

The Kiln is a complexity-proportionate implementation workflow. It routes, coordinates, and enforces gates. It does not implement code and does not review code — those belong to crafter and inspector.

**When NOT to use:** docs-only edits, hotfixes with a known spec and no Compounds task list needed, or single-file typo/config changes. Use The Kiln when you need routing, gate enforcement, or multi-task TDD implementation.

**Progressive disclosure:** Load on-demand files only when needed:
- `modes.md` — load once during routing decision
- `dispatch-contracts.md` — load once per Class dispatch
- `model-routing.md` — load once at first crafter dispatch, cache in-context

**Ledger:** `{{RUN_FOLDER}}/progress.md` — written before every gate transition. On resume after `/clear`, read the ledger and continue from the first incomplete task.

---

## Block 1: Entry Parsing

Parse the `/kiln` invocation argument:

```
/kiln EXT-7394                          → Jira ticket key
/kiln "add env copy to workspaces"      → raw idea string
/kiln EXT-7394 path/to/existing.plan.md → ticket + existing plan (EXECUTE fast-path)
```

Detection rules:
- Arg matches `[A-Z]+-\d+` followed by a `.md` path → EXECUTE fast-path
- Arg matches `[A-Z]+-\d+` alone → read ticket signals via Jira MCP
- Arg is a quoted string → raw idea → REFINE path

Build routing decision object:
```
entry_form: TICKET | RAW_IDEA | TICKET_WITH_PLAN
jira_key: <key or null>
plan_file: <path or null>
ticket_signals: <list from ticket read or null>
```

**Verify:** Confirm `entry_form` is set, and `jira_key` is non-null for TICKET and TICKET_WITH_PLAN forms. If `jira_key` is null for a TICKET form, surface the parse failure and stop — do not proceed to routing.

---

## Block 1.25: Run-Folder Bootstrap

Set `{{RUN_FOLDER}}` based on entry form:

**TICKET / TICKET_WITH_PLAN:**
```
{{RUN_FOLDER}} = jcslOS/projects/active/<jira_key>/kiln/
```
Create the directory if it does not exist:
```bash
mkdir -p {{RUN_FOLDER}}
```

**RAW_IDEA:**
`{{RUN_FOLDER}}` is unknown until the Refiner completes. Defer:
- Set a placeholder `{{RUN_FOLDER}} = PENDING`
- After `REFINER_DONE: ... | run-id: <slug>` is received, compute:
  ```
  {{RUN_FOLDER}} = jcslOS/projects/active/<slug>/kiln/
  ```
  Then `mkdir -p {{RUN_FOLDER}}`.

**EXECUTE (plan file provided):**
```
{{RUN_FOLDER}} = jcslOS/projects/active/<jira_key>/kiln/
```
Same as TICKET.

---

## Block 1.5: Artifact Verification (TICKET and TICKET_WITH_PLAN only)

Skip for RAW_IDEA entries — no repo claims to verify.

Before calling Compounds or dispatching any agent, verify the ticket's concrete claims match the current repo. Extract:
- **Package names** — any version bump or dep-remediation language (e.g., "floor `simple-git` to ≥3.x")
- **File paths** — any explicitly named source files
- **Deployed artifact names** — function names, service names, Lambda identifiers

For each extracted artifact, run a fast existence check:
- Package: `grep -r "<name>" package.json` (or equivalent manifest)
- File path: `test -f <path>`
- Function/service name: `grep -r "<name>" serverless.yml` (or `cdk` / `terraform` entrypoints)

**Gate condition:**
- At least one claimed artifact found → proceed to Block 2
- Zero claimed artifacts found → **ARTIFACT-GATE fires**:

```
ARTIFACT-GATE — repo mismatch detected
Ticket names artifacts not present in this repo:
  <list each missing artifact and what check failed>
This ticket may target a different repository.
Action required: confirm the correct repo before proceeding.
```

Write ledger: `ARTIFACT-GATE: fired | missing: <artifacts> | <ISO timestamp>`
Stop. Do not proceed to Block 2.

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
- Wait for `REFINER_DONE: {{RUN_FOLDER}}/spec-draft.md written`
- Write ledger: `REFINE: spec drafted | {{RUN_FOLDER}}/spec-draft.md`
- Proceed to Block 3

---

## Block 3: Compounds Integration

## GATE: plan_change-first

**Condition:** This gate fires if file edits, file creation, or implementation steps
are attempted before `plan_change(step="start")` has returned a successful routing result.

**Violation action:**
```
PLAN_CHANGE-FIRST GATE — HARD STOP
You attempted to edit files or write code before running plan_change(step="start").
Action required: Run plan_change(step="start") first, then resume from Block 3.
Do NOT proceed until plan_change routing completes.
```

**Pass condition:** `plan_change(step="start")` has been called and returned a tier/blast-radius
classification in this session. Then continue to the routing decision below.

---

Call `plan_change(step="start")` and follow the state machine through all steps until routing completes.

After Compounds produces tier + blast radius classification:

**TRIVIAL:**
- No gates fire
- Write `{{RUN_FOLDER}}/tasklist.md` from Compounds task (single task)
- Jump to Block 5 (single Crafter dispatch, no Inspector)

**STANDARD + HIGH blast radius:**
- SPEC-GATE fires (see Block 4)
- Then continue to generate tasks

**STANDARD (any blast radius):**
- Call `generate_tasks` to produce the full task list
- Write task list to `{{RUN_FOLDER}}/tasklist.md`
- Load `dispatch-contracts.md`, dispatch `planner` using Planner template
- Wait for `PLANNER_DONE: {{RUN_FOLDER}}/plan.md written, subtasks: ...`
- Write ledger: `PLAN: {{RUN_FOLDER}}/plan.md written | subtasks: <keys>`

**PLAN-GATE** (STANDARD only — fires for both LOW and HIGH blast radius):

```
PLAN-GATE — HARD STOP
Present task list from {{RUN_FOLDER}}/plan.md to user.
Do NOT proceed until the user responds with an explicit "approve".
On any other response: apply requested edits to {{RUN_FOLDER}}/plan.md, re-present, and return to this HARD STOP.
```

Write ledger: `PLAN-GATE: approved | <ISO timestamp>`
After explicit "approve": proceed to Block 5 (per-task loop).

---

## Block 4: SPEC-GATE

Fires only for STANDARD + HIGH blast radius, after Refiner completes (REFINE path) or after `plan_change` confirms HIGH blast radius (ORIENT path).

```
SPEC-GATE — HARD STOP
Present spec summary ({{RUN_FOLDER}}/spec-draft.md if REFINE path, or ticket summary).
Do NOT proceed until the user responds with an explicit "approve".
On any other response: apply requested edits to the spec, re-present, and return to this HARD STOP.
```

Write ledger: `SPEC-GATE: approved | <ISO timestamp>`

---

## Block 5: Per-Task Loop

Read ledger to find first incomplete task — this is resume support after `/clear`.

For each Compounds task (STANDARD) or the single task (TRIVIAL):

**5a. Write brief**

Extract task N from `{{RUN_FOLDER}}/tasklist.md`. Write `{{RUN_FOLDER}}/brief-N.md`.
Required sections: Task title, Acceptance criteria, File targets, Test strategy, Prior-task interfaces.

**5b. Dispatch crafter**

Load `dispatch-contracts.md` (Crafter template) and `model-routing.md` (first dispatch only).
Dispatch `crafter` agent with four-part contract from template.
Wait for `CRAFTER_DONE: {{RUN_FOLDER}}/report-N.md written, commit: <SHA>`

**5c. TASK-GATE (STANDARD + HIGH blast radius only)**

Dispatch `inspector` agent using Inspector template from `dispatch-contracts.md`.
Wait for `INSPECTOR_DONE: {{RUN_FOLDER}}/verdict-N.md written`

Read `{{RUN_FOLDER}}/verdict-N.md`. Evaluate gate condition:
- `spec: ✅` AND `quality: approved` → PASS → write ledger entry, advance to next task
- Any other result → FIX LOOP (see 5d)

**5d. Fix loop (cap: 2 iterations)**

On inspector findings:
1. Dispatch crafter with findings as context (load dispatch-contracts.md Crafter template, append findings)
2. Wait for `CRAFTER_DONE`
3. Re-dispatch inspector, wait for `INSPECTOR_DONE`
4. Read new `{{RUN_FOLDER}}/verdict-N.md`
5. If PASS → write ledger, advance
6. If still failing after 2 fix iterations:

```
HARD STOP — TASK-GATE ESCALATION
Task N has failed inspection after 2 fix attempts.
Inspector verdict: {{RUN_FOLDER}}/verdict-N.md
Action required: review findings and decide how to proceed.
```

Run `git log --oneline` to surface the failed-task commit range. Either `git revert` the commits in reverse order and push, or document the range in the escalation message.

Write ledger: `TASK-N: ESCALATED | fix-loops: 2 | {{RUN_FOLDER}}/verdict-N.md`
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
3. **Verify:** Confirm PR URL is returned. Surface the URL to the user. If `/create-pr` does not return a URL, stop and report the failure — do not write the COMPLETE ledger entry.

Write ledger: `COMPLETE: PR created | <url> | <branch> | <ISO timestamp>`

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
3. On resume: read ledger, find first entry without DONE status, continue from there. Before dispatching crafter for task N, run `git log --oneline origin/main..HEAD` and check whether a commit matching task N's title already exists. If it does, read the commit SHA, write the DONE ledger entry, and advance to task N+1.
