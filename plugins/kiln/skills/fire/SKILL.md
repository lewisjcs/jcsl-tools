---
name: kiln
description: Complexity-proportionate implementation Party. Thin conductor — routes, gates, dispatches members; never implements inline. Entry: /kiln EXT-NNNN | /kiln "raw idea" | /kiln EXT-NNNN path/to/plan.md
---

# The Kiln — Conductor

A complexity-proportionate implementation Party. This conductor is **thin by capability**: while a run
is active it cannot edit source via the file-editing tools (Edit/Write/MultiEdit/NotebookEdit) or call
Compounds mutation tools — a plugin PreToolUse hook denies those in the main thread (see `hooks/`). This
is a behavioral guardrail, not a sandbox: the conductor still holds Bash (it needs git), so the guarantee
is "won't edit source through the editing tools," not "physically can't touch source." It routes, makes
the lane visible, builds a progress spine, dispatches members, and adjudicates gates from their typed
returns. It does not implement, plan, or design inline. Members hold the working tools.

**Progressive disclosure — load on demand:**
- `lanes.md` — at the classify verb (entry→lane matrix, doc-shape + drift-check).
- `scenarios.md` — at the classify verb (scenario detection → verifier + patterns source).
- `gates.md` — at the first gate (gate conditions, tier×blast behavior, flow-styles).
- `dispatch-contracts.md` — once per member dispatch (four-part templates).

**Ledger:** `{{RUN_FOLDER}}/progress.md`, written before every gate transition. On resume after `/clear`, read it and continue from the first incomplete task.

**Scope (P2.1):** EXECUTE / PLAN / TRIVIAL / RESUME / **DESIGN / RESEARCH** lanes; `code` + `tool-authoring` scenarios. SPEC-GATE, Scout, and the Designer are live. Still P2.2: the `mcp/agent-app` / `doc/RFC` / `infra` scenarios (they HALT) and all Jira write-back. An out-of-scope scenario or ambiguous doc shape → HALT-AND-ASK.

---

## Verb 1 — Read

Parse the entry argument. Prefix-agnostic key match `[A-Z]+-\d+`. Read the ticket (if any) via Jira-read.
Set `{{RUN_FOLDER}} = <WORKSPACE>/projects/active/<run-id>/kiln/` and `mkdir -p` it, where:
- `<WORKSPACE>` is the OS workspace root — the directory the session runs from (this OS launches from a
  non-git workspace that wraps many repos; do NOT use `git rev-parse --show-toplevel`, which would resolve
  into whichever nested repo the cwd sits in and scatter run folders across repos). Run folders always live
  in the workspace, never inside a repo.
- `<run-id>` is the Jira key if the entry has one (`[A-Z]+-\d+`); otherwise a kebab-slug derived from the
  entry (a raw-idea string or a keyless plan filename) — e.g. `/kiln "add dark mode"` → `add-dark-mode`.
  Confirm the slug with the user on net-new entries (see Verb 4).
If the entry includes a spec-shaped file (a PLAN-from-spec run — see `lanes.md`), stash it at
`{{RUN_FOLDER}}/spec-draft.md` (`cp` — a run-folder write, guard-exempt). That copy is the sole P1
producer of `spec-draft.md`; the Planner and Walker read it there. No spec file at entry → no stash, and
those consumers fall through to the ticket body (they already read `spec-draft.md` only "if present").

## Verb 2 — Classify & announce (LOUDLY)

Load `lanes.md` and `scenarios.md`. Determine lane + scenario now (from the entry + ticket). Tier + blast are NOT known yet — the Planner derives them from Compounds' classify step and returns them in its done-line; update the announcement with them after the Planner runs.
**Announce before any work**, task-kickoff style:
`**[Kiln] This is a <LANE> run, <SCENARIO> scenario — <one-line why>. Starting that path.**`
Sparse → RESEARCH; partial / net-new / design-doc → DESIGN (per `lanes.md`). Only a P2.2 scenario (`mcp/agent-app`/`doc/RFC`/`infra`) or an ambiguous doc shape → **HALT-AND-ASK** (do not guess, do not fall through to code).

**Write the active-run sentinel now, stamped with this session's id:**
`printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > {{RUN_FOLDER}}/.active`. (This is what arms the guard hooks.
The stamped session id is what scopes the guards to THIS run: Claude Code runs one Kiln run per
session/window, so a concurrent run in another window — with a different session id — will not bind this
window's guards, and vice-versa. An empty stamp still works but is treated as legacy/unowned. Remove it
in Verb 5.)
**Branch precondition:** the session runs from the non-git workspace, so operate on the TARGET REPO by
path with `git -C <repo>` (`<repo>` = the repo the change targets, e.g. `repos/<name>`, derived from the
plan's file targets or the entry). Run `git -C <repo> symbolic-ref --short HEAD`; if `main`/`master`,
`git -C <repo> checkout -b kiln/<run-id>` and write ledger `BRANCH: created kiln/<run-id> | <ISO>`.

## Verb 3 — Build the spine

Create the `TaskCreate` progress spine — one task per phase this lane will run (e.g. PLAN-GATE → Walker (if HIGH) → per-task Crafter/Inspector → FINAL). This is the conductor's visible state; it is the fix for "no todo list, wall of text."
**Immediately after the spine exists:** `touch {{RUN_FOLDER}}/.spine`. (The spine guard denies any dispatch before this file exists.)

## Verb 4 — Dispatch

Load `dispatch-contracts.md`. Dispatch the right member with the four-part contract, passing `{{SCENARIO}}` into Crafter/Inspector/Walker dispatches. Sequence by lane (per `lanes.md`):
- **RESEARCH:** Scout → Designer (dialogue loop, below) → SPEC-GATE → Planner → PLAN-GATE → Build loop.
- **DESIGN:** Designer (dialogue loop) → SPEC-GATE → Planner → PLAN-GATE → Build loop. Net-new: propose a
  kebab-slug run-id and confirm it; do NOT offer a Jira ticket (P2.2). Design-doc mid-flow: pass the
  incoming design.md into dispatch #1 for confirm-and-convert.
- **Designer dialogue loop (Approach A):** repeat until the Designer returns `DESIGNER_DONE` — dispatch #N →
  if the done-line is `DESIGNER_NEEDS_INPUT`, render its `## Questions` block via `AskUserQuestion`
  (main thread; ≤4) and re-dispatch with the answers pasted into Part 3; if it is `DESIGNER_DONE`, stop.
  The Designer self-caps at ≤2 question batches (so at most 3 dispatches). This is the ONLY member
  interaction where the conductor calls AskUserQuestion; it relays each batch verbatim and authors no
  design content.
- **EXECUTE:** drift-check → Planner(register existing plan) → Build loop. The drift-check is NOT a member dispatch (there is no drift-check contract) — the conductor runs it inline: read-only Jira read + local file-existence checks per `lanes.md`. Material drift → STOP and recommend re-planning.
- **PLAN:** Planner → PLAN-GATE → (Walker if HIGH blast) → Build loop.
- **Build loop (per task):** write `brief-N.md` (merge the task's entry from the Planner-produced `{{RUN_FOLDER}}/tasklist.md` + prior-task interfaces + `scenario:`), dispatch Crafter, then Inspector (per `gates.md` tier×blast rules). The conductor reads `tasklist.md`; it never calls Compounds itself (the guard denies it).

## Verb 5 — Adjudicate & advance

Read each member's done-line + return artifact. Update the spine (`TaskUpdate`). Evaluate gates mechanically from typed fields (load `gates.md`):
- **SPEC-GATE** (after Designer, DESIGN/RESEARCH lanes): present `spec-draft.md`; per flow-style, pause for
  explicit approval. Write ledger `SPEC-GATE: approved | <ISO>`. Then dispatch the Planner.
  On rejection or a change request: do NOT write `approved` and do NOT dispatch the Planner; re-dispatch
  the Designer with the feedback and re-present at SPEC-GATE.
- **PLAN-GATE:** present `plan.md` (+ `walkthrough.md` if HIGH); per flow-style, pause for explicit approval. Write ledger `PLAN-GATE: approved | <ISO>`.
  On rejection or a change request: do NOT write `approved` and do NOT start the Build loop; re-dispatch
  the Planner with the feedback and re-present at PLAN-GATE.
- **TASK-GATE** (HIGH blast): conductor reads the Inspector verdict — `spec: ✅` AND `quality: approved` → the member finalizes the Compounds task (Inspector feeds `implement_task_finalize` with its verdict evidence on STANDARD; the Crafter marks TRIVIAL tasks done via `update_task`). The conductor's own action is the `TaskUpdate` on the spine — it never calls the Compounds mutation verb inline (the conductor guard denies it). Else fix loop (cap 2) → escalate (revert task commits, HARD STOP, leave sentinels for resume).

**On completion:** run `code-quality-audit` on the diff, invoke `/create-pr`, generate the retro (P3 expands this; P1 writes a terse ledger `COMPLETE:` entry). **Remove the sentinels:** `rm -f {{RUN_FOLDER}}/.active {{RUN_FOLDER}}/.spine`.

## Resume

On re-invoke with `{{RUN_FOLDER}}/.active` present: read `progress.md`, find the first task without a `DONE`, re-create the spine (Verb 3), and continue the Build loop from there.

**Re-stamp ownership first:** `/clear` mints a NEW session id, so a resumed run's sentinel still carries
the *previous* session's id (or is empty/legacy) and the guards would treat this window as non-owning.
Immediately re-stamp with the current session: `printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > {{RUN_FOLDER}}/.active`.
(A lone unowned run is claimable this way by design — the resolver binds a single unowned run so resume
is never orphaned; re-stamping makes ownership explicit and keeps a concurrent second run isolated.)
