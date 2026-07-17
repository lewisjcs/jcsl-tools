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
- `TICKET-KEY --subtasks-from <plan.md>` → **subtasks only** (`update` target, description skipped).

## Step 0 — Guarantee an agreed spec (the mini-conductor part)
The Drafter is a pure write mechanism — it requires an AGREED spec. Determine the spec source:
- If `--from <path>` was given, that is the spec.
- Else read the ticket via Jira-read. If it already carries an adequate spec (substantive AC /
  linked design), use it as the spec source.
- Else (thin/blank): the ticket is NOT ready. Invoke `superpowers:brainstorming` (or, if inside a
  Kiln run, this is the Designer's job) to produce an agreed spec FIRST, then continue. Announce:
  "This ticket has no agreed spec yet — let's design it first, then I'll draft the ticket."

## Step 1 — Dispatch the Drafter (Phase 1 — render)
The Drafter runs in two phases; you hold the human-ask between them. Dispatch the `drafter` agent
(Agent tool, `subagent_type: drafter`) with NO approval signal, so it runs Phase 1 (render only):
`{{SPEC_SOURCE}}`, `{{TARGET}}`, `{{SUBTASKS}}`, `{{LEDGER}}` = `none` (standalone),
`{{FORMAT_CACHE}}` = the local per-project cache path. Do NOT pass `APPROVAL`/`APPROVED_BUNDLE` here.
Before dispatching a `create`/`update` that touches subtasks, fetch the ticket's current children
yourself (Jira-read) and pass them as `{{CHILDREN}}` — the agent holds only `getJiraIssue`, no search.

## Step 2 — Present the diff and confirm (R1)
Phase 1 ends with `DRAFTER_AWAITING_APPROVAL: <bundle-dir>` (nothing is written yet). Read
`<bundle-dir>/diff.md` and present it to the user via `AskUserQuestion` (approve / cancel). On
`DRAFTER_NOOP` there is nothing to approve — skip to Step 3.

## Step 3 — Commit on approval (Phase 2) or stop
Only on explicit human approval, RE-INVOKE the `drafter` agent (Phase 2) with the SAME inputs PLUS the
approval signal: `APPROVAL=granted` and `APPROVED_BUNDLE=<the exact bundle-dir path from the Phase-1
done-line>`. Pass the same `{{TARGET}}` — the agent guards that `<bundle>/target.txt` matches it and
blocks on mismatch. If the user cancels or edits, do NOT re-invoke with approval; nothing is written to
Jira without approval, under every circumstance. If you rendered a second Phase-1 bundle, re-invoke
with the LATEST bundle path.

## Step 4 — Report
Relay the Drafter's `DRAFTER_DONE` / `DRAFTER_NOOP` / `DRAFTER_BLOCKED` outcome. On a standalone run
there is no ledger, so subtasks are create-missing-only (existing subtasks are never edited).

## Notes
- Never write "Kiln"/"Drafter"/tooling names into ticket content (neutral wording only).
- No-op is a valid, common outcome — an already-adequate ticket needs no write.
