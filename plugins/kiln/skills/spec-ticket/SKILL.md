---
name: spec-ticket
description: Use when asked to render an ALREADY-AGREED spec into a Jira ticket's team-format description with EARS acceptance criteria, or to reconcile a ticket's subtasks against a plan. This is a spec-to-ticket WRITE mechanism, not general ticket CRUD (that is the jira skill) and not requirements authoring (that is design/brainstorming). Trigger phrases include "render this spec into the ticket", "write the ticket's acceptance criteria in EARS", "sync the ticket's subtasks to the plan", "turn this approved design into a ticket". Always shows a diff before writing; requires an agreed spec first.
argument-hint: <TICKET-KEY | --new --from <design.md> --project <KEY>> [--subtasks-from <plan.md>]
---

# spec-ticket — render an agreed spec into a Jira ticket

Renders an agreed spec into the embedding team's ticket format with EARS acceptance criteria, then
writes it to Jira after showing you a diff. This skill is a thin router; the Drafter agent does the work.

## Entry detection
- `TICKET-KEY` alone → **flesh existing** (`update` target).
- `--new --from <design.md> --project <KEY>` → **create from design artifact** (`create` target).
- `TICKET-KEY --subtasks-from <plan.md>` → **subtask-focused** (`update` target; the description is
  still reconciled and shown in the diff — the human approves just the subtasks or cancels, per the
  usual gate).

## Step 0 — Guarantee an agreed spec (the mini-conductor part)
The Drafter is a pure write mechanism — it requires an AGREED spec, and its `{{SPEC_SOURCE}}` input
MUST be a path to a readable file. Determine the spec source:
- If `--from <path>` was given, that is the spec — pass the path as-is.
- Else read the ticket via Jira-read. If it already carries an adequate spec (substantive AC /
  linked design), WRITE that ticket content to a temp file first (e.g. `mktemp`), then pass that
  file's path as `{{SPEC_SOURCE}}` — never pass inline content directly, the Drafter cannot accept it.
- Else (thin/blank): the ticket is NOT ready. Invoke `superpowers:brainstorming` to produce an agreed
  spec FIRST, then continue. Announce: "This ticket has no agreed spec yet — let's design it first,
  then I'll draft the ticket."

## Step 1 — Dispatch the Drafter (Phase 1 — render)
The Drafter runs in two phases; you hold the human-ask between them. Dispatch the `drafter` agent
(Agent tool, `subagent_type: drafter`) with NO approval signal, so it runs Phase 1 (render only):
`{{SPEC_SOURCE}}`, `{{TARGET}}`, `{{SUBTASKS}}`, `{{LEDGER}}` = `none` (standalone),
`{{FORMAT_CACHE}}` = `none` (no persistent standalone cache in v1 — the Drafter infers or defaults the
skeleton each time). Do NOT pass `APPROVAL`/`APPROVED_BUNDLE` here.
Since `{{FORMAT_CACHE}}` is always `none` in v1, every dispatch is a cache miss: search for 3–5
recent ticket keys in the target project (Jira-read) and pass them as `{{SIBLING_KEYS}}` (or `none`
if the search turns up nothing usable) — the agent holds only `getJiraIssue`, no search.
Before dispatching a `create`/`update` that touches subtasks, fetch the ticket's current children
yourself (Jira-read) and pass them as `{{CHILDREN}}` — the agent holds only `getJiraIssue`, no search.

## Step 2 — Present the diff and confirm (R1)
Phase 1 ends with one of three outcomes:
- `DRAFTER_AWAITING_APPROVAL: <bundle-dir>` (nothing is written yet) — read `<bundle-dir>/diff.md` and
  present it to the user via `AskUserQuestion` with three options: **approve**, **request changes**,
  **cancel**. Branch per the answer in Step 3.
- `DRAFTER_NOOP` — there is nothing to approve; skip to Step 4.
- `DRAFTER_BLOCKED: <reason>` — surface the reason to the user and stop. Nothing to approve, nothing
  written; do not proceed to Step 3.

## Step 3 — Branch on the human's answer
- **approve** → proceed to Phase 2: RE-INVOKE the `drafter` agent with the SAME inputs PLUS the
  approval signal: `APPROVAL=granted` and `APPROVED_BUNDLE=<the exact bundle-dir path from the
  Phase-1 done-line>`. Pass the same `{{TARGET}}` — the agent guards that `<bundle>/target.txt`
  matches it and blocks on mismatch. If you rendered more than one Phase-1 bundle (see "request
  changes" below), re-invoke with the LATEST bundle path.
- **request changes** → capture the change note from the user, then go BACK to Step 1 and re-dispatch
  Phase 1 with the adjusted spec/inputs to render a NEW bundle. Re-present the new bundle's `diff.md`
  at Step 2. Do NOT re-invoke with approval — nothing is written to Jira on this path.
- **cancel** → stop. Write nothing to Jira, nothing to the ledger.
Nothing is written to Jira without an explicit approve, under every circumstance.

## Step 4 — Report
Relay the Drafter's `DRAFTER_DONE` / `DRAFTER_NOOP` / `DRAFTER_BLOCKED` outcome. On a standalone run
there is no ledger, so subtasks are create-missing-only (existing subtasks are never edited).

## Notes
- Never write "Kiln"/"Drafter"/tooling names into ticket content (neutral wording only).
- No-op is a valid, common outcome — an already-adequate ticket needs no write.
