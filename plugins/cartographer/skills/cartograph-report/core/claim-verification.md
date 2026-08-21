# Claim Verification Contract

TL;DR: every `included` claim gets a content-class at stage 2 (RC-26),
and `check-readme-patch.sh` recognizes a `signature` or `self-citation`
claim in the candidate README's own text at stage 4 (RC-27) and checks
it against the cited source or document with a permissive
existence-proxy predicate (RC-28). This is the Tier-1 half of this
file. The Tier-2 dispatch contract, the verdict taxonomy, the
verification-report grammar, and the Accuracy gate predicate are the
Tier-2 half (RC-29..RC-32), defined further down in this same file.

This file is the sole definition site for the content-class taxonomy
and its stage-2 assignment procedure, the Tier-1 textual recognition
rule, the Tier-1 match predicates, the shared Tier-2 isolated-dispatch
contract, the accuracy dispatch scope, the verification-report record
grammar, and the Accuracy gate. It uses `core/claim-model.md`'s
claim ledger and evidence classes, `core/pipeline.md`'s stage sequence,
`core/refresh.md`'s mode selection,
and `core/local-validation.md`'s RC-6 invocation, RC-8 record grammar,
and RC-9 caller-exclusion obligation, and defines none of them. It adds no
evidence class to `claim-model.md`'s three-class contract: content-class
is a separate field on the same ledger row, not a fourth member of
`class`.

## Content-class taxonomy and its Stage-2 assignment procedure (RC-26)

Four values, one per `included` ledger row's content-class field:
`signature`, `self-citation`, `behavioral`, `other`. `claim-model.md`'s
claim ledger carries the field; this file is the sole definition site
for these four values and the procedure that assigns them —
`claim-model.md` defines neither.

Apply in order, once per `included` claim, at stage 2, after
`claim-model.md`'s evidence classification has run:

1. If the statement names a code symbol — an identifier the statement
   renders as an inline code span immediately followed by `(` — the
   content-class is `signature`.
2. Otherwise, if the statement attributes a term, rule, or convention to
   a repository document, the content-class is `self-citation`.
3. Otherwise, if the statement asserts what the repository or its code
   **does, requires, produces, or forbids** — a claim about behavior
   rather than about the existence or location of a thing — the
   content-class is `behavioral`.
4. Otherwise the content-class is `other`.

Non-firing branches, stated so a literal executor cannot improvise:

- A statement that fits two classes takes the first that fires; branch
  order is the whole tiebreak, and the claim is recorded once, never
  twice.
- `other` is a residual, never a choice. A drafter may not classify a
  statement `other` to route it away from a check: while branch 1, 2, or
  3 fires, `other` is unavailable.
- Content-class is recorded on `included` rows only. An `unresolved-gap`
  row's content-class is empty — the claim never reaches the draft, so
  nothing verifies it.

**The shape test for `behavioral` as distinct from `other`.**
`behavioral` asserts a repository behavior — something an execution, a
build, or a rule could confirm or refute. `other` is the residual for a
statement about the repository's structure, provenance, or metadata
that no execution could confirm or refute. Two illustrations, simplified
for this contract and not drawn from a real drafted claim: "the build
requires Node 20" is `behavioral`; "this repository has been maintained
since 2019" is `other`.

**Routing tag, not a verification result.** Content-class decides which
verification tier a claim is eligible for, never how it is verified —
Tier 1 gates only `signature` and `self-citation` claims (RC-27 below).
`behavioral` claims dispatch to Tier 2 always, with no cap.
Tier-1-passed `signature`/`self-citation` claims **also** dispatch to
Tier 2, under a cap (RC-30) — Tier 1 gating a claim does not exempt it
from Tier 2. `other` claims dispatch to neither tier and are instead
counted in the run's honest-coverage statement (RC-30).

**How RC-26 relates to RC-27, stated so neither is read as deriving from
the other.** RC-26 assigns a content-class to a ledger row at stage 2 —
a decision about which claims dispatch to Tier 2. RC-27 below recognizes
a claim textually in the candidate README at stage 4 — a decision about
which lines the checker emits a Tier-1 record for. They are two
mechanisms at two stages on two artifacts (the ledger and the
candidate), neither derives from the other, and they are not required to
agree line-for-line. Their one point of contact is the join a Tier-1
record undergoes to reach a claim id, stated below.

## Tier-1 textual recognition rule (RC-27)

States how `check-readme-patch.sh` recognizes a `signature` or
`self-citation` claim in a candidate README's own text at stage 4 — see
RC-26 above for how content-class is assigned to a ledger row at stage
2; the two mechanisms do not derive from each other.

Both gates scan only lines **outside** fenced blocks, reusing the same
fence-toggle idiom `local-validation.md`'s `check_links()` and
`scan_markers()` already use. On such a line:

- A **`signature` claim** is an inline code span matching
  `^[A-Za-z_][A-Za-z0-9_.]*\(` — an identifier immediately followed by
  `(`. Its cited source is the **first** markdown link on the same line
  whose target resolves to a **regular file** under `REPO_ROOT` and does
  **not** end in `.md`. `<SUBJECT>` is the identifier text (everything
  before the first `(`).
- A **`self-citation` claim** is an inline code span that does not match
  the signature form and contains no `/`. Its cited document is the
  **first** markdown link on the same line whose target resolves to a
  **regular file** under `REPO_ROOT` and **does** end in `.md`.
  `<SUBJECT>` is the code span's text — the cited term.

Non-firing branches, stated so a literal executor cannot improvise:

- A qualifying code span on a line with no qualifying link for its class
  emits **no record**. A link whose target is not a regular file — a
  directory, most commonly — is not a qualifying link for either class,
  because RC-28's predicates read the cited target as a file. Gate (a)
  still resolves it as a link; this branch is what keeps a Tier-1 record
  from asserting a symbol is absent from a "cited source file" that is
  not one.
- A code span containing `/` is a path, not a cited term: no
  `self-citation` record. Paths are gate (a)'s and `local-validation.md`
  RC-11's territory.
- A code span containing `|` emits no record — the pipe-delimited
  grammar cannot carry it, the same reason a malformed marker's
  `<SUBJECT>` is `-`.
- Content inside a fenced block emits no record, on either gate. A
  fenced example is not a live claim, exactly as it is not a navigable
  link.
- **Tier 1 has no gate for the `behavioral` or `other` content-classes,
  and this is not a deferral.** `behavioral` claims are decided at Tier
  2 (RC-30). `other` claims are decided by **neither** tier; the
  Accuracy result counts them and the report states them as not
  machine-verified.

## Tier-1 match predicates (RC-28)

Permissive existence proxies, with the interpolation rule stated:

- `signature`: the identifier matches in the cited source file under the
  whole-word predicate `(^|[^A-Za-z0-9_])<identifier>([^A-Za-z0-9_]|$)`.
  No arity check, no whitespace normalization, no definition-site
  pattern.
- **`<identifier>` is interpolated literally, never as a pattern.**
  Before interpolation, every character of the identifier outside
  `[A-Za-z0-9_]` is backslash-escaped. In practice `.` is the only such
  character RC-27's signature form admits, so `store.open` interpolates
  as `store\.open`.
- **A dotted identifier is matched whole, never segment-wise.**
  `store.open` matches `store.open` and matches neither `storeXopen`,
  nor `open`, nor `store`. There is no last-segment fallback: matching
  only the last segment would pass `foo.open` against any file
  containing the word `open`, which is not a transcription proxy at
  all. A dotted identifier whose whole form is absent from the cited
  source is a `GAP`, even when a segment of it appears.
- `self-citation`: the cited term appears in the cited document as a
  **case-insensitive literal substring**. No inflection handling, no
  rule-semantics judgment. The term is also matched literally — no
  character of it is treated as a pattern metacharacter.

**Honest-proxy statement.** Both predicates are stated in this shipped
prose as proxies for transcription correctness, never as semantic
verification — the same register `local-validation.md` § Low-value
section flagging (RC-11) already established: a table mapping the real
concept to the machine-detectable stand-in, with the gap between them
stated out loud.

| What the spec asks | What RC-28 actually checks |
|---|---|
| the cited source correctly documents this symbol | the identifier's exact spelling, whole and literal, appears somewhere in the cited source file |
| the cited document correctly states this rule or term | the term's exact spelling, case-insensitive, appears somewhere in the cited document |

They are proxies, not the spec's own terms. The known false negative: a
cited document can contain the cited term without containing the
claimed rule, which is why Tier 2 exists. The dotted-identifier
whole-match rule above carries its own honesty note — whole-token
matching is stricter than a segment match precisely so the proxy stays a
proxy for transcription, not a word search.

The exact message strings a Tier-1 `signature` or `self-citation` record
carries, byte-for-byte:

| Case | `<MESSAGE>` |
|---|---|
| signature GAP | `cited symbol does not appear in the cited source file (existence proxy)` |
| signature OK | `cited symbol appears in the cited source file (existence proxy)` |
| self-citation GAP | `cited document does not contain the cited term (existence proxy)` |
| self-citation OK | `cited document contains the cited term (existence proxy)` |

## The join to a claim id (cited, not owned here)

Neither RC-27 nor RC-28 attaches a claim id to a Tier-1 finding. RC-6 is
unchanged: the checker never reads the claim ledger, so it cannot know
one. `local-validation.md` RC-9's caller obligation states how the
caller joins a Tier-1 record's `<FILE>:<LINE>` to the ledger row whose
drafted sentence occupies that line, names the claim id in the report,
and what it does when no row occupies that line. This file cites that
obligation and defines nothing about it.

## The shared Tier-2 isolated-dispatch contract (RC-29)

Tier 2 is one dispatch per gate per run, each to a fresh isolated
helper agent (a conforming dispatch per `core/dispatch-contract.md`).
It exists for exactly what Tier 1 structurally cannot decide:
transcription *fidelity* — RC-28 confirms that a symbol's spelling
appears in the cited source, and only judgment confirms that the
sentence written about it is accurate — and the `behavioral`
content-class, which has no textual proxy at all. Isolation is scoped to
that residue deliberately. The Tier-1 half of this file decides the
rest, and a dispatch that re-decided it would add cost without adding
information.

This section is the contract both gates share. The Accuracy gate fills
it as RC-30 and RC-31 state; `core/effectiveness-verification.md` RC-35
fills it for the Effectiveness gate. Both fill the same template, and
neither rewrites it.

### Isolation: what is enforced, what is asserted

There is no per-dispatch permission mechanism in this plugin, so this
contract names which half of the isolation property holds by
construction and which half is an assertion with a detector behind it,
rather than implying an enforcement it does not have.

- **No stage 1-through-3 session memory: enforced by construction.** A
  fresh isolated helper agent receives its dispatch prompt and nothing
  else. It holds no transcript of this run, so there is nothing to
  instruct it to forget — the drafting session's reasoning is
  unreachable because it was never handed over, not because the prompt
  asked the subagent to set it aside.
- **The source-access profile is asserted, detected, and not enforced.**
  Read-only repository access for Accuracy and no source access for
  Effectiveness are stated in the prompt's permitted-input list, and the
  detection branch below tests a returned verdict against that list.
  Nothing prevents a subagent from reading a file the prompt did not
  permit. In the register `local-validation.md` § `derivation` is not
  mechanically enforced already uses: the source-access half is checked
  by reading what a verdict cites, not by a sandbox, and a subagent that
  reads outside its permitted inputs and cites nothing from what it read
  is not detected.

### The dispatch prompt template

The prompt is a template, not a requirements list, because the detection
branch compares a returned verdict against the inputs that dispatch was
given — which is auditable only when the input enumeration is fixed
byte-for-byte. The template ships here verbatim. Exactly four slots vary
between dispatches; the executor fills the slots and changes nothing
else.

```
You are verifying drafted README content in isolation. You have no
record of the session that drafted it, and you may not reconstruct one.

Permitted inputs — the only material you may read or rely on:
{{ARTIFACT_LIST}}

Anything not on that list is outside this dispatch: do not read it, do
not ask for it, and do not infer its contents. If the permitted inputs
do not settle an item, say so through the verdict vocabulary below
rather than reaching outside them.

Items to verify:
{{ITEMS}}

Return one record per item, one record per line, and nothing else — no
preamble, no summary, no commentary between or after the records:
{{OUTPUT_GRAMMAR}}

Every field is required. Cite only locations you read in the permitted
inputs.
{{VIOLATION_NOTE}}
```

The four substitution slots, and nothing else, vary:

| Slot | Carries |
|---|---|
| `{{ARTIFACT_LIST}}` | the enumerated permitted inputs, one per line |
| `{{ITEMS}}` | the claims to verify (Accuracy, RC-30) or the questions to ask (Effectiveness, RC-35) |
| `{{OUTPUT_GRAMMAR}}` | the RC-31 record line this dispatch returns, with the field values legal for this gate |
| `{{VIOLATION_NOTE}}` | empty on the first dispatch; on the single re-dispatch, the sentence naming the detected violation |

**"Inversion" is therefore defined, not interpreted.** An inversion is a
named substitution of one slot's content, or of one enumerated line of
`{{ARTIFACT_LIST}}`. RC-35 states the Effectiveness gate's inversions as
slot values and rewords nothing in the template above. A gate that needs
the template's own prose changed does not have an inversion; it has a
second contract, and this file ships one.

### The Accuracy dispatch's permitted inputs and its items

`{{ARTIFACT_LIST}}` for the Accuracy dispatch is exactly these two
lines:

```
- The repository under analysis, as it stands on disk, read only. You
  may read any tracked file in it.
- The claims listed under Items to verify, each carrying a claim id, the
  drafted statement, and that statement's content-class.
```

`{{ITEMS}}` carries, per dispatched claim, exactly three values and no
others:

1. `claim id` — the returned record's `SUBJECT` is keyed by it.
2. `statement` — the claim text as drafted; it is the thing being
   verified.
3. `content-class` — it selects which verification question the prompt
   asks.

It carries none of `claim-model.md`'s `class`, `reference`,
`disposition`, or `subject` fields, and the dispatch receives no other
working-only artifact: not the evidence record, not the claim ledger,
not `.cartographer/validation-report.md`, not the run state. **The
accuracy subagent shall not receive the claim ledger.**

Where that prohibition's line falls, and why, stated outright because
guessing it wrong is a contract violation rather than a style call:

> The prohibition is on the **evidence** half of the ledger, not on the
> claim's identity. The isolation property this section holds is that
> the accuracy subagent must not see the drafting session's own
> reasoning about *why* it believed a claim — that reasoning is the
> `reference` and `class` fields, and a verification that reads them is
> re-reading the drafter's conclusion rather than testing it. It must
> see *what* was claimed, or it has nothing to verify.
> Handing over `claim id`, `statement`, and `content-class` therefore
> does not hand over the ledger; handing over `reference` does, and is
> the specific violation this rule names.

### Detection branch

A dispatch's returned output is **contaminated** when any of these
holds:

1. it cites a path, symbol, or line that appears nowhere in that
   dispatch's `{{ARTIFACT_LIST}}` inputs;
2. it returns a record that does not parse as the `{{OUTPUT_GRAMMAR}}`
   that dispatch supplied;
3. it returns no record at all, or no record for an item it was given;
4. it returns a record whose `SUBJECT` was not among that dispatch's
   `{{ITEMS}}`.

Condition 1 is the isolation condition proper. Conditions 2 through 4
are unusable-output conditions and take the same branch, because a
dispatch whose output cannot be read against its inputs cannot be shown
to have honored the profile either.

Consequence and failure branch: discard the contaminated output — never
accept it, in whole or in part — and re-dispatch **once**, filling
`{{VIOLATION_NOTE}}` with the sentence naming the detected violation.
Never re-dispatch more than once. If the re-dispatch is also
contaminated, the affected gate does not pass and the reason
`isolation not demonstrated` is carried verbatim, as the reserved
`EVIDENCE` literal (RC-31) and in that gate's block of
`.cartographer/report.md`. Concretely, and this is the whole
representation:

- **Accuracy:** emit one record per dispatched claim,
  `accuracy|<KIND>|<claim id>|plausible|isolation not demonstrated`.
  `plausible` carries the gate to `NEEDS WORK` through RC-32's existing
  predicate — no new verdict value, no reason field, and no vocabulary
  shared between the gates.
- **Effectiveness:** emit exactly five records,
  `effectiveness|question|q<i>|unanswered|isolation not demonstrated`
  for `i = 1..5`, so the five-question invariant holds, `answered=0/5`,
  and Effectiveness is `NEEDS WORK` (RC-35).

The reserved literal is legal on `accuracy` + `plausible` records and on
`effectiveness` + `unanswered` records, and nowhere else (RC-31).

## The accuracy dispatch scope (RC-30)

**Which claims dispatch.** Every `behavioral`-class claim dispatches,
always, with no cap — Tier 1 has no gate for it (RC-27), so the dispatch
is the only verification it receives. Tier-1-passed `signature` and
`self-citation` claims dispatch under a cap of **10**, sampled by the
selection rule below. `other`-class claims never dispatch.

**Tier-1-passed, defined totally so no claim falls outside the eligible
set:**

> A `signature` or `self-citation` claim is **Tier-1-passed** when stage
> 4's validation report contains no `GAP` record whose `RULE` is
> `signature` or `self-citation` and which joins to that claim's ledger
> row. A claim that produced no Tier-1 record at all is Tier-1-passed:
> Tier 1 found nothing against it. Tier-1-passed and Tier-1-failed are
> complements; there is no third "not tested" state and no exclusion for
> an untested claim.
>
> This is deliberate, not a fallback. Tier 1 is an existence proxy on
> drafted *text*; a claim it never emitted a record for is precisely a
> claim it could not test, which makes it the highest-value member of the
> spot-check sample rather than a claim to skip. A Tier-1-failed claim,
> meanwhile, was excluded from the candidate by RC-9 before stage 5 runs,
> so the eligible set and the drafted `signature`/`self-citation` claim
> set coincide.

The join named in that definition is `local-validation.md` RC-9's caller
obligation, cited above under § The join to a claim id.

**The selection rule.** Let `N` be the eligible count — the number of
Tier-1-passed `signature` and `self-citation` claims. If `N` is 10 or
fewer, all `N` dispatch. If `N` is greater than 10, sort the eligible
claim ids ascending in byte order, index them zero-based, and dispatch
exactly the ten at indices `round(i * (N - 1) / 9)` for `i = 0..9`, ties
rounded up. The ten indices are distinct for every `N > 10`, because the
step `(N - 1) / 9` exceeds 1. The sample includes the first and the last
eligible id and spreads the remaining eight evenly between them: it is
deterministic, reproducible from the ledger alone, and not front-loaded.

**`other`-class claims are verified by neither tier, and the run says
so.** `other` is by construction the class no shape test matched
(RC-26), so there is no verification question to ask of it: Tier 1 has
no gate for it (RC-27), Tier 2 never dispatches it, and RC-31's `KIND`
field does not admit it. What replaces verification is a stated coverage
gap, carried in both artifacts — the machine count
`RESULT|accuracy|…|unverified-other=<m>` (RC-31) and the prose sentence
the `## Accuracy` block carries verbatim on every run (RC-32). This is a
named blind spot, not silence: no tier verified these claims, and
neither artifact implies that one did.

**The three counts, defined once here and reported in both forms.**

| Count | Counts |
|---|---|
| `<n>` in `dispatched=<n>` | the claims this run selected for dispatch, across every dispatched content-class. Exactly one accuracy record exists per selected claim on every branch — either the returned verdict or the record RC-29's consequence branch emits in its place — so this count and the accuracy record count agree by construction, whichever branch the dispatch took |
| `<n>/<N>` in `spot-checked=<n>/<N>` | `<n>` is the `signature` and `self-citation` claims the selection rule dispatched; `<N>` is the eligible count it drew from |
| `<m>` in `unverified-other=<m>` | the `included` ledger rows whose content-class is `other` |

**Targeted mode scopes the accuracy dispatch and does not scope the
effectiveness dispatch.** `core/refresh.md` § The accuracy dispatch
covers the claims this run wrote ledger rows for is the sole definition
site for that asymmetry and its cost reasoning. Its consequence for this
section: in targeted mode the eligible set — and therefore all three
counts above — ranges over freshly drafted claims only. A carried-forward
section produced no ledger rows this run, so its claims are not
dispatched, and the verification recorded by the run that last assessed
that section stands.

## The verification-report record grammar (RC-31)

Stage 5's artifact is `.cartographer/verification-report.md`: a
working-only artifact, named to match stage 4's
`.cartographer/validation-report.md`, and never part of a patch
(`core/pipeline.md` § Repository-bound and working-only artifacts). Its
content is a machine-checkable record set — one record per line, five
fields.

```
<GATE>|<KIND>|<SUBJECT>|<VERDICT>|<EVIDENCE>
```

- `GATE` is `accuracy` or `effectiveness`.
- `KIND` is `behavioral`, `signature`, or `self-citation` when `GATE` is
  `accuracy`; exactly `question` when `GATE` is `effectiveness`. There is
  no `other` value — `other`-class claims are never dispatched and never
  produce a record (RC-30).
- `SUBJECT` is the ledger claim id on an `accuracy` record and one of
  `q1` through `q5` on an `effectiveness` record. A claim id matches
  `^[A-Za-z0-9._-]+$` (`core/claim-model.md`'s claim-id row), so it can
  never break the field count.
- `VERDICT` is `confirmed`, `plausible`, or `disproved` when `GATE` is
  `accuracy`; `answered` or `unanswered` when `GATE` is `effectiveness`.
  The two vocabularies are **disjoint**, and that disjointness is what
  makes "attribute every result to exactly one gate" mechanically
  checkable. No value is ever shared between them.
- `EVIDENCE` is non-empty on every record, and what it carries is fixed
  by verdict:

| `GATE` | `VERDICT` | `EVIDENCE` carries |
|---|---|---|
| accuracy | `confirmed` | the repository location that confirms the claim, as `<path>:<line>` |
| accuracy | `plausible` | the normalized excerpt (below) of the drafted sentence the verdict could not confirm |
| accuracy | `disproved` | the repository location that contradicts the claim, as `<path>:<line>` |
| effectiveness | `answered` | the normalized excerpt of the draft text the answer rests on |
| effectiveness | `unanswered` | the literal `none` |
| either | the RC-29 consequence branch | the reserved literal `isolation not demonstrated`, legal on `accuracy` + `plausible` and `effectiveness` + `unanswered` records, nowhere else |

**A `disproved` verdict requires a contradicting location.** Without
one, the verdict is `plausible`. This is what keeps the `EVIDENCE` table
total: every `disproved` record has a location to put in the field, by
construction.

**The normalized excerpt, defined once and applied everywhere `EVIDENCE`
carries quoted text.** Take the quoted text; replace every newline and
every `|` with a single space; collapse runs of spaces to one and trim;
truncate to 120 characters, appending `…` (U+2026) when truncation
occurred. The field is a normalized excerpt for locating the text, not a
byte-exact quote, and is labeled that way wherever it is read — a reader
who expects a quote reads a normalization as a discrepancy. The rule is
also why this grammar needs no escape syntax, no field-splitting
exception, and no unquotable branch.

The last three lines of the file, in this order, with these exact field
counts:

```
RESULT|accuracy|<PASS or NEEDS WORK>|dispatched=<n>|spot-checked=<n>/<N>|unverified-other=<m>
RESULT|effectiveness|<PASS or NEEDS WORK>|answered=<n>/5
OVERALL|<PASS or NEEDS WORK>
```

Six fields, four fields, two fields. Every value is bare: no
parentheses, no citations, no prose. The prose forms of these results
live in `.cartographer/report.md`'s two blocks (RC-32 and RC-35), never
in a `RESULT` field.

**What this artifact holds, and what it does not.**
`.cartographer/verification-report.md` holds records and nothing else —
no marker, no corrected-findings list, no prose. The
`[NEEDS VERIFICATION]` markers and the corrected-findings list belong to
the `## Accuracy` block of `.cartographer/report.md` (RC-32).

**What the checker can confirm, and what it cannot.**
`scripts/check-verification-report.sh` (RC-36) validates this grammar:
field counts, the two enums per gate, the claim-id predicate, the
`EVIDENCE` sentinel rules, and each summary line's agreement with the
records. It confirms that `unverified-other=<m>` is a non-negative
integer, and it **cannot** confirm `<m>` against the claim ledger, which
it never reads. That count is asserted by the run and checked by a human
reviewer, not mechanically enforced by this script.

## The Accuracy gate (RC-32)

**The gate predicate.** Accuracy reports `PASS` when and only when every
accuracy record in `.cartographer/verification-report.md` carries the
verdict `confirmed`. One `plausible` record or one `disproved` record
carries the gate to `NEEDS WORK`: there is no severity threshold, no
proportion, and no override. A run that produced a draft and dispatched
no claims from it has no accuracy record, so the predicate holds
vacuously and Accuracy reports `PASS` — item 7 of the block's required
contents below is what keeps that `PASS` from being read as a verified
result. A run that produced **no** draft is not that case; the
non-firing branch at the end of this section governs it, and it reports
`NEEDS WORK`.

**The verdict taxonomy.**

| `VERDICT` | The dispatch found |
|---|---|
| `confirmed` | a location in the permitted inputs that confirms the statement; that location is the record's `EVIDENCE` |
| `plausible` | nothing in the permitted inputs that either confirms or contradicts the statement |
| `disproved` | a location in the permitted inputs that contradicts the statement; that location is the record's `EVIDENCE` |

A `disproved` verdict requires a contradicting location; a verdict
reached without one is `plausible`, not `disproved` (RC-31). The gate
never excludes a drafted sentence on an unlocated objection.

**A `plausible` verdict is resolved outside the run.** Stated verbatim,
because a reader who expects an in-grammar resolution state will look
for one and not find it:

> A `plausible` verdict is resolved **outside the run**. The operator
> either corrects the drafted sentence or supplies the missing evidence,
> then re-runs stage 5; a claim resolved that way does not come back as
> `plausible` on the fresh run. There is therefore no in-grammar
> resolution state and none is needed. Within a run, every `plausible`
> record is by construction unresolved at report time, because report
> time is the end of this run — so Accuracy does not report PASS while
> any `plausible` record exists, and the report carries a
> `[NEEDS VERIFICATION]` marker for each.

Consequence and failure branch: while any accuracy record's verdict is
`plausible`, Accuracy reports `NEEDS WORK` and the `## Accuracy` block
carries one `[NEEDS VERIFICATION] <claim id>` entry for that record; a
run that reports Accuracy `PASS` over a `plausible` record, or omits the
marker for one, has not applied this rule.

**A `disproved` verdict excludes the claim and re-validates, and the
re-entry is bounded by construction.** The sequence is the caller's,
exactly as `local-validation.md` RC-9 already makes exclusion the
caller's job:

1. Stage 5 dispatches both subagents **once per run** and writes
   `.cartographer/verification-report.md`.
2. For every accuracy record whose `VERDICT` is `disproved`, the caller
   removes that claim's drafted sentence or sentences from the
   candidate.
3. If step 2 removed at least one sentence, the caller re-enters stage 4
   **once**. That re-entry is an ordinary stage-4 run against the
   reduced candidate: **RC-9 applies unchanged**, including its own
   internal re-run loop and its termination argument. The caller
   excludes each `in-patch` `GAP` subject, reports each `out-of-patch`
   one, repairs or reports each `marker` record, and rewrites
   `.cartographer/validation-report.md` from that re-entry.
4. Stage 5 does **not** re-dispatch. The verdicts from step 1 are the
   run's verdicts; a claim removed at step 2 keeps its `disproved`
   record, and that record is what the corrected-findings list is built
   from. Because no second set of verdicts is produced, no second
   exclusion round can arise: the re-entry is bounded at one **by
   construction**, not by a counter a reader has to trust.
5. Patch readiness is recomputed from the re-entry and **may flip in
   either direction**. The report states readiness before and after the
   exclusion — `core/pipeline.md` § The report states the initial state
   and the final state, not a new rule. If the re-entry's RC-9 outcome
   is blocked, the run reports the patch blocked and proceeds to stage
   6.

Consequence and failure branch: a `disproved` verdict both excludes the
claim from the patch and carries it into the `## Accuracy` block's
corrected-findings list, and a run that excludes the sentence without
reporting it — or reports it without excluding it — has not applied this
rule.

**Which rule wins where, stated verbatim so the two files cannot
drift:** RC-9 governs what happens *inside* a stage-4 run — it is
untouched by this section, and nothing new about the re-entry is written
into it. This section governs *how many times stage 5 may send the
caller back into stage 4*: at most once per run. There is no conflict
between "exclude and continue" and "block and stop", because they answer
different questions at different scopes.

**Blocked is an outcome, not a halt.** A run that reports the patch
blocked still executes stage 6 in full: it writes
`.cartographer/report.md` and `.cartographer/last-run.md`. "Blocked"
describes the patch's readiness, never the run's completion.
`core/pipeline.md`'s "Every run produces a report" is unqualified and
stays unqualified. This is the shape RC-9 already uses — a run that
reports the patch blocked over a pre-existing marker line is a complete
run (`local-validation.md` § Which marker records the run may repair,
and which it may not).

**The bounded re-entry and the stage-ordering rule are one decision.**
`core/pipeline.md` § The stage sequence states the ordering rule ("Stage
N reads only artifacts stages 1 through N-1 wrote") and names this
single bounded re-entry as its one explicit exception. The two halves
are read together: neither licenses re-entering a stage this section
does not name.

**How a `disproved` verdict relates to a claim contradicted by
evidence.** `core/claim-model.md` § When evidence contradicts fires at
stage 2, on the drafting session's own collected evidence, and its
outcome is a ledger disposition: the claim is `unresolved-gap` and never
reaches the draft. A `disproved` verdict fires at stage 5, on an
isolated dispatch's independent reading of the repository, against a
claim that is already drafted, and its outcome is the exclusion and
re-validation above plus a corrected finding in the report. Neither is a
trigger for the other: a `disproved` verdict does not rewrite a stage-2
ledger row, and a stage-2 contradiction produces no stage-5 record,
because a claim that never reached the draft is never dispatched.

**Required contents of the `## Accuracy` block of
`.cartographer/report.md`.** A report block is a named section of that
file; there are exactly two, and `core/pipeline.md` states where they
sit and that they are co-equal. The `## Accuracy` block carries, on
every run:

1. the gate's result, `PASS` or `NEEDS WORK`, as the `RESULT|accuracy`
   line states it;
2. one `[NEEDS VERIFICATION] <claim id>` entry per accuracy record whose
   verdict is `plausible`;
3. one corrected-findings entry per accuracy record whose verdict is
   `disproved`, naming the claim id and the drafted sentence that was
   removed;
4. patch readiness before and after any exclusion, when step 2 of the
   sequence above removed a sentence;
5. these two sentences, verbatim:

   ```
   spot-checked <n> of <N> Tier-1-passed signature and self-citation claims (deterministic stride sample, cap 10 — core/claim-verification.md RC-30).
   <m> other-class claims were recorded this run and are verified by neither tier.
   ```

6. the reserved literal `isolation not demonstrated`, carried verbatim
   as the gate's stated reason whenever it appears in an accuracy
   record's `EVIDENCE`;
7. when `dispatched=0`, the sentence `no claims were eligible for Tier-2
   verification this run`.

Item 5's second sentence is present on every run, including runs where
`<m>` is 0, and item 7 covers the run that dispatched nothing — together
they are what keeps a vacuous `PASS` from being printed bare.

Deriving this block from the records at run time is
`skills/cartograph-report/SKILL.md` § Stage 5 in detail; the required
contents are fixed here so that derivation is mechanical rather than a
judgment call.

**Non-firing branch: a run that produced no draft.** Stated verbatim,
and it takes precedence over the gate predicate's vacuous case:

> Non-firing branch: a run that produced no draft has nothing to verify.
> Stage 5 dispatches neither subagent and writes no
> `.cartographer/verification-report.md`. Both report blocks state
> `stage 5 not run: the run produced no draft` and both report NEEDS
> WORK — a run with no draft has demonstrated neither accuracy nor
> effectiveness — so overall PASS is false. The absent artifact is this
> branch's stated outcome, not a missing artifact under `pipeline.md`'s
> Verification-check item 1. The Stage-5 checklist line is still marked
> `[x]`: the stage ran and produced its stated outcome; it was not
> interrupted.

**Which rule wins where, so the two zero-record cases cannot be read as
one:** the gate predicate's vacuous `PASS` governs a run that produced a
draft and dispatched no claims from it — there was something to verify
and nothing in it was eligible, which is a coverage statement the
`## Accuracy` block makes in item 7. This non-firing branch governs a
run that produced no draft at all: stage 5 dispatches neither subagent,
writes no `.cartographer/verification-report.md`, and there is no gate
predicate to evaluate, because the file the predicate reads does not
exist. They answer different questions — nothing eligible to verify
versus nothing to verify — and where both descriptions could be applied
to a run, this branch is the one that fires, because a run with no draft
has demonstrated neither accuracy nor effectiveness.

## The verification-report checker (RC-36)

`scripts/check-verification-report.sh` is the deterministic validator for
the artifact RC-31 defines. It validates the record grammar and both gate
predicates' arithmetic — field counts, the two per-gate enums, the
claim-id predicate, the `EVIDENCE` sentinel rule, the five-question
invariant (`core/effectiveness-verification.md` RC-35), and each summary
line's agreement with the records. It never judges whether a verdict is
itself correct: that is the dispatched subagent's job (RC-29), and a
checker that re-decided it would be a third opinion with no inputs to
form one from.

### Invocation

```
check-verification-report.sh <VERIFICATION_REPORT_FILE>
```

One argument, the stage-5 artifact. The script is read-only: it never
rewrites `VERIFICATION_REPORT_FILE` and writes no file of its own. It
never reads the claim ledger — `local-validation.md` RC-6's reasoning
holds here unchanged, the ledger is a working-only artifact
(`core/claim-model.md`) and a checker that depended on it would read the
drafting session's conclusion rather than test the emitted artifact. It
is only ever invoked on a file that exists: the no-draft branch above
writes no `.cartographer/verification-report.md` and does not invoke the
checker. Its regression fixtures are
`scripts/fixtures/accuracy-verification/` and
`scripts/fixtures/effectiveness-verification/`.

### The report is stdout, one violation per line

```
INVALID|<LINE>|<MESSAGE>
```

- `<LINE>` is the **1-based line number** of the offending line, a bare
  integer. It is not the record text: the text is already in the file,
  and locating it is the number's whole job. `local-validation.md` RC-8's
  `<FILE>:<LINE>` is the in-repo precedent.
- A **file-level** violation — one with no single offending line —
  carries `<LINE>` `0`. Zero is a line number in no file, so it is
  unambiguous and keeps the field integral.
- The final line of every run is `SUMMARY|invalid=<n>`, where `<n>`
  counts exactly the `INVALID` records that run just emitted. This
  mirrors RC-8's `SUMMARY|gaps=<n>|low_value=<n>`: same register, no new
  conventions.
- **This grammar is the checker's stdout. The `RESULT` and `OVERALL`
  lines are the input file's last three lines (RC-31).** Two
  pipe-delimited grammars on two artifacts: a reader who conflates them
  looks for `INVALID` in the verification report, or for `RESULT` in the
  checker's output, and neither is there.
- A blank line carries no record and is ignored everywhere, including in
  "the last three lines". Reported line numbers are the file's own, blank
  lines counted, so every `<LINE>` locates a line in the file as it
  stands.

### The message strings

Byte-for-byte, so a consumer and a regression fixture pin the same
target:

| Case | `<LINE>` | `<MESSAGE>` |
|---|---|---|
| record field count | record | `record does not carry exactly five fields` |
| summary field count | summary | `summary line does not carry its stated field count` |
| illegal gate | record | `unknown gate: legal values are accuracy and effectiveness` |
| illegal kind | record | `kind is not legal for this gate` |
| illegal verdict | record | `verdict is not legal for this gate` |
| malformed subject | record | `claim id does not match ^[A-Za-z0-9._-]+$` |
| unknown question subject | record | `question subject is not one of q1 through q5` |
| duplicate question | record | `question subject appears more than once` |
| missing question record | `0` | `the five question records q1 through q5 are not all present` |
| evidence sentinel misuse | record | `evidence is none on a record that is not an unanswered question` |
| empty evidence | record | `evidence is empty` |
| accuracy result | summary | `RESULT accuracy is PASS while a disproved or plausible accuracy record exists` |
| effectiveness result | summary | `RESULT effectiveness is PASS while an unanswered question record exists` |
| answered count | summary | `RESULT effectiveness answered count does not match the question records` |
| dispatched count | summary | `RESULT accuracy dispatched count does not match the accuracy records` |
| spot-check count | summary | `RESULT accuracy spot-checked numerator does not match the signature and self-citation records` |
| overall | summary | `OVERALL is PASS while a RESULT line is NEEDS WORK` |
| missing or misordered summary lines | `0` | `the three summary lines are not the last three lines of the file, in order` |

Two of those rows carry a stated scope, so a reader is not left to infer
one:

- The **summary field count** message covers a summary line that is not
  in RC-31's stated form for that line — a field count other than six,
  four, and two, a result value other than `PASS` or `NEEDS WORK`, or a
  count field that is not in its stated `key=value` form, including a
  `unverified-other=<m>` whose `<m>` is not a non-negative integer. A
  summary line carrying this violation is not then compared against the
  records: a value that cannot be read cannot be shown to disagree with
  them.
- The **missing or misordered summary lines** violation is terminal. The
  checker emits it, emits `SUMMARY|invalid=1`, and exits 1 without
  validating any record, because without the three summary lines the
  record region has no end and every per-record result would be an
  artifact of the miscut rather than a finding about a record.

### Exit codes

| Exit | Meaning |
|---|---|
| `0` | no `INVALID` records. The file is a legal RC-31 emission |
| `1` | one or more `INVALID` records |
| `2` | usage or invocation error (a missing, unreadable, or non-file `VERIFICATION_REPORT_FILE`) |

Exit 1 is a defect in the artifact, not a gate result: a legal file whose
`OVERALL` is `NEEDS WORK` exits 0, because the gate result and the
artifact's validity are two different questions. The three shapes that
most invite a wrong answer here are all legal and all exit 0 — the
contaminated-dispatch accuracy records (`plausible` +
`isolation not demonstrated`), the contaminated-dispatch five
effectiveness records (`unanswered` + `isolation not demonstrated`), and
the vacuous accuracy PASS with `dispatched=0` and `spot-checked=0/0`.

### What the checker confirms, and what it cannot

Stated in the same never-flattering register `local-validation.md` §
`derivation` is not mechanically enforced uses, because a checker that
implied coverage it does not have is worse than one that names its blind
spots:

- It **cannot** confirm `unverified-other=<m>` against the claim ledger,
  which it never reads. It confirms `<m>` is a non-negative integer and
  nothing more; the count itself is asserted by the run and checked by a
  human reviewer.
- It checks the `none` sentinel in both directions — `none` appears on an
  `effectiveness|question|<q>|unanswered` record and nowhere else — and
  it does **not** police the free prose inside an `EVIDENCE` excerpt.
  RC-31 states no form for that prose, and a check that pinned it would
  reject correct output over formatting, which trains a caller to fight
  the check instead of meeting it.
- The reserved literal `isolation not demonstrated` is admitted wherever
  RC-31 permits it and is not otherwise policed: no message string above
  names its misuse, and a checker that reported a violation this contract
  does not define would be inventing one.
- `spot-checked=<n>/<N>` is checked in full from the file alone — `<n>`
  equals the `signature` plus `self-citation` record count, and `<n>`
  equals `<N>` when `<N>` is 10 or fewer and 10 when `<N>` is greater —
  but `<N>` itself is the eligible count RC-30 draws from, which lives in
  the ledger. The checker cannot confirm `<N>`, for the same reason it
  cannot confirm `<m>`.

## Verification check

Before trusting a content-class assignment, a Tier-1 finding, or a
Tier-2 verdict, confirm every one of these, and report the first that
fails instead of the finding:

1. Every `included` ledger row carries exactly one content-class value,
   assigned by the RC-26 procedure above, and no `unresolved-gap` row
   carries one.
2. RC-26 fired in branch order — the first branch that matched decided
   the value, and no row was assigned `other` while an earlier branch
   could fire.
3. Every RC-27 finding was recognized outside a fenced block, and no
   fenced example was read as a live claim.
4. Every RC-28 predicate result interpolated the identifier or term
   literally, with each character outside `[A-Za-z0-9_]` escaped, and
   matched a dotted identifier's whole form, never a segment.
5. Every `signature` or `self-citation` message reproduces the table
   above byte-for-byte.
6. Every dispatch used the RC-29 template with its four slots filled and
   nothing else altered, and each `{{ITEMS}}` entry carried the claim
   id, the statement, and the content-class — and no other ledger field.
7. The claims dispatched are exactly those RC-30 selects: every
   `behavioral` claim, the selection rule's sample of the Tier-1-passed
   `signature` and `self-citation` claims, and no `other`-class claim.
8. Every branch RC-29, RC-30, and RC-32 names produced a legal RC-31
   record. A branch that emitted a gate, kind, verdict, subject, or
   reason the five-field grammar cannot carry is a defect in this file,
   not a case to improvise around.
9. `.cartographer/verification-report.md`'s last three lines are the
   three summary lines, in order, carrying six, four, and two fields,
   with bare values only.
10. Accuracy reports `PASS` only when every accuracy record is
    `confirmed`, and the `## Accuracy` block carries every item RC-32
    lists — including both coverage sentences on a run where nothing
    failed.
11. Stage 5 dispatched each subagent once, re-dispatched at most one
    contaminated dispatch, sent the caller back into stage 4 at most
    once, and re-dispatched nothing after that re-entry.
