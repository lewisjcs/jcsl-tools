# Refresh Contract

TL;DR: a run re-assesses either every section of the README under
analysis (**full mode**) or only the sections whose evidence or body
changed since the previous run (**targeted mode**). The choice is made
once, at Step 0, from `.cartographer/last-run.md` — the fingerprint the
previous run wrote — and every case that file cannot decide falls back
to full mode, which is always correct and only ever more expensive.

This file is the sole definition site for the run-state file format, the
per-section fingerprint schema, the `section-key` identifier, the
mode-selection rule, the change-impact selection algorithm, the
bounded-cost fallback threshold, and the three reporting buckets. It
uses `core/claim-model.md`'s evidence reference — a path plus a location
— and `core/readme-ownership.md`'s section definition together with its
ownership and freshness values, and defines none of them.

Throughout, **README under analysis** means the single README this run
was invoked against, `REPO_ROOT` means the top level of the working tree
holding it, and **HEAD** means the revision the current run executes at,
as reported by `git -C <REPO_ROOT> rev-parse HEAD`. The recorded
revisions have two distinct names, used consistently below and never
interchanged: `source-revision` is the header field and
`last-assessed-revision` is the per-row field.

## Term Definitions

| Term | Kind | Definition |
|---|---|---|
| full mode | run mode | Every section of the README under analysis is assessed. Stages 1 through 6 run for all of them. |
| targeted mode | run mode | Only the sections the per-section procedure selects are assessed; the rest are carried forward. |
| run state | artifact | `.cartographer/last-run.md`, the file one run writes at stage 6 and the next run reads at Step 0. |
| fingerprint | artifact | The table inside the run state: one row per classified section of the README the writing run analyzed. |
| `section-key` | identifier | The fingerprint's row key for a section. Defined below; this file is its sole definition site. |
| `source-revision` | run-state header field | The revision the run that wrote the file completed at. A later run diffs from it. |
| `readme-path` | run-state header field | The `REPO_ROOT`-relative path of the README the writing run analyzed. |
| `last-assessed-revision` | fingerprint field | The revision at which that row's classification was actually computed. |
| `evidence-paths` | fingerprint field | The `REPO_ROOT`-relative paths of the evidence references behind that section's claims. |
| `watched-paths` | fingerprint field | The pathspecs an absence-based claim in that section was established by. Defined below. |
| `body-hash` | fingerprint field | The digest of that section's normalized body. Defined below. |
| assess | section disposition | Run stages 1 through 3 for the section, producing fresh evidence, fresh ledger rows, and a fresh classification. |
| carry forward | section disposition | Reuse the recorded ownership and freshness without running stages 1 through 3 for the section. |
| covers | predicate | The relation between one fingerprint row and one path. The only path-matching predicate in this contract; Step 0 and the per-section procedure both use it. Defined below. |

`source-revision` and `last-assessed-revision` are two fields because
they are two facts. A carried-forward row keeps its older
`last-assessed-revision`; a freshly assessed row gets `source-revision`.
The report's "last assessed at" figure reads `last-assessed-revision`;
the diff base reads `source-revision`.

## The run state is rewritten in whole at stage 6

`.cartographer/last-run.md` is written in whole every run and never
partially updated. Its format:

```markdown
# Cartographer run state

- source-revision: <output of `git -C <REPO_ROOT> rev-parse HEAD` at stage 6>
- readme-path: <path of the README under analysis, relative to REPO_ROOT>

| section-key | ownership | freshness | last-assessed-revision | evidence-paths | watched-paths | body-hash |
|---|---|---|---|---|---|---|
```

The empty-cell literal is a single `-`. `evidence-paths` and
`watched-paths` are comma-separated, `REPO_ROOT`-relative, deduplicated,
and sorted. The file is a working-only artifact under
`core/pipeline.md`'s split: it never enters a patch.

## `section-key` identifies every classified section, not only managed ones

`core/readme-ownership.md`'s `<id>` exists only for
`cartographer-managed` sections, and the fingerprint keys every
classified section. Apply in order, once per section:

1. The section is `cartographer-managed` → its marker `<id>`, verbatim.
2. Otherwise → the kebab slug of its heading text, computed exactly as
   `make_slug()` in `scripts/check-readme-patch.sh:90-96` computes it:
   delete every character that is not alphanumeric, space, or hyphen;
   lowercase; replace each space with `-`.
3. When two sections yield the same key, the first in document order
   keeps it and each later one appends `#<ordinal>`, the 1-based
   occurrence number — `overview`, `overview#2`, `overview#3`.

Document order is the only tiebreak. It is deterministic and needs no
heading-level component. A `section-key` is not a line number and never
encodes one: line numbers move, and a key must survive an unrelated edit
above its section.

## The body-content hash — one command, one normalization

The section body is `core/readme-ownership.md`'s section — the heading
line and the lines beneath it, up to but excluding the next heading of
the same or shallower level. For a `cartographer-managed` section the
enclosing `<!-- cartographer:managed:start|end <id> -->` lines are
excluded from the body: they are the delimiter, not the content, and
including them would make an id rename read as a body change.

Normalize in this order, then hash:

1. Extract the body lines as defined above.
2. Strip trailing whitespace from every line (`sed -E 's/[[:space:]]+$//'`).
3. Drop leading and trailing blank lines of the extracted block.
4. Join the surviving lines with a single `\n` between each adjacent
   pair and **no** trailing newline. That joined string is
   `$normalized_body`.
5. `printf '%s\n' "$normalized_body" | shasum -a 256 | awk '{print $1}'`
   — the `\n` in this format string is the one and only newline that
   terminates the hashed byte stream.

**The hashed byte stream ends in exactly one `\n`.** Step 4 supplies no
terminator and step 5 supplies exactly one: `printf '%s\n'` is the
mechanism that terminates the stream, not a second terminator layered on
top of step 4. Do not append a newline in step 4, and do not use
`printf '%s'` in step 5.

Consequence and failure branch: either deviation changes every digest in
the table, and changes them silently. The compare side runs at Step 0 of
a later run, possibly in a later session, reading this same contract
text. A digest computed under one reading and compared under the other
mismatches for every section, and targeted mode degrades to a full
re-assessment with no error — the exact failure the fingerprint exists
to prevent.

Record the full 64-character lowercase hex digest. No truncation, no
case folding, and no markdown normalization beyond steps 2 through 4;
the bytes are hashed as they appear in the file.

`core/local-validation.md`'s external-tool allowlist does not verify
this pipeline. That allowlist is tested against `argv[0]` alone, and
`argv[0]` here is `printf`, which the list does not carry — `shasum`
appears later in the pipeline and is never examined. A README
that documents this command verbatim therefore emits
`GAP|command|<file>:<line>|<cmd>|not verified: …` unless one of RC-10's
other clauses matches it. That is a reporting fact about documenting the
command, not a constraint on running it; this contract's hash is
computed by the run, not read out of a README.

## The hash is always taken over the README on disk

The hash is taken over the README under analysis as it stands on disk in
the repository's working tree, never over stage 3's in-memory candidate.
Stage 3's draft exists only after the stages targeted mode skips, so
hashing it would be circular.

- **Compare (Step 0, before stage 1):** hash each section of the on-disk
  README and compare against the recorded `body-hash`.
- **Write (stage 6):** hash each section of the on-disk README as it
  stands at that moment — the unmodified file on a report-only run, the
  post-patch file on an authorized-patch run that applied one.

Both ends read the same artifact, which is what makes a later run's
comparison meaningful.

## `watched-paths` records the pathspec an absence was established by

`core/claim-model.md` defines a claim's `reference` as a path plus a
location, a commit, or a supplied record id, and records no glob and no
absence artifact. `watched-paths` is therefore a fingerprint-level field
with its own source, not a projection of the ledger's `reference` field:

> For every `included` claim whose evidence class is `inference` and
> whose supporting facts are the *absence* of a file set,
> `watched-paths` records the exact pathspec the run evaluated during
> stage 1 to establish that absence, in `git ls-files` pathspec form —
> a claim that no CI is configured, established by
> `git -C <REPO_ROOT> ls-files -- '.github/workflows/*'` returning
> empty, records `.github/workflows/*`.

Non-firing branches, stated so a literal executor cannot improvise:

- A section with no absence-based `included` claim records `-`.
- A section that has one whose stage-1 pathspec was not recorded records
  the literal `unrecorded`.

Consequence and failure branch: a row whose `watched-paths` is
`unrecorded` is never eligible for carry-forward. It is re-assessed
every run. That is the safe failure.

The producing half of this rule lives elsewhere: `core/pipeline.md`
stage 1 requires the pathspec to be recorded, and the skill's stage-1
instructions perform the recording. This file defines the field; it does
not instruct the executor.

## Only `current` carries forward

A section whose recorded freshness is `stale` or `obsolete` is always
re-assessed, regardless of which paths its row covers and of any
body-hash match. `core/readme-ownership.md`'s action matrix requires a
`stale` or `obsolete` section to produce a proposed diff, an in-place
body replacement, or a proposed removal, each citing the contradicting
evidence — and the fingerprint records no evidence citation and no
drafted body. Carrying such a row forward would put a section in the
drifted bucket with nothing to cite, which the matrix forbids. Only
`freshness: current` rows are carry-forward candidates.

## A row *covers* a path — one predicate, used at both sites

A fingerprint row **covers** a path when either of these holds:

1. The path is byte-equal to one of the row's `evidence-paths` entries,
   both compared as `REPO_ROOT`-relative paths with no leading `./`.
2. The path is listed by
   `git -C <REPO_ROOT> ls-files -- <watched-pathspec>` for one of the
   row's `watched-paths` entries.

This is the only path-matching predicate in this contract, and the two
places that need one both use it: Step 0's uncovered-path valve (step 8)
and the per-section procedure's rule 5. There is no second, weaker
relation. A reading that treats one site as byte-equality and the other
as something looser is a misreading of this section, not a distinction
this contract draws.

Clause 2 is what closes targeted mode's new-path hole. A file added
since `source-revision` is byte-equal to no `evidence-paths` entry, so
under clause 1 alone it would be covered by no row, fire step 8 on every
addition, and never reach rule 5 — and a row whose watched pathspec
matches that new file would otherwise carry its section forward with an
absence-based claim that the new file has already falsified. Under
clause 2 the watching row covers the new file, the run stays in targeted
mode, and rule 5 selects that row's section for assessment.

A path that clause 2 matched when the fingerprint was written but no
longer matches — a watched file deleted since `source-revision` — is
covered by no row and fires step 8. Full mode is the correct direction
there: the row that watched it can no longer be evaluated against it.

## Selecting the mode — apply in order, once per run, at Step 0

1. `.cartographer/last-run.md` is absent → **full mode**. This is not a
   degraded run; report nothing about it.
2. The file is present and missing its `source-revision` line, missing
   its `readme-path` line, or missing its fingerprint table → **full
   mode**; report
   `targeted mode unavailable: .cartographer/last-run.md is unparseable`.
   All three header elements are required, and any one of them absent
   makes the file unparseable in the same sense and reports the same
   string.
3. Any body row of the fingerprint table is malformed → **full mode**;
   report
   `targeted mode unavailable: .cartographer/last-run.md has a malformed fingerprint row at table row <N>`,
   where `<N>` is the 1-based position of the **first** malformed row
   among the table's body rows (the header and delimiter rows are not
   body rows). A row is malformed when any one of these holds: its cell
   count is not 7; its `section-key` cell is empty; its `ownership` cell
   is not one of `cartographer-managed`, `other-tool-generated`,
   `human-authored`, `unknown`; its `freshness` cell is not one of
   `current`, `stale`, `obsolete`; or its `body-hash` cell does not
   match `^[0-9a-f]{64}$`. Both enums are `core/readme-ownership.md`'s;
   this file uses them and defines neither.

   Two or more body rows carry the same `section-key` → **full mode**;
   report
   `targeted mode unavailable: .cartographer/last-run.md records section-key <key> in more than one fingerprint row`,
   where `<key>` is the first `section-key` in table order that appears
   more than once. A duplicate key is a further way this table is
   malformed, and it carries its own report string because it is a
   property of the table rather than of any single row — neither row is
   individually wrong, and the pair leaves the per-section row lookup
   with no defined answer. Evaluate the five per-row criteria across
   every body row first and report the malformed-row string if any of
   them holds; evaluate the duplicate-key criterion only when no row is
   individually malformed, so exactly one of the two strings is emitted.
4. The recorded `readme-path` is not the README this run is analyzing →
   **full mode**; report
   `targeted mode unavailable: run state records readme-path <recorded> but this run analyzes <current>`.
   Compare the two as `REPO_ROOT`-relative paths with no leading `./`,
   byte for byte after that normalization.
5. `git -C <REPO_ROOT> rev-parse --git-dir` exits non-zero → **full
   mode**; report
   `targeted mode unavailable: no accessible git history`.
6. `git -C <REPO_ROOT> cat-file -e <source-revision>^{commit}` exits
   non-zero → **full mode**; report
   `targeted mode unavailable: recorded revision <source-revision> does not resolve`.
7. **Bounded-cost valve.** `CHANGED` is
   `git -C <REPO_ROOT> diff --name-only <source-revision>..HEAD` and
   `TRACKED` is `git -C <REPO_ROOT> ls-files | wc -l`. When
   `changed_count * 4 > tracked_count` → **full mode**; report
   `targeted mode unavailable: changed-path count <changed_count> exceeds 25% of <tracked_count> tracked files`.
   The `* 4 >` form is the integer expression of the 25% threshold — no
   floating point. **25% is a tunable heuristic, not a contract
   constant.**
8. **Uncovered-path valve.** When a path in `CHANGED` other than the
   `REPO_ROOT`-relative path of the README under analysis is covered by
   no row → **full mode**; report
   `targeted mode unavailable: <path> is covered by no recorded section`.
   *Covers* is the predicate defined above, unchanged and not restated
   here.

   The README under analysis is the one path this valve excludes from
   its domain, and it is excluded because it is already owned by the
   per-section body-hash rule (rule 6 below), which detects any change
   to any of its sections. Without the exclusion, the tool's own
   patch-then-commit-then-rerun cycle would put the README in `CHANGED`,
   find it in no section's `evidence-paths`, and fall back to full mode
   on every run after a committed README edit — making rule 6
   unreachable for exactly the edits it exists to catch. No other path
   is excluded.
9. Otherwise → **targeted mode**.

One malformed row — or one duplicated `section-key` — forces full mode
for the whole run. The offending rows are not discarded, and their
sections are not merely re-assessed while the remaining rows are
trusted: either defect means the write side of this file is not
behaving as this contract specifies, and a table that is provably wrong
in one place gives no ground for trusting the rows beside it. That is
the same safe-failure bias steps 5 through 8 carry — every uncertain
case falls back to full mode.

Step 4 is what makes `readme-path` load-bearing rather than a decorative
header field. There is exactly one `.cartographer/last-run.md` per
working tree, and `section-key`s are heading slugs (`overview`,
`quick-start`) that collide freely across two different READMEs in one
repository. Without step 4 a run against a second README would match
another file's fingerprint rows and carry that file's sections forward.
Stage 6 writes `readme-path` for the README this run analyzed, so the
next run against the same README passes this step, and the next run
against a different one falls back to full mode and rewrites the state
file for its own README.

The eight report strings in steps 2 through 8 are exhaustive: every path
by which a run declines targeted mode emits exactly one of them, and no
other string. Step 1 is the only silent fallback, and it is silent
because a first run in a working tree is not a degraded run. A case none
of the eight covers is a contract defect to raise, not a string to
invent.

Precedence, stated once: steps 1 through 8 are run-level. If any of them
fires, the run is in full mode and **no section-level evaluation happens
at all** — the per-section procedure below is not consulted, and no
section is carried forward.

## Selecting sections — apply in order, once per key, in targeted mode only

The iteration domain is the **union** of the `section-key`s recorded in
the fingerprint and the `section-key`s of the sections present in the
current README under analysis, the latter computed by the `section-key`
rule above. The domain is the union and not the current README's
sections alone, because rule 1 keys off a fingerprint row that has no
section left to iterate; an executor that walked only the current
README's sections would never reach it and would silently drop the
`sections removed since <source-revision>` report line. Walk the union
in document order for the keys present in the README, then the
remaining fingerprint-only keys in table order.

1. The `section-key` is in the fingerprint and the section is absent
   from the current README → the section is not part of this run. List
   it in the report under `sections removed since <source-revision>`,
   put it in **no** bucket, and write **no** row for it at stage 6. Its
   absence does not trigger full mode.
2. The section is present and its `section-key` is absent from the
   fingerprint → **assess**. A new section is never carried forward, and
   its presence does not trigger full mode.
3. The recorded `freshness` is not `current` → **assess**.
4. `watched-paths` is `unrecorded` → **assess**.
5. The row covers a path in `CHANGED` → **assess**. *Covers* is the
   predicate defined above — the same one step 8 applies, with no
   weakening here.
6. The current body-hash differs from the recorded `body-hash` →
   **assess**, regardless of which paths the row covers.
7. Otherwise → **carry forward**: reuse the recorded ownership and
   freshness, report the section under **not assessed** together with
   its `last-assessed-revision`, and re-emit its row at stage 6 with a
   freshly computed `body-hash` and its unchanged
   `last-assessed-revision`.

Non-firing branches, stated so a literal executor cannot improvise: no
branch of this procedure returns the run to full mode. A removed
section, a new section, and a section whose recorded row cannot be
trusted are all handled inside targeted mode, and the run-level steps
are not re-evaluated once Step 0 has selected the mode. Every key in the
union reaches exactly one of the seven branches — the first that fires
decides — so no section is both assessed and carried forward, and no
fingerprint key goes unvisited.

## What targeted mode does not detect

`CHANGED` is a commit-range diff, `<source-revision>..HEAD`. An
uncommitted working-tree edit to a tracked evidence or watched file
appears in no `CHANGED` entry, so it reaches neither step 8 nor rule 5,
and a section whose evidence drifted only in the working tree carries
forward. The body-hash closes this for one file and one file only: it is
taken on disk, so an uncommitted edit to the README under analysis still
fires rule 6. Every other file's uncommitted state is invisible to this
contract.

The harm is bounded, not absent, and the bound is the reporting rule:
such a section is reported under **not assessed** with its
`last-assessed-revision`, never under **confirmed current**. A run
therefore never asserts freshness it did not verify — it reports that it
did not look, and names the revision it last looked at. To assess
against uncommitted work, commit the work first, or delete
`.cartographer/last-run.md` to force full mode under step 1.

## Stage 4 is never skipped per section

`scripts/check-readme-patch.sh` takes `<README_FILE> [REPO_ROOT]` and
scans the whole file; it has no section, id, or line-range argument.
So targeted mode's saving is stated precisely: **stages 1 through 3 are
not re-run for a carried-forward section** — no evidence re-collection,
no ledger rows, no redraft — and **stage 4 runs whole-file, once, on
every run in both modes**. Targeted mode saves stages 1 through 3, not
stage 4: one bash invocation is cheap, and a whole-file exit code that
is always correct is worth more than skipping it.

Record-to-section attribution, for the report: a record belongs to the
section whose heading line number is the greatest heading line number
less than or equal to the record's `<LINE>`. A record attributed to a
carried-forward section is carried into the report as an informational
finding under that section's "not assessed" entry and does not change
its carried-forward classification — it was not produced by content this
run drafted.

Consequence and failure branch: every record counts toward the run's
exit code. Carrying a section forward never suppresses a `GAP`. Which
`GAP`s block patch readiness is `core/local-validation.md`'s RC-9 rule,
consumed by the skill, and not this file's.

## The accuracy dispatch covers the claims this run wrote ledger rows for

Stage 5 runs two dispatches, and targeted mode scopes them differently.
The asymmetry is stated here rather than left to be inferred from the
section above, because the two dispatches read two different inputs.

**The accuracy dispatch covers the claims this run wrote ledger rows
for.** In targeted mode a carried-forward section produced no ledger
rows this run — stages 1 through 3 did not run for it — so its claims
are not dispatched: the verification recorded by the run that last
assessed the section stands, exactly as its ownership and freshness do.
`.cartographer/verification-report.md` therefore holds accuracy records
only for freshly drafted claims, and `dispatched`, `spot-checked`, and
`unverified-other` count over that set.

**The effectiveness dispatch is not scoped this way.** It reads the
whole drafted README as a newcomer would, so it runs whole-file, once,
on every run in both modes — the same reasoning § Stage 4 is never
skipped per section gives for the checker. A newcomer reads the file,
not the diff.

The asymmetry is load-bearing beyond cost. Scoping the effectiveness
dispatch per section would leave `.cartographer/verification-report.md`
carrying fewer than five `question` records in targeted mode, which
`scripts/check-verification-report.sh` rejects. Whole-file
effectiveness is what keeps that record set total on every run, in
either mode.

The gates themselves are defined elsewhere and are not restated here:
`core/claim-verification.md` owns the accuracy dispatch scope and cites
this section for the targeted-mode rule, and
`core/effectiveness-verification.md` owns the effectiveness half.

## Every classified section lands in exactly one bucket

| Bucket | Fires when |
|---|---|
| confirmed current | Assessed this run, freshness `current`, and collected evidence positively supported at least one of the section's claims. |
| not assessed | Carried forward under selection rule 7, **or** assessed this run with freshness `current` where collected evidence neither supported nor contradicted any claim (`core/readme-ownership.md`'s branch-3 unassessed record). |
| drifted | Freshness `stale` or `obsolete`. Always freshly assessed. |

A carried-forward entry states its `last-assessed-revision`. A branch-3
unassessed entry states that evidence was collected and was silent. The
two "not assessed" reasons are distinguishable in the report even though
they share a bucket.

## Verification check

Before a run reports itself complete, confirm every one of these, and
report the first that fails:

1. The run's mode was determined legitimately (selected by the ordered
   Step 0 procedure, read from an existing checklist's `mode:` line, or
   forced to full by a restart), and a run that selected its mode this
   run by the ordered Step 0 procedure — not a run that resumed from an
   existing `progress.md` and read its mode from the `mode:` line, and
   not a restart forced into full mode by a missing `mode:` line or an
   unexecutable recorded `mode: targeted` — and that landed in full mode
   for any reason other than an absent `.cartographer/last-run.md`,
   reported exactly one of the eight strings in steps 2 through 8.
2. No section was carried forward in a run that fell back to full mode.
3. A targeted-mode run visited every key in the union of the
   fingerprint's `section-key`s and the current README's section keys,
   and every fingerprint key with no section left in the README was
   listed under `sections removed since <source-revision>`.
4. Every carried-forward section has recorded freshness `current`, a
   `watched-paths` value other than `unrecorded`, no `CHANGED` path
   covered by its row, and a current body-hash equal to its recorded
   `body-hash`.
5. Stage 4 ran whole-file on this run, and every record it emitted
   counted toward the exit code.
6. Every classified section appears in exactly one of the three buckets,
   and every carried-forward entry states its `last-assessed-revision`.
7. The run state written at stage 6 carries a `source-revision` line, a
   `readme-path` line naming the README this run analyzed, and one
   well-formed row per classified section — no `section-key` appearing
   twice, each `body-hash` a 64-character lowercase hex digest.
8. `bash <skill-root>/scripts/check-core-profile-boundary.sh`
   exits 0.
