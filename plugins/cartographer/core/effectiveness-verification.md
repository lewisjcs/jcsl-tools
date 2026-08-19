# Effectiveness Verification Contract

TL;DR: stage 5 dispatches a second, independent subagent that reads the
drafted README alone, as a newcomer would, and tries to answer five
fixed questions from it (RC-33). Each question is `answered` or
`unanswered` (RC-34), and the Effectiveness gate reports `PASS` only
when all five are `answered` (RC-35). This is the second consumer of
`core/claim-verification.md` RC-29's shared Tier-2 isolated-dispatch
contract — this file cites that contract and states only Effectiveness's
own slot values, its own gate, and its own report block. It defines no
dispatch mechanics of its own.

This file is the sole definition site for the newcomer-question set, the
answered/unanswered predicate, the Effectiveness dispatch's slot values,
the Effectiveness gate, and the required contents of the `## Effectiveness`
block of `.cartographer/report.md`. It uses `core/claim-verification.md`
RC-29's shared dispatch contract (the isolation split, the verbatim
prompt template, the detection branch, the one-re-dispatch bound, and the
`isolation not demonstrated` consequence) and RC-31's verification-report
record grammar and normalized-excerpt rule, `core/pipeline.md`'s stage
sequence, and `core/refresh.md`'s mode selection, and defines none of
them. `claim-verification.md` fills the same RC-29 template for the
Accuracy gate; neither file rewrites the template the other fills.

## The newcomer-question set (RC-33)

Five questions, fixed, one per README section kind the core may draft.
This is the set; it is never composed or extended per run:

1. What does this repository do, and who or what is it for?
2. What exact commands do I run to set this repository up and confirm
   the setup worked?
3. Which directories or components hold this repository's main parts,
   and what is each one responsible for?
4. What constraint, guardrail, or convention would I violate here
   without being told about it?
5. Where do I go — which file or which command — to make a change of a
   kind this repository handles routinely?

Each question's `SUBJECT` in a verification-report record is its
position in this list — `q1` through `q5` — never its text
(`core/claim-verification.md` RC-31).

## The answered / unanswered predicate (RC-34)

The spec asks the dispatched subagent to "attempt to answer each
newcomer question from the draft alone" and to "report each question as
answered or unanswered." Both halves are under-specified until this
section states the criterion.

A question is **answered** when the draft alone contains a specific,
actionable statement resolving it — naming a concrete path, command,
component, or rule — and the subagent can quote the draft text it relied
on. It is **unanswered** when no such text can be quoted, or when the
only bearing text is generic and names no path, command, component, or
rule. **A partially-answered question is unanswered.** There is no third
value: the binary is the gate's whole force, and any `unanswered`
question means Effectiveness is `NEEDS WORK` (RC-35) with the question
listed, verbatim from RC-33 above, in the `## Effectiveness` block.

**The quote requirement, reconciled with RC-31's normalization.** Every
`answered` record's `EVIDENCE` carries the draft text the subagent relied
on as `core/claim-verification.md` RC-31's **normalized excerpt** — never
a byte-exact quote, because RC-31's grammar cannot carry one. This is not
a weaker requirement than "quote the draft text": it enforces that
quotable text exists. An `answered` record whose `EVIDENCE` is the
literal `none` is invalid, and `scripts/check-verification-report.sh`
(RC-36) rejects it. What the field promises is locatable, not verbatim,
text — the same honesty `scripts/check-readme-patch.test.sh`'s
`assert_line` helper already models for a different artifact: pin the
artifact, not the prose around it.

## The Effectiveness dispatch profile, gate, and report block (RC-35)

This section fills `core/claim-verification.md` RC-29's shared template
for the Effectiveness gate. It states Effectiveness's inversions as named
slot values, per RC-29's own definition of "inversion" — a named
substitution of one template slot's content, or of one enumerated line of
`{{ARTIFACT_LIST}}`. It rewords nothing in the template's prose, and
everything RC-29 defines that this section does not restate — the fresh
Task-tool dispatch, the malformed-verdict branch, the one-re-dispatch
bound, and the general shape of the `isolation not demonstrated`
consequence — is RC-29's, cited here and owned there.

### The four slots, as Effectiveness's values

- **`{{ARTIFACT_LIST}}`** for the Effectiveness dispatch is exactly this
  one line, shipped byte-for-byte in the same style
  `core/claim-verification.md` RC-29 ships Accuracy's two-line list —
  the input enumeration must be fixed for the detection branch below to
  be auditable:

  ```
  - The drafted README candidate under verification. No other input,
    including the repository under analysis, is permitted.
  ```

  This is the inversion that carries the gate's whole reason for
  existing: Accuracy's `{{ARTIFACT_LIST}}` additionally carries the
  repository under analysis, read only; Effectiveness's does not, and
  the denial is stated in the list itself, per RC-29's definition of
  "inversion" as a substitution of one enumerated `{{ARTIFACT_LIST}}`
  line.
- **`{{ITEMS}}`** is RC-33's five questions, verbatim, in the order
  above. Effectiveness receives no ledger-derived value at all: unlike
  Accuracy's `{{ITEMS}}` (`core/claim-verification.md` RC-29, three
  fields per claim), the dispatch never sees a claim id, a statement, or
  a content-class. Its records are keyed `q1` through `q5`, not a claim
  id.
- **`{{OUTPUT_GRAMMAR}}`** is one line per question, in the record
  grammar RC-31 defines:

  ```
  effectiveness|question|q<i>|<answered or unanswered>|<EVIDENCE>
  ```

  `EVIDENCE` carries the normalized excerpt on `answered` and the literal
  `none` on `unanswered` (RC-34 above, citing RC-31).
- **`{{VIOLATION_NOTE}}`** is unchanged from RC-29 — empty on the first
  dispatch, the detected violation's sentence on the single re-dispatch.
  What Effectiveness supplies is its own **contamination tell**, which
  follows directly from its `{{ARTIFACT_LIST}}` inversion above: because
  the permitted inputs are the draft and nothing else, a returned verdict
  is contaminated when it cites any repository path, symbol, or line —
  anything that is not text appearing in the draft. RC-29's detection
  branch condition 1 ("cites a path, symbol, or line that appears nowhere
  in that dispatch's `{{ARTIFACT_LIST}}` inputs") is the general rule;
  this is what it means for a dispatch whose `{{ARTIFACT_LIST}}` is the
  draft alone.

### Isolation: what is denied, and what is asserted

There is no in-harness per-dispatch permission mechanism in this plugin
(`core/claim-verification.md` RC-29), so this file states Effectiveness's
profile in the same terms: what holds by construction, and what is
asserted with a detector behind it. **Source access is denied for
Effectiveness, and the denial is asserted, detected, and not
mechanically enforced** — nothing in this plugin sandboxes the dispatched
subagent's tool use, so nothing prevents it from reading a repository
file the prompt did not permit. What exists instead is the tell above:
a subagent that reads outside the draft and cites nothing from what it
read is not detected, exactly as RC-29 already states for Accuracy's
read-only repository access. This file does not claim more than that.

### Consequence, and its five-record representation

`core/claim-verification.md` RC-29 owns the general consequence branch —
the discard, the single re-dispatch, and the `isolation not
demonstrated` reserved literal on a second contamination — cited here,
not restated. This section states only Effectiveness's own instance: on
that branch, Effectiveness emits exactly five records, one per question:

```
effectiveness|question|q1|unanswered|isolation not demonstrated
effectiveness|question|q2|unanswered|isolation not demonstrated
effectiveness|question|q3|unanswered|isolation not demonstrated
effectiveness|question|q4|unanswered|isolation not demonstrated
effectiveness|question|q5|unanswered|isolation not demonstrated
```

The five-record shape holds this section's own five-question invariant
(enforced by `scripts/check-verification-report.sh` RC-36) even on this
branch, `answered=0/5` follows, and Effectiveness reports `NEEDS WORK`
under the gate predicate below. This is the whole representation this
file adds: no reason field, no sixth record, no shared vocabulary with
Accuracy's own instance of the same branch.

### The Effectiveness gate predicate

Effectiveness reports `PASS` when and only when all five
`effectiveness|question` records in `.cartographer/verification-report.md`
carry the verdict `answered`. One `unanswered` record carries the gate to
`NEEDS WORK`: there is no partial credit and no threshold on four of
five. Because the dispatch always returns (or the consequence branch
above always synthesizes) exactly five records, this predicate is never
evaluated over an empty or partial set — there is no vacuous-`PASS` case
to guard here, unlike Accuracy's `dispatched=0` case
(`core/claim-verification.md` RC-32).

**A denial with no detection and no consequence is a gate a literal
executor satisfies by advancing past it.** This file's isolation claim
therefore stands on three things stated together, not on the prose
reading well in isolation: the denial (Effectiveness's
`{{ARTIFACT_LIST}}` carries no repository access), the detection tell
(any repository path, symbol, or line in a returned verdict, above), and
the consequence (discard, re-dispatch once, then the reserved `EVIDENCE`
literal and `NEEDS WORK`, above). A reader who finds only the denial has
not found this gate's whole force.

**Non-firing branch: a run that produced no draft.** `core/claim-verification.md`
RC-32 states the shared non-firing branch for both gates — stage 5
dispatches neither subagent, writes no verification report, and both
report blocks state `stage 5 not run: the run produced no draft`, with
both gates `NEEDS WORK`. This file adds nothing to that branch and cites
it rather than restating it.

### Whole-file, both modes

`core/refresh.md` § The accuracy dispatch covers the claims this run
wrote ledger rows for states, with its cost reasoning, exactly which
stages targeted mode skips and how the two stage-5 dispatches are scoped
differently; `core/claim-verification.md` RC-30 cites it for Accuracy.
This file states the Effectiveness half of that same asymmetry: the
effectiveness dispatch is never scoped to freshly drafted claims. It
reads the whole drafted README, once, on every run, in both full and
targeted mode — a newcomer reads the file a reader is handed, not the
diff a run produced. This is what keeps
`.cartographer/verification-report.md`'s five `question` records total
on every run, in either mode.

### Required contents of the `## Effectiveness` block of `.cartographer/report.md`

A report block is a named section of `.cartographer/report.md`
(`core/claim-verification.md` RC-32 states the same for `## Accuracy`,
and `core/pipeline.md` states where the two blocks sit and that they are
co-equal). The `## Effectiveness` block carries, on every run:

1. the gate's result, `PASS` or `NEEDS WORK`, as the `RESULT|effectiveness`
   line states it;
2. one entry per `effectiveness|question` record whose verdict is
   `unanswered`, naming the question's RC-33 text verbatim — never a
   paraphrase, never the bare `q<i>` subject alone;
3. the reserved literal `isolation not demonstrated`, carried verbatim as
   the gate's stated reason whenever it appears in an effectiveness
   record's `EVIDENCE`.

Deriving this block from the records at run time is
`skills/cartograph-report/SKILL.md` § Stage 5 in detail; the required
contents are fixed here so that derivation is mechanical rather than a
judgment call.

## Naming discipline: Effectiveness, never Completeness

The gate is named "Effectiveness" in every artifact this file and RC-31
define, and it is never renamed "Completeness" in shipped prose. Two
reasons this file states rather than assumes: `core/claim-model.md`'s
claim ledger already owns an unrelated notion of completeness (whether a
claim's evidence is sufficient), and
`core/references/context-file-effectiveness.md` is this plugin's own
grounding research and already uses "effectiveness" as its term of art
for this exact property. A headline that conflates accuracy with
completeness is the historical defect this naming corrects; reusing
"completeness" here would reintroduce it.

## Verification check

Before trusting an Effectiveness verdict or gate result, confirm every
one of these, and report the first that fails instead of the finding:

1. `{{ITEMS}}` carried exactly RC-33's five questions, verbatim and in
   order, and no ledger-derived value.
2. `{{ARTIFACT_LIST}}` carried exactly one line — the drafted README
   candidate — and no repository-access line.
3. Every `answered` record's `EVIDENCE` is a non-empty normalized excerpt
   (`core/claim-verification.md` RC-31) that can be located in the
   draft, and no `answered` record's `EVIDENCE` is the literal `none`.
4. Every `unanswered` record's `EVIDENCE` is exactly the literal `none`,
   unless it is the reserved literal `isolation not demonstrated` on the
   RC-29 consequence branch.
5. `.cartographer/verification-report.md` carries exactly five
   `effectiveness|question` records, one per `q1` through `q5`, on every
   run in both full and targeted mode.
6. Effectiveness reports `PASS` only when all five records are
   `answered`, and the `## Effectiveness` block lists every `unanswered`
   question's RC-33 text verbatim.
7. The RC-29 one-re-dispatch bound held (`core/claim-verification.md`),
   and a second contamination produced exactly the five-record
   representation above, never a partial substitution.
