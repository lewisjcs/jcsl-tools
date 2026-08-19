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
rule, and the Tier-1 match predicates. It uses `core/claim-model.md`'s
claim ledger and evidence classes, `core/pipeline.md`'s stage sequence,
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
  whose target resolves under `REPO_ROOT` and does **not** end in `.md`.
  `<SUBJECT>` is the identifier text (everything before the first `(`).
- A **`self-citation` claim** is an inline code span that does not match
  the signature form and contains no `/`. Its cited document is the
  **first** markdown link on the same line whose target resolves under
  `REPO_ROOT` and **does** end in `.md`. `<SUBJECT>` is the code span's
  text — the cited term.

Non-firing branches, stated so a literal executor cannot improvise:

- A qualifying code span on a line with no qualifying link for its class
  emits **no record**.
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

## Verification check

Before trusting a content-class assignment or a Tier-1 finding, confirm
every one of these, and report the first that fails instead of the
finding:

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
