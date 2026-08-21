# Claim Model

TL;DR: every statement the core drafts about a repository is a claim, and
every claim carries either one evidence reference — classified as one of
three classes — or the `unresolved-gap` disposition, which keeps it out of
the draft and puts it in the report. There is no third outcome.

This file is the sole definition site for the three evidence classes and
the `unresolved-gap` disposition. Every other file under `core/` uses
these terms and defines none of them.

Throughout this file, **claim** means a statement the core would put into
a drafted README for the repository under analysis, and **evidence**
means a located fact about that repository. The evidentiary markers that
ground this plugin's own `core/knowledge/` files are an unrelated
mechanism with an unrelated vocabulary; see `core/README.md`.

## Term Definitions

| Term | Kind | Definition |
|---|---|---|
| `direct-repository-evidence` | evidence class | A reference to a fact read from the repository under analysis: a tracked file and location within it, a manifest key, a command in a tracked CI configuration, or a commit in its history. The reference names the artifact and the location, so a reader can re-read the fact without re-running collection. |
| `institutional-evidence` | evidence class | A reference to a fact recorded outside the repository, in a system of record supplied to the run. The core collects none of it and reaches no external system; the class exists so a profile may supply such a reference without changing the ledger's shape. |
| `inference` | evidence class | A reference to the repository-local facts a conclusion was drawn from, where the conclusion itself is stated in none of them. The class value is what makes an inferred claim distinguishable from a read fact in the ledger. |
| `unresolved-gap` | claim disposition | The disposition of a claim that has no evidence reference of any class. The claim is omitted from the draft and reported. |

The three evidence classes are exhaustive and mutually exclusive: an
included claim carries exactly one class value, never two and never none.
Disposition is binary — a claim carrying a classified evidence reference
is `included`, and a claim carrying none is `unresolved-gap`.

The requirement's four names map onto this table without addition or
loss: direct repository evidence, institutional evidence, and inference
are the three evidence classes; unresolved gap is the disposition of a
claim that has no reference at all. `unresolved-gap` is not a fourth
class, because it describes the absence of a reference rather than the
kind of one.

## The claim ledger

One row per claim, written before drafting and carried through the run:

| Field | Contents |
|---|---|
| claim id | Stable within the run; the draft and the report both cite it. Matches `^[A-Za-z0-9._-]+$`, so it is safe in the plugin's pipe-delimited record grammars. |
| subject | The drafted README section the claim would appear in. |
| statement | The claim text as it would be drafted, in the words the draft would use. |
| class | `direct-repository-evidence`, `institutional-evidence`, or `inference`. Empty only when disposition is `unresolved-gap`. |
| reference | The located evidence: path plus location, commit, or supplied record id. Empty only when disposition is `unresolved-gap`. |
| disposition | `included` or `unresolved-gap`. |
| content-class | `signature`, `self-citation`, `behavioral`, or `other`; assigned by `claim-verification.md`'s RC-26 procedure, once per row, at stage 2. Recorded on `included` rows only; empty when disposition is `unresolved-gap`. |

`claim-verification.md` is the sole definition site for the content-class
field's four values and the stage-2 procedure that assigns them to a
row; this table records only the field. Content-class is a separate
field on the same ledger row, not a fourth member of `class` — the three
evidence classes above stay exhaustive and mutually exclusive, and
content-class classifies a claim's *content* for verification routing,
an orthogonal question from *what evidence backs it*.

The ledger is the run's record of what it believed and why. It is a
working-only artifact and never enters a patch — see `core/pipeline.md`.

A drafted sentence that has no ledger row is a contract violation: the
core shall not report a draft ready while any sentence in it lacks a row,
and the run reports the unrowed sentence instead of the draft.

## Classifying a claim

Apply in order, once per claim, before the claim reaches the draft:

1. If a fact in the repository under analysis states the claim directly,
   the class is `direct-repository-evidence` and the reference names the
   file and location.
2. Otherwise, if a record supplied to the run from outside the repository
   states the claim, the class is `institutional-evidence` and the
   reference names that record. In a run with no such record supplied —
   the Slice 1 default — this branch never fires.
3. Otherwise, if repository-local facts support the claim without stating
   it, the class is `inference` and the reference names those facts.
4. Otherwise the disposition is `unresolved-gap`.

Non-firing branches, stated so a literal executor cannot improvise:

- A claim never carries two classes. Where branches 1 and 3 would both
  apply, branch 1 wins because it fires first, and the inferred reading
  is not recorded as a second claim about the same fact.
- An `inference` row whose reference names no repository-local fact is
  not an inference; its disposition is `unresolved-gap` and it is omitted
  and reported like any other unreferenced claim.
- Confidence does not enter the classification. There is no
  low-confidence path that lets an unreferenced claim into the draft.

## Omit and report

A claim with disposition `unresolved-gap` shall be omitted from the draft
and reported as an unresolved gap, never rendered as established fact and
never rendered as hedged prose. "The project appears to use X" is the
same violation as "The project uses X": both put an unreferenced claim in
front of a reader.

Consequence and failure branch: a draft containing a sentence whose
ledger row has disposition `unresolved-gap` is not reported ready. The
core removes the sentence and carries the ledger row into the report's
unresolved-gaps list. A run that cannot produce a draft after removals
reports the gaps and produces no draft, which is a complete run and not a
failure.

Inferred claims stay visible after drafting: the report lists every
included claim whose class is `inference` alongside its reference, so a
reader can tell inferred content from read content without opening the
ledger. A report that omits that list is not a valid report.

## When evidence contradicts

Collected evidence sometimes contradicts a claim rather than supporting
or missing it. The contradiction never silently drops:

- **A drafted claim contradicted by collected evidence** is not included.
  The contradicting evidence produces a replacement claim, classified by
  the procedure above. If no replacement claim can be supported, the
  original claim's disposition is `unresolved-gap` — omitted and
  reported, not corrected by guesswork.
- **A claim in an existing README section contradicted by collected
  evidence** additionally sets that section's freshness value; the
  classification and the action that follows from it are defined in
  `core/readme-ownership.md`. Contradiction is a freshness signal about
  the section and a disposition signal about the claim, and both fire.
- **Evidence that contradicts itself** — two repository-local facts that
  cannot both hold — supports neither reading. Both readings are
  `unresolved-gap` and the report names the conflicting locations.

## Verification check

Before a draft is reported ready, confirm every one of these, and report
the first that fails instead of the draft:

1. Every sentence in the draft has a ledger row whose disposition is
   `included`.
2. Every `included` row carries exactly one class value and a non-empty
   reference.
3. Every `unresolved-gap` row appears in the report's unresolved-gaps
   list and nowhere in the draft.
4. Every `included` row whose class is `inference` appears in the
   report's inferred-claims list.
5. Every `included` row carries exactly one content-class value assigned
   by `claim-verification.md`'s RC-26 procedure, and every
   `unresolved-gap` row's content-class is empty.
