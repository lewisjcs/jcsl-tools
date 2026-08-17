---
name: cartograph-report
description: Use when onboarding to an unfamiliar repository, orienting a new contributor or agent, needing repository context before starting work, or asked to draft, refresh, audit, or cartograph a README against actual repository evidence.
---

# Cartograph Report

Runs Cartographer's core pipeline against the repository under analysis:
evidence collection, a claim ledger, a drafted README section or diff,
local validation, and a run report — or, only when explicitly authorized,
a patch. Slice 1 ships the core only; no `profiles/contentful/` behavior
is in scope here.

## Before anything else — three blocking gates

These are the highest-consequence rules in this file. A run that violates
any of them is not complete, no matter what else it produced.

1. **Report, never patch, unless the caller explicitly authorized a
   patch in this request.** Explicit authorization is a direct instruction
   in the caller's own words to write or apply the change (e.g. "apply
   this," "write the patch," "update the file"). Check: re-read the
   request that started this run. If it contains no such instruction,
   stage 5 produces a report only — do not offer, draft, or write a patch.
2. **Omit an unsupported section and report it as a gap.** A section
   whose every candidate claim resolved to `unresolved-gap`
   (`core/claim-model.md`) never reaches the draft. Check: before adding
   any section to the draft, confirm it has at least one `included` ledger
   row; if it has none, add it to the report's skipped-sections list
   instead and continue.
3. **Never report a patch ready while a `GAP` record exists for it**
   (RC-9, `core/local-validation.md`). Check: the local-validation stage's
   exit code is `0`, or every `GAP` record's subject has been removed from
   the patch and carried verbatim into the report's unresolved-gaps list.
   A patch reported ready with an outstanding `GAP` record is a contract
   violation, not a formatting issue.

## Step 0 — resume-first check (load-bearing, runs before stage 1)

This run's own working artifacts live in `.cartographer/` at the root of
the repository under analysis, created if it does not already exist.
Nothing under this directory is repository-bound (see "Repository-bound
vs. working-only artifacts" below) — never stage it, never commit it.

Before starting stage 1, check whether `.cartographer/progress.md`
already exists.

- **If it exists:** read it. It is a five-line checklist, one line per
  stage, each marked `[x]` (complete) or `[ ]` (incomplete). Resume the
  run at the first `[ ]` stage; do not re-run a stage already marked
  `[x]`, and do not restart from stage 1.
- **If it does not exist:** create it with all five stages marked `[ ]`,
  then proceed to stage 1.

As each stage completes, mark its line `[x]` in `.cartographer/progress.md`
before moving to the next stage. A stage is not complete until its
artifact is written **and** its checklist line is updated — updating the
checklist is part of finishing the stage, not a separate bookkeeping step.

## The five-stage pipeline

Full stage contract: `core/pipeline.md`. Summarized here with the working
file each stage writes; do not restate `core/pipeline.md`'s content
elsewhere in this run — read it when a stage's exact failure branch
matters.

| # | Stage | Working file | Concrete check before advancing |
|---|---|---|---|
| 1 | Evidence collection | `.cartographer/evidence.md` | Every collected fact records the file and location it was read from. If the repository could not be read, stop here and report the read failure — do not advance with a partial record that does not say which inputs were unreadable. |
| 2 | Claim ledger | `.cartographer/claim-ledger.md` | Every claim from stage 1 has exactly one row, classified by `core/claim-model.md`'s ordered procedure. A claim with no evidence reference is `unresolved-gap` here, not later. |
| 3 | Draft | (held in-memory / conversation until stage 5) | Every drafted sentence traces to an `included` ledger row. A generic-overview-shaped section (`repository at a glance`, `architecture overview`) is included only with a recorded necessity justification — `core/knowledge/readme-section-necessity.md` states the litmus test. With no justification, omit the section and log it as skipped. |
| 4 | Local validation | `.cartographer/validation-report.md` | Run the checker (below) and confirm its exit code. `LOW_VALUE` findings are advisory; `GAP` findings are not. |
| 5 | Report or authorized patch | `.cartographer/report.md` | The report states the initial state and the final state of every finding — never the end state alone. If a patch is authorized, it contains only repository-bound content (below). |

## Stage 4 in detail — invoking the checker

Run the plugin's own checker against the drafted README candidate:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-readme-patch.sh" <candidate_README> <REPO_ROOT>
```

Capture its stdout verbatim into `.cartographer/validation-report.md`.
Per RC-9, the checker is read-only: it reports `GAP`/`LOW_VALUE`/`OK`
records and an exit code, and never rewrites the candidate or excludes
anything itself. Excluding is this skill's job, not the checker's:

- Exit `0` → no `GAP` records. Proceed; carry any `LOW_VALUE` records into
  the report as advisory findings.
- Exit `1` → one or more `GAP` records. Remove each `GAP` record's subject
  from the draft/patch, and carry that record verbatim into the report's
  unresolved-gaps list. Re-run the checker against the reduced candidate
  before reporting the patch ready.
- Exit `2` → usage or invocation error. Stop and report the invocation
  failure; this is not a finding about the draft.

## Repository-bound vs. working-only artifacts

Uses `core/pipeline.md`'s own terms. A patch may contain repository-bound
content only:

| Artifact | Class | Lives at |
|---|---|---|
| The README patch/diff | repository-bound | The target repository's own README, at the location the patch touches |
| `.cartographer/progress.md` | working-only | This run's working directory |
| `.cartographer/evidence.md` | working-only | This run's working directory |
| `.cartographer/claim-ledger.md` | working-only | This run's working directory |
| `.cartographer/validation-report.md` | working-only | This run's working directory |
| `.cartographer/report.md` | working-only | This run's working directory |

In Slice 1 there is exactly one repository-bound artifact: the README
patch itself. Every file under `.cartographer/` is working-only and never
enters a patch — as a new file, as an edit, or as content pasted into the
README. A patch that would include any of them is not reported ready;
remove the artifact from the patch and report the violation instead of
shipping the patch with a note about the extra file.

## Ownership — which README sections this run may write

Full classification: `core/readme-ownership.md`. The core writes only
sections classified `cartographer-managed` (enclosed by a matching
`cartographer:managed:start`/`:end` marker pair). Every other ownership
value — `human-authored`, `other-tool-generated`, `unknown` — is preserved
or proposed, never edited in place.

## Core/profile scope (Slice 1)

This run completes all five stages using repository-local evidence only,
for a repository with no `profiles/contentful/` integration configured.
It declares no dependency on Glean, Backstage, a `catalog-info.yaml`, or a
repository visibility policy. A repository with none of them is an
ordinary subject for this run, not a degraded one. Confirm this run's own
`core/` files still honor that boundary:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-core-profile-boundary.sh"
```

Exit `0` required. This checks the plugin's own `core/` files, not the
repository under analysis.

## Evaluation-first — an honest constraint on this file

This skill's effectiveness is **unproven pending Slice 3**. Slice 1 ships
no evaluation harness — no baseline-without-the-skill comparison exists
yet for README drafting or onboarding-context quality. Do not present a
run of this skill as evidence that it improves outcomes; that claim is
Slice 3's to make, with a baseline behind it, not this file's to assert.

## Verification check — before reporting this run complete

Confirm every one of these, and report the first that fails instead of
the report:

1. `.cartographer/progress.md` shows all five stages `[x]`, or the run
   stopped at a named stage and reported why.
2. Every drafted sentence in stage 3's output traces to an `included`
   ledger row in `.cartographer/claim-ledger.md`; every `unresolved-gap`
   row appears in `.cartographer/report.md`'s unresolved-gaps list and
   nowhere in the draft.
3. The local-validation checker's exit code is recorded in
   `.cartographer/validation-report.md`, and if it was `1`, every `GAP`
   subject is absent from the draft/patch and present in the report.
4. If a patch was produced, it was explicitly authorized (gate 1 above),
   and it contains only repository-bound content (the artifact-split table
   above).
5. `.cartographer/report.md` states the initial state and the final state
   of every finding — a report showing only the end state is not
   complete.
