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
{{RUN_FOLDER}} = $(git rev-parse --show-toplevel)/projects/active/<jira_key>/kiln/
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
  {{RUN_FOLDER}} = $(git rev-parse --show-toplevel)/projects/active/<slug>/kiln/
  ```
  Then `mkdir -p {{RUN_FOLDER}}`.

**EXECUTE (plan file provided):**
```
{{RUN_FOLDER}} = $(git rev-parse --show-toplevel)/projects/active/<jira_key>/kiln/
```
Same as TICKET.

---

## Block 1.4: Branch Precondition (all entry forms)

Run: `git symbolic-ref --short HEAD`

- If output is `main` or `master`:
  - TICKET/TICKET_WITH_PLAN → `git checkout -b kiln/<jira_key>`
  - RAW_IDEA → `git checkout -b kiln/raw-<entry-slug>` (slug = first 3 words of idea, lowercased, hyphenated)
  - Write ledger: `BRANCH: created <branch-name> | <ISO timestamp>`
- If output is any other branch name → proceed silently (no ledger entry needed)
- If `git symbolic-ref` fails (detached HEAD) → treat as non-default, proceed silently

---

## Block 1.5: Artifact Verification (TICKET and TICKET_WITH_PLAN only)

### Artifact Verification

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

## Block 1.6: Read Lessons (all entry forms)

Read the cross-run lessons corpus before routing.

**Corpus path:** `$(git rev-parse --show-toplevel)/projects/active/kiln-lessons.md`

- If file absent → treat as zero lessons, proceed silently (do NOT create the file here)
- Parse each line matching: `- [YYYY-MM-DD] scope:<x> | trigger:<y> | gate:<z> | action:<a> | runs:<ids>`
- Skip malformed lines silently; do not abort the run

**Scope match rules** (filter which lessons to surface):

| Scope | Include when |
|-------|-------------|
| `branch`, `entry`, `routing`, `compounds` | Always (every run reaches these blocks) |
| `repo-onboarding` | Only if repo not yet indexed (`init_repo` needed) |
| `dispatch` | Only if tier resolves to STANDARD (TRIVIAL skips per-task dispatch) |

**Ranking:** sort surviving lessons by `len(runs)` descending (most recurrent first).

**Surface pre-flight notice** if N > 0:
```
**[Kiln] Pre-flight — N lessons from prior runs:**
- <scope>: <action> (<len(runs)> runs)
```

If N > 7, append one line: `(>7 lessons surfaced — consider pruning kiln-lessons.md)`

If N == 0, proceed silently (no notice emitted).

Write ledger: `LESSONS-READ: <N> surfaced | <ISO timestamp>`

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
- Emit: `**[Kiln] Phase: REFINE — transforming entry into spec**`
- Load `dispatch-contracts.md`, dispatch `refiner` agent using Refiner template
- Wait for `REFINER_DONE: {{RUN_FOLDER}}/design.md + {{RUN_FOLDER}}/spec-draft.md written | run-id: <slug>`
- Write ledger: `REFINE: spec drafted | {{RUN_FOLDER}}/design.md + {{RUN_FOLDER}}/spec-draft.md`
- Proceed to Block 3

---

## Block 3: Compounds Integration

### GATE: plan_change-first

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
- Emit: `**[Kiln] Phase: PLAN — authoring task breakdown**`
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

- Emit: `**[Kiln] Task {{N}}/{{TOTAL_TASKS}}: implementing {{task title}}**`

**5a. Get Compounds prompt and write brief**

Call `implement_task(project_id, task_id)` to get the prompt and context for this task.
From the response, extract the structured fields only (do NOT paste the full Compounds implementation prompt):
- Task title
- Acceptance criteria
- File targets
- Test strategy

Write `{{RUN_FOLDER}}/brief-N.md` with:
- Compounds task title + acceptance criteria (from implement_task response)
- File targets (from implement_task response)
- Test strategy (from implement_task response)
- Prior-task interfaces (from orchestrator context — function signatures, file paths, exported types)

**5b. Dispatch crafter**

Load `dispatch-contracts.md` (Crafter template) and `model-routing.md` (first dispatch only).
Dispatch `crafter` agent with four-part contract from template.
Wait for `CRAFTER_DONE: {{RUN_FOLDER}}/report-N.md written, commit: <SHA>`

**5c. TASK-GATE (STANDARD + HIGH blast radius only)**

Dispatch `inspector` agent using Inspector template from `dispatch-contracts.md`.
Wait for `INSPECTOR_DONE: {{RUN_FOLDER}}/verdict-N.md written`

Read `{{RUN_FOLDER}}/verdict-N.md`. Evaluate gate condition:
- `spec: ✅` AND `quality: approved` → PASS → proceed to 5e
- Any other result → FIX LOOP (see 5d)

**5d. Fix loop (cap: 2 iterations)**

On inspector findings:
1. Dispatch crafter with findings as context (load dispatch-contracts.md Crafter template, append findings)
2. Wait for `CRAFTER_DONE`
3. Re-dispatch inspector, wait for `INSPECTOR_DONE`
4. Read new `{{RUN_FOLDER}}/verdict-N.md`
5. If PASS → proceed to 5e
6. If still failing after 2 fix iterations → ESCALATION (do NOT call implement_task_finalize):

```
HARD STOP — TASK-GATE ESCALATION
Task N has failed inspection after 2 fix attempts.
Inspector verdict: {{RUN_FOLDER}}/verdict-N.md
Action required: review findings and decide how to proceed.
```

Run `git log --oneline` to surface the failed-task commit range. Either `git revert` the commits in reverse order and push, or document the range in the escalation message.

Write ledger: `TASK-N: ESCALATED | fix-loops: 2 | {{RUN_FOLDER}}/verdict-N.md`
Stop execution. Do not proceed to next task.

**5e. Finalize on PASS**

Reached only when Inspector verdict is `spec: ✅` AND `quality: approved`.

Read `{{RUN_FOLDER}}/verdict-N.md` to extract evidence fields (`criteria_met`, `criteria_total`, `critical_findings`, `changed_files`).
Read `{{RUN_FOLDER}}/report-N.md` to extract changed files list.

Call:
```
implement_task_finalize(
  project_id=<id>,
  task_id=<id>,
  caller_role="orchestrator",
  phase="validate",
  evidence={
    validation_summary: "<Inspector verdict summary + key findings, ≥200 chars>",
    criteria_met: <from Inspector verdict>,
    criteria_total: <from Inspector verdict>,
    critical_findings: <from Inspector verdict>,
    changed_files: <from crafter report>
  }
)
```

- If `implement_task_finalize` succeeds → write ledger entry (5f)
- If `implement_task_finalize` fails → escalate (same HARD STOP as task-gate escalation above)

**5f. Ledger entry (on successful finalize)**

```
DONE task-N: <title> | commits: <sha1>..<sha2> | inspected: ✅
```

(TRIVIAL tasks skip inspection and finalize: `DONE task-1: <title> | commits: <sha> | inspected: N/A`)

---

## Block 6: Final Gate

Emit: `**[Kiln] Phase: FINAL — running quality gate and creating PR**`

After all tasks complete:

1. Run `code-quality-audit` skill on `git diff main...HEAD`
2. Invoke `/create-pr` skill — enforces title format and body template
3. **Verify:** Confirm PR URL is returned. Surface the URL to the user. If `/create-pr` does not return a URL, stop and report the failure — do not write the COMPLETE ledger entry.
4. Generate retro — see **Retro Generation** below.

## Retro Generation

Load `retro-template.md` on-demand from `plugins/kiln/skills/fire/retro-template.md`.

### Friction Detection

Parse `{{RUN_FOLDER}}/progress.md`:
- `fix_loops` = count of lines matching `FIX-LOOP:`
- `escalations` = count of lines matching `ESCALATED`
- `user_corrections` = count of lines matching `USER-CORRECTION:`
- `routing_mismatch` = 1 if any `ROUTING:` entry differs from Block 1 routing decision, else 0

`friction_score` = fix_loops + escalations + user_corrections + routing_mismatch

### Retro Selection

- `friction_score == 0` → use terse-stub from retro-template.md
- `friction_score >= 1` → use full-form from retro-template.md

### Auto-Seed Fields

Populate from progress.md and verdict-N.md:
- Run ID, routing mode, tier, blast radius
- Task count, commit SHAs
- Gate fires (SPEC-GATE, PLAN-GATE, TASK-GATE escalations)
- Fix loop details (which tasks, how many iterations)
- Inspector findings summary

Write retro to: `{{RUN_FOLDER}}/kiln-retro.md`

### Distill Lessons (runs when friction_score >= 1)

**Corpus path:** `$(git rev-parse --show-toplevel)/projects/active/kiln-lessons.md`

For each friction item recorded in `progress.md`, evaluate:

1. **Mechanically preventable?**
   - YES: wrong branch, skipped `plan_change`, committed to main, missing artifact check
   - NO: narration notes, pacing complaints, judgment calls, "felt slow" observations
   - If NO → skip; item stays in retro prose only, never enters corpus

2. **Already in corpus?** Match on `scope` + `trigger` (exact string match).

Three-way outcome:
- **New + preventable** → append: `- [YYYY-MM-DD] scope:<x> | trigger:<y> | gate:<z> | action:<a> | runs:<this-run-id>`
  - `scope` MUST be one of: `branch`, `entry`, `routing`, `compounds`, `repo-onboarding`, `dispatch`
  - `gate` = block reference (e.g., `Block-1.4`) or `none-yet` if no gate exists yet
  - Write ledger: `LESSON-WRITE: new scope:<x> trigger:<y> | <ISO timestamp>`
- **Existing** → find the matching line, append `,<this-run-id>` to its `runs:` field
  - Write ledger: `LESSON-WRITE: bump scope:<x> trigger:<y> | <ISO timestamp>`
- **Not preventable** → no write, no ledger entry

**Error posture:** if the corpus write fails, log the failure and continue. A distill error must NEVER block retro completion or PR creation.

Write ledger: `RETRO: terse|full | <ISO timestamp>`

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

---

## Block 8: Ledger Entry Reference

All ledger entries are written to `{{RUN_FOLDER}}/progress.md`.

| Entry | Format | Written when |
|-------|--------|--------------|
| `BRANCH:` | `BRANCH: created <branch-name> \| <ISO timestamp>` | New branch created in Block 1.4 |
| `ARTIFACT-GATE:` | `ARTIFACT-GATE: fired \| missing: <artifacts> \| <ISO timestamp>` | Required artifacts absent at gate |
| `REFINE:` | `REFINE: spec drafted \| {{RUN_FOLDER}}/design.md + {{RUN_FOLDER}}/spec-draft.md` | Refiner completes spec |
| `PLAN:` | `PLAN: {{RUN_FOLDER}}/plan.md written \| subtasks: <keys>` | Plan written in Block 3 |
| `PLAN-GATE:` | `PLAN-GATE: approved \| <ISO timestamp>` | User approves plan |
| `SPEC-GATE:` | `SPEC-GATE: approved \| <ISO timestamp>` | User approves spec |
| `FIX-LOOP:` | `FIX-LOOP: task-N iteration <n> \| <ISO timestamp>` | Fix iteration triggered after Inspector FAIL |
| `TASK-N: ESCALATED` | `TASK-N: ESCALATED \| fix-loops: 2 \| {{RUN_FOLDER}}/verdict-N.md` | Task escalated after 2 fix failures |
| `DONE` | `DONE task-N: <title> \| commits: <sha1>..<sha2> \| inspected: ✅` | Task finalized successfully |
| `PAUSED:` | `PAUSED: task-N in progress \| <ISO timestamp>` | Context-reset nudge fires |
| `LESSONS-READ:` | `LESSONS-READ: <N> surfaced \| <ISO timestamp>` | Block 1.6 completes (written even when N == 0 and corpus exists) |
| `LESSON-WRITE:` | `LESSON-WRITE: new\|bump scope:<x> trigger:<y> \| <ISO timestamp>` | Block 6 distill writes or bumps a lesson (one entry per action; not written if nothing qualifies) |
| `RETRO:` | `RETRO: terse\|full \| <ISO timestamp>` | Retro written in Block 6 |
| `COMPLETE:` | `COMPLETE: PR created \| <url> \| <branch> \| <ISO timestamp>` | PR created in Block 6 |
| `USER-CORRECTION:` | `USER-CORRECTION: <description> \| <ISO timestamp>` | User issues mid-run correction |

### USER-CORRECTION: ledger entry

**When to write:** Whenever the user issues a mid-run correction — explicit pushback,
direction change, or hard-stop override. Detect this from any user message that contradicts,
overrides, or restates a decision already recorded in `progress.md`.

**Write step:** Immediately after detecting the correction, before resuming any implementation work:
```
Write ledger: USER-CORRECTION: <one-sentence description of what changed> | <ISO timestamp>
```

Format: `USER-CORRECTION: <description> | <ISO timestamp>`

Affects `friction_score` — triggers full retro if present.
