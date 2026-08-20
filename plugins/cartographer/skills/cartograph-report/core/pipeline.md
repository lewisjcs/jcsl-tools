# Core Pipeline (Slice 1)

TL;DR: six stages, in order, each handing the next a written artifact —
evidence collection, claim ledger, draft, local validation, accuracy and
effectiveness verification, then report or explicitly authorized patch.
A stage that cannot produce its artifact stops the run at that stage and
reports; it never hands the next stage a guess.

This file uses the evidence classes and the `unresolved-gap` disposition
defined in `core/claim-model.md`, and the ownership and freshness values
defined in `core/readme-ownership.md`. It defines neither set.

## The stage sequence

| # | Stage | Input | Artifact it produces |
|---|---|---|---|
| 1 | evidence collection | The repository under analysis | The evidence record: located facts, each addressable by path and location |
| 2 | claim ledger | The evidence record | One ledger row per claim, classified and dispositioned |
| 3 | draft | The ledger's `included` rows | Drafted sections, each traceable to ledger rows |
| 4 | local validation | The draft | The validation report: findings against the draft |
| 5 | accuracy and effectiveness verification | The draft, the claim ledger, and the validation report | The verification report: one verdict record per verified claim and per newcomer question |
| 6 | report or authorized patch | The draft, the validation report, and the verification report | The run report, and — only on explicit caller authorization — a patch |

The order is the contract. Stage N reads only artifacts stages 1 through
N-1 wrote; no stage reaches back into the conversation that started the
run, and no stage re-derives an artifact an earlier stage already wrote.

The one exception, named here so it is never read as a violation of the
rule above: **stage 5 may send the caller back through stage 4 exactly
once per run**, against a candidate stage 5 reduced, and that re-entry
rewrites stage 4's artifact. Nothing else re-enters an earlier stage,
and no stage other than 5 may trigger a re-entry at all. The re-entry
is bounded at one by construction rather than by a counter a reader has
to trust: stage 5 dispatches once per run and produces no second set of
verdicts, so no second exclusion round can arise. The sequence itself is
owned by `core/claim-verification.md` RC-32; this file names the
exception so the ordering rule and that sequence are read as one
decision rather than as two rules in conflict.

## Stage 1 — evidence collection

Collect from the repository under analysis only: tracked files, its
manifests, its CI configuration, and its history. Every collected fact is
recorded with the location it was read from, because a fact whose
location was not recorded cannot become a claim reference in stage 2.
When a claim is established by the absence of a file set, stage 1 records
the pathspec it evaluated, because a pathspec that was not recorded
cannot become a watched path in the run state.

In targeted mode, stage 1 runs only for the sections
`core/refresh.md`'s per-section procedure selects for assessment; a
carried-forward section's evidence is reused from the run state rather
than re-collected. `core/refresh.md` is the sole definition site for mode
selection and for the run-state format this stage's recording feeds.

Failure branch: if the repository cannot be read, the run stops at stage
1 and reports the read failure. It does not proceed with a partial
evidence record silently — a partial record is legitimate only when the
run records which inputs were unreadable.

## Stage 2 — claim ledger

Every claim the run might draft gets a ledger row, classified by
`core/claim-model.md`'s ordered procedure. Claims with no evidence
reference take the `unresolved-gap` disposition here, not later: the
draft stage never sees them.

Failure branch: if every candidate claim for a section resolves to
`unresolved-gap`, the section has no drafted content and is reported as a
gap. The pipeline does not fall back to generic prose to fill the space.

## Stage 3 — draft

Draft only from ledger rows whose disposition is `included`. Each drafted
sentence traces to at least one row.

**The necessity rule for generic-overview-shaped sections.** Among the
sections the core may draft, *repository at a glance* and *architecture
overview* are generic-overview-shaped: they are conventional, they are
costly to carry, and they do not reliably help a reader who has the
repository in front of them. *Quick start*, *known constraints*, and
*agent routing* are concrete and are not subject to this rule. <!-- see: references/readme-scope.md#concrete-instructions-succeed-generic-overviews-do-not -->

A generic-overview-shaped section requires a recorded, evidence-based
necessity justification — a named thing the reader could not learn any
other way — attached before the section enters the draft. With no such
record, the section is omitted from the draft and reported as a skipped
low-priority section. It is never included on the strength of its
conventional name. <!-- see: references/readme-scope.md#repository-context-files-null-result-on-task-success-positive-cost -->

Non-firing branch: sections outside the generic-overview-shaped set need
no necessity record. They are governed by the ordinary claim rules, and
requiring a justification of them would be a rule this file does not make.

Failure branch: a draft containing a generic-overview-shaped section with
no recorded justification is not reported ready. The core removes the
section, adds it to the skipped-sections list, and continues.

## Stage 4 — local validation

Validation is local: it reads the draft and the repository under
analysis, and no external service. It never rewrites the draft — it
produces findings, and the caller acts on them.

The concrete link, command, and low-value rules, their record format, and
their exit codes are defined in `core/local-validation.md`, which ships in
this slice. This file fixes only the stage's position and its
hand-off: stage 5 receives the draft together with the findings, never
the draft alone.

Failure branch: a finding that the draft cannot satisfy removes the
offending item from the draft and carries the finding into the report. A
draft is never reported ready with an unaddressed finding against it.

## Stage 5 — accuracy and effectiveness verification

Two gates run against the draft this stage receives, independently of
each other: **Accuracy**, which tests whether what the draft claims
about the repository is true, and **Effectiveness**, which tests whether
the draft answers the questions a newcomer arrives with. Their verdicts
are written to `.cartographer/verification-report.md`, a working-only
artifact named to match stage 4's
`.cartographer/validation-report.md`.

The concrete dispatch contract, the verdict record grammar, and the two
gate predicates are defined in `core/claim-verification.md` (Accuracy)
and `core/effectiveness-verification.md` (Effectiveness), which ship in
this slice. This file fixes only the stage's position, its artifact, its
hand-off, and the one branch on which its artifact is deliberately
absent: stage 6 receives the draft, the findings, and the verdicts, and
reports each gate's result in its own block.

This stage does not decide patch readiness. Which findings block a patch
is `core/local-validation.md`'s RC-9 rule on stage 4's artifact, and
neither gate here weakens, overrides, or re-decides it. What stage 5 may
do is send the caller back through stage 4 once, against a candidate it
reduced — the bounded re-entry § The stage sequence names, whose
sequence `core/claim-verification.md` RC-32 owns.

Non-firing branch: a run that produced no draft has nothing to verify,
and stage 5 writes no `.cartographer/verification-report.md` for it.
`core/claim-verification.md` RC-32 owns that branch and states it in
full — what stage 5 dispatches, what both report blocks say, both gates'
results, and the checklist line. This file states only the half the
ordering rule above needs: the absent artifact is that branch's stated
outcome, not a missing artifact under the Verification check's item 1.

Failure branch: a gate that cannot demonstrate its result reports NEEDS
WORK, states its reason in its own block, and the run proceeds to stage
6. A result the stage could not demonstrate is never recorded as a
passing one.

## Stage 6 — report or authorized patch

Every run produces a report. A run produces a patch only when the caller
explicitly authorizes one, and only for the sections
`core/readme-ownership.md`'s matrix permits writing.

### The report states the initial state and the final state

The report names what the run found when it started and what the state of
each finding is when the run ends. A finding the run resolved appears in
the report as found-then-resolved, with both states visible. A run that
found problems and fixed them does not report a bare pass.

Consequence and failure branch: a report that shows only the end state is
a contract violation, and the run is not complete until the report shows
both. If the initial state was not recorded before remediation, the run
reports that the before-state is unavailable rather than presenting the
after-state as if nothing had failed.

### The report carries two co-equal verification blocks

A **report block** is a named section of `.cartographer/report.md`.
There are exactly two, `## Accuracy` and `## Effectiveness`, and they sit
in the report as sibling sections in that order. Neither is nested inside
the other, and neither sits beneath a combined verification heading that
carries a result of its own.

**Co-equal is operational, not a matter of tone.** Neither block is
derived from the other, neither is presented as a summary or a
sub-finding of the other, and neither may be omitted on a run where the
other reports `PASS`. One headline result with the second gate reduced
to a sub-bullet does not satisfy this contract.

Every verification result is attributed to exactly one block: the one
whose gate produced it. The mechanical half of that property is the
disjoint per-gate verdict vocabulary `core/claim-verification.md` RC-31
fixes — no verdict value is shared between the gates, so which block a
result belongs in is decided by the record, never by judgment.

The two blocks' required contents, and the predicate deciding whether
each gate reports `PASS` at all, are owned where their gates are
defined — `core/claim-verification.md` RC-32 for `## Accuracy` and
`core/effectiveness-verification.md` RC-35 for `## Effectiveness`. This
file composes the two results; it states neither predicate and neither
block's contents.

**The overall result.** The run's overall result is `PASS` only when
both blocks report `PASS`. While either reports NEEDS WORK, overall
`PASS` is false: there is no partial credit, no averaging of the two
gates, and no gate whose result the other can compensate for. This
predicate inherits the initial-and-final-state rule above rather than
competing with it — a run that found problems and fixed them does not
report a bare overall pass, and a run that excluded a claim states patch
readiness before and after the exclusion.

Overall `PASS` is a statement about the two gates, not about the patch.
Whether a patch is ready is decided by `core/local-validation.md`'s RC-9
on stage 4's artifact; this section neither restates that decision nor
overrides it.

### Repository-bound and working-only artifacts

| Artifact | Class |
|---|---|
| The README patch | repository-bound |
| The evidence record from stage 1 | working-only |
| The claim ledger from stage 2 | working-only |
| The validation report from stage 4 | working-only |
| The verification report from stage 5 (`.cartographer/verification-report.md`) | working-only |
| The run report from stage 6 | working-only |
| The run state from stage 6 (`.cartographer/last-run.md`) | working-only |
| Any scratch, intermediate, or log file the run writes | working-only |

Repository-bound artifacts are the only content a patch may contain.
Exactly one artifact class is repository-bound: the README patch itself.

The run state is working-only: it lives under `.cartographer/`, a
directory added to the target repository's `.git/info/exclude` rather
than to its tracked `.gitignore`, so it stays local-only ignore state
and is never committed to the repository.

Working-only artifacts never enter a patch. They are the run's own
records; a reader of the repository never receives them, and a reviewer
of the patch never has to sort them out of it.

Consequence and failure branch: a patch containing any working-only
artifact — as a new file, as an edit, or as content pasted into the
README — is not reported ready. The core removes the artifact from the
patch and reports the violation; it does not ship the patch and mention
the extra file in passing.

## Core/profile independence

The core completes stages 1 through 6, using repository-local evidence
only, for a repository with no `profiles/contentful/` integration. <!-- boundary-exempt: prose -->
The core declares no required runtime dependency on any module under
`profiles/contentful/`, and no core stage waits on one. <!-- boundary-exempt: prose -->
The core never assumes that Glean, Backstage, a `catalog-info.yaml`, or a
repository visibility policy exists. A run in a repository that has none
of them is an ordinary run, not a degraded one.

A profile may add evidence sources and may narrow the core's rules. It
may not weaken the ownership, claim, or validation guarantees this file
and its two siblings state.

Prose is half of this guarantee. The other half is mechanical:
`scripts/check-core-profile-boundary.sh` flags any line under `core/`
containing the profile directory path unless the line carries the
`boundary-exempt: prose` token, and exits non-zero when one does not.
A statement of independence that the check does not back is the way the
original coupling returns.

## Verification check

Before a run reports itself complete, confirm every one of these, and
report the first that fails:

1. Each stage's artifact exists, and stage N cites only artifacts from
   stages 1 through N-1 — the single bounded stage-4 re-entry named in
   § The stage sequence is the one re-entry exception, and stage 5's
   no-draft branch (§ Stage 5) is the one branch on which a stage's
   artifact is deliberately absent.
2. The report shows the initial state and the final state of every
   finding.
3. `.cartographer/report.md` carries both the `## Accuracy` and the
   `## Effectiveness` block, each stating its own gate's result, and the
   run's overall result is `PASS` only if both of them are.
4. The patch, if any, contains only repository-bound artifacts and only
   sections `core/readme-ownership.md` permits writing.
5. `bash <skill-root>/scripts/check-core-neutrality.sh`
   exits 0.
