---
name: cartograph-report
description: Use when onboarding to an unfamiliar repository, orienting a new contributor or agent, needing repository context before starting work, or asked to draft, refresh, audit, or cartograph a README against actual repository evidence.
---

# Cartograph Report

Runs Cartographer's core pipeline against the repository under analysis:
evidence collection, a claim ledger, a drafted README section or diff,
local validation, accuracy and effectiveness verification, and a run
report — or, only when explicitly authorized, a patch. Slice 1 ships the
core only; no `profiles/contentful/` behavior is in scope here.

## Before anything else — three blocking gates

These are the highest-consequence rules in this file. A run that violates
any of them is not complete, no matter what else it produced.

1. **Report, never patch, unless the caller explicitly authorized a
   patch in this request.** Explicit authorization is a direct instruction
   in the caller's own words to write or apply the change (e.g. "apply
   this," "write the patch," "update the file"). Check: re-read the
   request that started this run. If it contains no such instruction,
   stage 6 produces a report only — do not offer, draft, or write a patch.
2. **Omit an unsupported section and report it as a gap.** A section
   whose every candidate claim resolved to `unresolved-gap`
   (`core/claim-model.md`) never reaches the draft. Check: before adding
   any section to the draft, confirm it has at least one `included` ledger
   row; if it has none, add it to the report's skipped-sections list
   instead and continue.
3. **Never report a patch ready while an `in-patch` `GAP` record — or any
   `GAP` record whose `RULE` is `marker` — exists for it** (RC-9,
   `core/local-validation.md`). Check: the local-validation stage's exit
   code is `0`, or every remaining `GAP` record is tagged `out-of-patch`
   (sixth field of the record), no remaining record's `RULE` is `marker`,
   every `in-patch` record's subject has been removed from the patch
   and carried verbatim into the report's unresolved-gaps list, and the
   candidate contains at least one well-formed `cartographer:managed`
   marker pair. **When the candidate README contains no well-formed
   `cartographer:managed` marker pair, every `GAP` record blocks** —
   with no marked patch region there is no out-of-patch exemption to
   claim. **A `marker` record
   always blocks**: repair the marker line it names when this run
   authored or modified that line, and otherwise report the patch
   blocked — a marker line carried unchanged from the on-disk README sits
   in a section `core/readme-ownership.md` authorizes no write to. A
   patch reported ready in violation of any of this is a contract
   violation, not a formatting issue.

## Step 0 — resume-first check and mode selection (load-bearing, runs before stage 1)

This run's own working artifacts live in `.cartographer/` at the root of
the repository under analysis, created if it does not already exist.
Nothing under this directory is repository-bound (see "Repository-bound
vs. working-only artifacts" below) — never stage it, never commit it.

"Never stage it" must not depend on discipline alone: a later `git add .`
or `git add -A` in the target repository — by anyone, in any session —
would silently stage the claim ledger, evidence record, and validation
report. So, when creating `.cartographer/`, also make git ignore it
locally: if the target repository has a `.git` directory and
`.git/info/exclude` does not already contain a `.cartographer/` line,
append one. `.git/info/exclude` is local-only ignore state — it touches
no tracked file, so this is not a repository-bound write and needs no
patch authorization. Do not edit the target's `.gitignore` for this;
that IS a tracked file, and working-only tooling artifacts are not the
target repository's concern. Every other file this run writes, including
the run state `.cartographer/last-run.md`, lives inside that same
directory and inherits this one exclusion. Do not add a second ignore
step for any of them.

Step 0 reads two state files, and they answer two different questions.
`.cartographer/progress.md` records whether an earlier attempt at this
run was interrupted; it is a `mode:` line followed by a six-line
checklist, one line per stage, each marked `[x]` (complete) or `[ ]`
(incomplete). `.cartographer/last-run.md` is the **run state** a previous
completed run wrote, and it decides whether this run assesses every
section of the README under analysis (**full mode**) or only the sections
whose evidence or body changed since that run (**targeted mode**). Check
for both files, then apply exactly one row of this table:

| `.cartographer/progress.md` | `.cartographer/last-run.md` | Do this |
|---|---|---|
| absent | absent | Create `progress.md` with `mode: full` as its first line and six `[ ]` stage lines beneath it. Run in full mode. |
| absent | present | Select the mode by `core/refresh.md` § Selecting the mode — apply in order, once per run, at Step 0. Create `progress.md` with the resulting `mode:` line first — `mode: full` or `mode: targeted <source-revision>` — and six `[ ]` stage lines beneath it. |
| present | absent | Read the mode from `progress.md`'s `mode:` line; do not re-derive it. `mode: full` → resume the run at the first `[ ]` stage in full mode. `mode: targeted <source-revision>` → the recorded mode is unexecutable, because the fingerprint it would carry forward from is gone, so restart at stage 1 in **full mode** and rewrite the checklist with `mode: full` as its first line and six `[ ]` stage lines beneath it — the same safe-failure move as a checklist carrying no `mode:` line. |
| present | present | Resume the run at the first `[ ]` stage. Read the mode from `progress.md`'s `mode:` line; do not re-derive it. An interrupted run's mode is a fact about that run, not about the current state of `last-run.md`. |

A resumed run may be in targeted mode — that is what recording the mode
buys. Do not treat resumption as full mode, and do not re-run a stage
already marked `[x]`.

The `<source-revision>` written on a `mode: targeted` line is there for
the operator: it makes an interrupted targeted run's fingerprint base
visible without opening the run state. It is **not** consulted on resume
and is compared against nothing — the `mode:` line is authoritative for
which mode a resumed run is in.

Two non-firing branches, stated so they are not improvised, and both
take the same safe-failure move: `progress.md` exists but carries no
`mode:` line — a checklist written before this mechanism existed — or
its checklist is not six stage lines, as a checklist written against an
earlier five-stage pipeline is not. In either case restart at stage 1 in
**full mode** and rewrite the checklist with `mode: full` as its first
line and six `[ ]` stage lines beneath it. An unrecorded mode is not
guessable, a checklist that does not have one line per stage cannot say
which stages are done, and a partially completed targeted run cannot be
finished as a full one.

Mode selection itself: `core/refresh.md`. That file is the sole
definition site for the ordered selection procedure, the run-state
format, per-section selection, and the reporting buckets; it holds the
exact conditions and the exact report strings. Do not restate its content
elsewhere in this run — read it when a branch's exact condition matters.
Three of its outcomes bind Step 0 directly:

- An absent `.cartographer/last-run.md` selects full mode silently. A
  first run in a working tree is not a degraded run; report nothing
  about it.
- A run state that is unparseable, that records a different
  `readme-path` than the README this run analyzes, or that fails one of
  the run-level valves selects full mode, and the report carries exactly
  one of `core/refresh.md`'s eight `targeted mode unavailable: …`
  strings, verbatim — for example
  `targeted mode unavailable: .cartographer/last-run.md is unparseable`.
- Every `body-hash` comparison is computed over the README under
  analysis **as it stands on disk**, never over stage 3's in-memory
  candidate (`core/refresh.md` § The hash is always taken over the README
  on disk). A hash taken over the draft produces a run state that never
  matches.

As each stage completes, mark its line `[x]` in `.cartographer/progress.md`
before moving to the next stage. A stage is not complete until its
artifact is written **and** its checklist line is updated — updating the
checklist is part of finishing the stage, not a separate bookkeeping step.

Concrete check before advancing to stage 1: `.cartographer/progress.md`
exists, its first line reads `mode: full` or
`mode: targeted <source-revision>`, and exactly six stage lines follow it.

## The six-stage pipeline

Full stage contract: `core/pipeline.md`. Summarized here with the working
file each stage writes; do not restate `core/pipeline.md`'s content
elsewhere in this run — read it when a stage's exact failure branch
matters.

| # | Stage | Working file | Concrete check before advancing | Full failure branch |
|---|---|---|---|---|
| 1 | Evidence collection — in targeted mode, only for the sections selected for assessment | `.cartographer/evidence.md` | Confirm every collected fact cites a file and location, and that every claim established by the *absence* of a file set records beside it the exact pathspec evaluated (e.g. `git -C <REPO_ROOT> ls-files -- '.github/workflows/*'`); if any input was unreadable, stop and report before advancing. | `core/pipeline.md` § Stage 1 |
| 2 | Claim ledger | `.cartographer/claim-ledger.md` | Confirm every stage-1 fact has exactly one classified ledger row before drafting begins. | `core/pipeline.md` § Stage 2 |
| 3 | Draft | (held in-memory / conversation until stage 6) | Confirm every drafted sentence cites an `included` row, and every generic-overview-shaped section carries a recorded necessity justification. | `core/pipeline.md` § Stage 3, `core/knowledge/readme-section-necessity.md` |
| 4 | Local validation | `.cartographer/validation-report.md` | Run the checker (below) and record its exit code before advancing. | `core/pipeline.md` § Stage 4, `core/local-validation.md` |
| 5 | Accuracy and effectiveness verification | `.cartographer/verification-report.md` | Confirm the verification report's last three lines are the two `RESULT` lines and the `OVERALL` line — or that this run produced no draft, the one branch on which stage 5 writes no artifact. | `core/pipeline.md` § Stage 5, `core/claim-verification.md`, `core/effectiveness-verification.md` |
| 6 | Report or authorized patch | `.cartographer/report.md`, `.cartographer/last-run.md` | Confirm the report states both the initial and final state of every finding, carries both the `## Accuracy` and the `## Effectiveness` block, and that `.cartographer/last-run.md` was rewritten with a `source-revision` equal to `git -C <REPO_ROOT> rev-parse HEAD`, before closing the run. | `core/pipeline.md` § Stage 6, `core/refresh.md` § The run state is rewritten in whole at stage 6 |

## What targeted mode changes

Per-section selection: `core/refresh.md` § Selecting sections — apply in
order, once per key, in targeted mode only. Name the branch and read that
file; do not restate its rules here.

- **Stages 1 through 3 do not re-run for a carried-forward section** — no
  evidence re-collection, no ledger rows, no redraft. Reuse the ownership
  and freshness recorded in the run state.
- **Stage 4 always runs whole-file, once, on every run in both modes.**
  The checker takes a file, not a section. Attribute its records to
  sections for the report by nearest preceding heading; never filter a
  record out because its section was carried forward.
- **Stage 5's two dispatches are scoped differently**: the accuracy
  dispatch covers the claims this run wrote ledger rows for, and the
  effectiveness dispatch runs whole-file, once, on every run in both
  modes. `core/refresh.md` § The accuracy dispatch covers the claims this
  run wrote ledger rows for holds the rule and its reasoning; name the
  branch and read that file.
- A section present in the README but absent from the fingerprint is
  always assessed. A section recorded in the fingerprint but absent from
  the README lands in no bucket: list it in the report under
  `sections removed since <source-revision>`, and write no run-state row
  for it.
- A section whose absence-based claim had no pathspec recorded at stage 1
  is written to the run state with `watched-paths: unrecorded` and is
  re-assessed on every later run. Stage 1's recording is what makes
  carry-forward possible at all.

Every classified section lands in exactly one report bucket:

| Bucket | The report lists a section here when |
|---|---|
| confirmed current | It was assessed this run, its freshness is `current`, and collected evidence positively supported at least one of its claims. |
| not assessed | Carried forward under `core/refresh.md`'s selection rule 7 — state its `last-assessed-revision` alongside it — **or** assessed this run with freshness `current` where collected evidence neither supported nor contradicted any claim. |
| drifted | Its freshness is `stale` or `obsolete`. Such a section is always freshly assessed, never carried forward. |

Concrete check before reporting: every section this run classified appears
in exactly one of the three buckets, and every carried-forward entry
states its `last-assessed-revision`.

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
- Exit `1` → one or more `GAP` records. Act on them in this order, then
  re-run:

  1. For every `GAP` record whose `RULE` is `marker`: repair the marker
     line at the record's `<FILE>:<LINE>` if this run authored or
     modified that line. If the line is carried unchanged from the
     on-disk README, repair nothing — that section is not this run's to
     write (`core/readme-ownership.md`) — and carry the record verbatim
     into the report's unresolved-gaps list. A `marker` record is never
     resolved by removing its subject.
  2. Remove the subject of every `GAP` record tagged `in-patch` from the
     draft/patch and carry that record verbatim into the report's
     unresolved-gaps list.
  3. Carry every `GAP` record tagged `out-of-patch` into the report as
     an informational finding and remove nothing for it.

  Re-run the checker against the reduced candidate. **Stop re-running
  when no record remains that step 1 or step 2 can act on** — that is,
  when every remaining `GAP` record is either tagged `out-of-patch` or
  is a `marker` record at a line this run did not author. Each pass
  strictly reduces the count of actionable records, so this terminates
  in at most that many passes. Then report the outcome: **ready** when
  the only remaining records are `out-of-patch` `GAP`s and the candidate
  contains at least one well-formed marker pair — the checker still
  exits `1`, and that is a passing state for gate 3, not a failure — and
  **blocked**, not ready, when any `marker` record remains. The same stop
  condition applies to a candidate with no well-formed marker pair, and
  the outcome there is **blocked** whenever any `GAP` record remains at
  stop — with no marked patch region there is no out-of-patch exemption
  to claim (RC-9). (A no-pair candidate whose only records were
  run-authored `marker` lines can still reach exit `0` through repair;
  that is the exit-`0` branch above, not this one.)
- Exit `2` → usage or invocation error. Stop and report the invocation
  failure; this is not a finding about the draft.

## Stage 5 in detail — the two verification dispatches

Runs after stage 4 completed and `.cartographer/validation-report.md`
exists. Stage 5 dispatches two fresh subagents, writes
`.cartographer/verification-report.md`, runs the plugin's second checker
against it, and removes every disproved claim from the candidate. The
dispatch template, the record grammar, the two gate predicates, and both
report blocks' required contents are defined in
`core/claim-verification.md` (RC-29 through RC-32, RC-36) and
`core/effectiveness-verification.md` (RC-33 through RC-35). This section
states what to run and in what order; it restates none of their rules —
read them when a branch's exact condition matters.

**Non-firing branch, checked before anything else: this run produced no
draft.** Dispatch neither subagent, write no
`.cartographer/verification-report.md`, and do not invoke the checker
below. Hold `stage 5 not run: the run produced no draft` for both report
blocks, with both gates NEEDS WORK, for stage 6 to write
(`core/claim-verification.md` RC-32 owns this branch and states it
verbatim). Then mark the stage-5 line `[x]` and advance to stage 6: the
absent artifact is this branch's stated outcome, not an interrupted
stage.

Otherwise run these eight steps in order:

1. **Dispatch the accuracy subagent.** Take RC-30's selection first.
   **If it selects no claim, do not dispatch this subagent.** An empty
   `{{ITEMS}}` returns nothing, and RC-29's detection branch reads a
   returned-nothing dispatch as contaminated — so dispatching an empty
   item set would spend a re-dispatch and then write the contaminated
   shape over a run whose real outcome is that nothing was eligible.
   Write zero accuracy records instead and carry `dispatched=0` into
   step 4: that is the vacuous shape `core/claim-verification.md` RC-32
   owns, and step 7 carries the coverage sentence RC-32 requires with
   it. This branch does not touch step 2 — RC-33's five questions are
   fixed, so the effectiveness dispatch runs on every drafted run.
   Otherwise build the prompt from RC-29's
   template, changing nothing outside its four slots. `{{ARTIFACT_LIST}}`
   is RC-29's two-line accuracy list, verbatim. `{{ITEMS}}` is the claim
   set RC-30 selects, each claim carrying exactly three values — claim
   id, the drafted statement, and that statement's content-class — and no
   other ledger field. `{{OUTPUT_GRAMMAR}}` is RC-31's record line with
   the field values legal for the accuracy gate. `{{VIOLATION_NOTE}}` is
   empty on this first dispatch. Dispatch one fresh Task-tool subagent
   and capture the returned records verbatim.
2. **Dispatch the effectiveness subagent.** The same template, with
   RC-35's inversions: `{{ARTIFACT_LIST}}` is RC-35's single line — the
   drafted candidate alone, with the source denial stated in the line
   itself — and `{{ITEMS}}` is RC-33's five questions, verbatim and in
   order, with no ledger-derived value of any kind. `{{OUTPUT_GRAMMAR}}`
   is RC-35's per-question line; `{{VIOLATION_NOTE}}` is empty. Dispatch
   one fresh Task-tool subagent, separate from step 1's — never the same
   one, and never one prompt carrying both gates — and capture the
   returned records verbatim.
3. **Check each dispatch for contamination.** Apply RC-29's detection
   branch to the returned output of each dispatch this run made, against
   that dispatch's own
   `{{ARTIFACT_LIST}}` and `{{ITEMS}}`. On a hit, discard that output
   entirely — accept no part of it, not even the records that parse — and
   re-dispatch that one gate **once**, with `{{VIOLATION_NOTE}}` carrying
   the sentence naming the detected violation. On a second hit for the
   same gate, do not dispatch it again and accept nothing it returned:
   write that gate's records in RC-29's contaminated shape — one
   `plausible` accuracy record per dispatched claim, or exactly five
   `unanswered` effectiveness records — with the reserved literal
   `isolation not demonstrated` as each record's `EVIDENCE`, exactly as
   RC-29 states them. Contamination on one gate never re-dispatches the
   other.
4. **Write the artifact.** Write `.cartographer/verification-report.md`
   in this order: every accuracy record, then every effectiveness record,
   then RC-31's three summary lines as the file's last three lines.
   Nothing else belongs in this file — no prose, no `[NEEDS VERIFICATION]`
   marker, no corrected-findings list; those live in the report blocks
   (RC-31). The three counts on the `RESULT|accuracy` line each have a
   named source, so none of them is guessed:

   - `dispatched=<n>` is the number of accuracy records in this file.
   - `spot-checked=<n>/<N>` is RC-30's selection: `<n>` is the
     `signature` and `self-citation` claims this run dispatched, `<N>`
     the eligible count they were drawn from.
   - `unverified-other=<m>` is the number of `included` ledger rows whose
     content-class is `other`.
5. **Invoke the checker** against the file just written:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-verification-report.sh" .cartographer/verification-report.md
   ```

   Its stdout is `INVALID|<LINE>|<MESSAGE>` records and a closing
   `SUMMARY|invalid=<n>` line (RC-36). Read it; never write it into
   `.cartographer/verification-report.md`, whose only content is records
   and the three summary lines.

   - Exit `0` → the file is a legal emission. Proceed to step 6. A legal
     file whose `OVERALL` is NEEDS WORK also exits `0`: the gate result
     and the artifact's validity are two different questions, and a
     NEEDS WORK result is never a reason to rewrite the file.
   - Exit `1` → the file this run just wrote is malformed. That is this
     run's own defect, not a finding about the draft and not a finding
     about the repository under analysis. Rewrite the file to conform to
     RC-31 — each `INVALID` record names the line and the violation — and
     re-invoke the checker **once**. If exit `1` persists, stop
     rewriting: hold the second invocation's `INVALID` records verbatim
     as stage-6 input, record that stage 5 failed, set both gates to
     NEEDS WORK, and continue to stage 6 — which is where they reach
     `.cartographer/report.md`. Never invoke a third time, and never
     change a verdict to make the checker quiet.
   - Exit `2` → usage or invocation error. Stop and report the invocation
     failure; this is not a finding about the draft — the same
     disposition stage 4's exit `2` branch uses.
6. **Remove every disproved claim, and re-enter stage 4 at most once.**
   For every accuracy record whose verdict is `disproved`, remove that
   claim's drafted sentence or sentences from the candidate. Then take
   exactly one of these two branches:

   - No sentence was removed → continue to step 7. Do not re-enter stage
     4.
   - At least one sentence was removed → re-enter § Stage 4 in detail —
     invoking the checker **once**, unchanged, against the reduced
     candidate. RC-9 governs that run in full, including its own re-run
     loop and its own stop condition; do not shorten it and do not read
     its outcome as a stage-5 result. Rewrite
     `.cartographer/validation-report.md` from that re-entry, then
     continue to step 7. If the re-entry's RC-9 outcome is blocked,
     report the patch blocked and continue — blocked describes the
     patch's readiness, never the run's completion.

   **Do not re-dispatch either subagent after a removal, and do not
   re-enter stage 4 a second time.** Steps 1 and 2 dispatch once per run,
   so no second set of verdicts exists and no second removal round can
   arise (`core/claim-verification.md` RC-32, step 4). The records stay
   as written: a removed claim keeps its `disproved` record, and that
   record is what step 7's corrected-findings entry is built from. Do not
   rewrite `.cartographer/verification-report.md` to reflect the removal.
7. **Derive the two report blocks from the records.** Deriving them is
   this stage's work; writing them is not. **Stage 5 writes no part of
   `.cartographer/report.md`, on any branch above** — it derives this
   content and holds it, and stage 6 writes the file. What each block
   must carry is fixed where its gate is defined —
   `core/claim-verification.md` RC-32 for `## Accuracy`,
   `core/effectiveness-verification.md` RC-35 for `## Effectiveness` —
   and `core/pipeline.md` states that the two sit as co-equal sibling
   sections. Four mappings are mechanical; apply each one exactly:

   - an accuracy record whose verdict is `plausible` → one
     `[NEEDS VERIFICATION] <claim id>` entry in `## Accuracy`;
   - an accuracy record whose verdict is `disproved` → one
     corrected-findings entry in `## Accuracy`, naming the claim id and
     the drafted sentence step 6 removed;
   - an effectiveness record whose verdict is `unanswered` → one entry in
     `## Effectiveness` carrying that question's RC-33 text verbatim,
     never a paraphrase and never the bare `q<i>` subject;
   - the reserved literal `isolation not demonstrated` in any record's
     `EVIDENCE` → carried verbatim into that record's own gate's block as
     that gate's stated reason.

   Every other required item of either block — each gate's result, the
   patch-readiness before and after a removal, and `## Accuracy`'s two
   verbatim coverage sentences and its `dispatched=0` sentence — is
   listed where the block is defined. Read RC-32 and RC-35 and carry
   their items across; do not reconstruct either list from memory.
8. **Mark the checklist.** Mark stage 5's line `[x]` in
   `.cartographer/progress.md` before advancing to stage 6 — on every
   branch above, including the no-draft branch. That branch is a
   completed stage with a stated outcome, not an interrupted one, so it
   does not compete with Step 0's rule that a stage is not complete until
   its artifact is written **and** its checklist line is updated: where
   the artifact's absence is the stage's stated outcome, the checklist
   line is what records that the stage ran.

Concrete check before advancing to stage 6:
`.cartographer/verification-report.md` exists and
`check-verification-report.sh` exited `0` against it — or this run
produced no draft and both report blocks say so — and stage 4 was
re-entered at most once.

## Stage 6 in detail — writing the run state

Every run ends by rewriting `.cartographer/last-run.md` in whole; it is
never partially updated, and it is written on every run in both modes.
The run is not complete until it exists. Format, header fields, and row
fields: `core/refresh.md` § The run state is rewritten in whole at
stage 6.

- `source-revision` is the output of `git -C <REPO_ROOT> rev-parse HEAD`
  at stage 6. `readme-path` is the README under analysis, relative to
  `REPO_ROOT`.
- Write one row per section this run classified. A freshly assessed
  section's `last-assessed-revision` is this run's `source-revision`; a
  carried-forward section keeps its earlier `last-assessed-revision` and
  gets a freshly computed `body-hash`.
- Compute every `body-hash` over the README as it stands on disk at that
  moment — the unmodified file on a report-only run, the post-patch file
  on an authorized-patch run that applied one. Never hash stage 3's
  in-memory candidate.
- The run state is working-only. It is never staged, never committed, and
  never enters a patch — as a new file, as an edit, or as content pasted
  into the README. It needs no ignore step of its own: it lives inside
  `.cartographer/`, which Step 0 already added to `.git/info/exclude`.
- A `.cartographer/last-run.md` that reaches a commit permanently
  disables targeted mode: every later run sees the committed file as a
  changed path that no recorded section covers, and falls back to full
  mode forever. This is the concrete harm behind "never commit it."

Concrete check before closing the run: `.cartographer/last-run.md`
exists, its `source-revision` equals the current output of
`git -C <REPO_ROOT> rev-parse HEAD`, and its fingerprint table holds one
row per section this run classified.

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
| `.cartographer/verification-report.md` | working-only | This run's working directory |
| `.cartographer/report.md` | working-only | This run's working directory |
| `.cartographer/last-run.md` | working-only | This run's working directory |

Exactly one artifact class is repository-bound: the README patch itself.
Every file under `.cartographer/` is working-only and never
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

This run completes all six stages using repository-local evidence only,
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

## Interactive-only — an honest constraint on this file

This skill requires an interactive session. It does not support headless
(`claude -p`) invocation in Slice 2 — the dogfood failures that shaped
this constraint were harness permission denials plugin code cannot fix.
Do not invoke this skill from a headless `claude -p` run expecting a
completed report; the run will hit a permission boundary this file has
no way to route around.

## Verification check — before reporting this run complete

Confirm every one of these, and report the first that fails instead of
the report:

1. `.cartographer/progress.md` records this run's mode on its first line
   and shows all six stages `[x]`, or the run stopped at a named stage
   and reported why.
2. Every drafted sentence in stage 3's output traces to an `included`
   ledger row in `.cartographer/claim-ledger.md`; every `unresolved-gap`
   row appears in `.cartographer/report.md`'s unresolved-gaps list and
   nowhere in the draft.
3. The local-validation checker's exit code is recorded in
   `.cartographer/validation-report.md`, and if it was `1`, every
   `in-patch` `GAP` subject is absent from the draft/patch and present in
   the report, every `out-of-patch` `GAP` record is present in the
   report, every `marker` record is either repaired or reported with the
   patch marked blocked, and — when the candidate carries no well-formed
   marker pair — either no `GAP` record remains or every remaining `GAP`
   record is reported with the patch marked blocked.
4. `.cartographer/verification-report.md` exists and
   `check-verification-report.sh` exited `0` against it — or the run
   produced no draft and both report blocks state
   `stage 5 not run: the run produced no draft`. Every `disproved`
   claim's sentence is absent from the draft/patch and present in the
   report's corrected findings; every `plausible` claim carries a
   `[NEEDS VERIFICATION]` marker; every `unanswered` question is listed
   verbatim; and stage 4 was re-entered at most once.
5. If a patch was produced, it was explicitly authorized (gate 1 above),
   and it contains only repository-bound content (the artifact-split table
   above).
6. `.cartographer/report.md` states the initial state and the final state
   of every finding — a report showing only the end state is not
   complete.
7. `.cartographer/last-run.md` exists, its `source-revision` equals
   `git -C <REPO_ROOT> rev-parse HEAD`, and it carries one row per
   section this run classified — or the run stopped at a named stage and
   reported why.
8. A run that selected its mode **this run** — the `absent | present`
   cell of Step 0's table, the only cell that runs `core/refresh.md`'s
   selection procedure — and landed in full mode for any reason other
   than an absent `.cartographer/last-run.md` reported exactly one of
   `core/refresh.md`'s eight `targeted mode unavailable: …` strings,
   verbatim. This item does not apply to a run that resumed from an
   existing `progress.md`: such a run read its mode from the `mode:`
   line and selected no mode this run, so it has no selection reason to
   report. Neither does it apply to a restart forced into full mode by a
   missing `mode:` line or by an unexecutable recorded `mode: targeted`
   — those are Step 0 branches, not selection outcomes. Do not fabricate
   a string for any of them, and do not treat the missing string as a
   failure.
9. Every section this run classified appears in exactly one of the three
   report buckets — confirmed current, not assessed, drifted — and every
   carried-forward entry states its `last-assessed-revision`.
