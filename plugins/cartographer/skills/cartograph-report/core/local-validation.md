# Local Validation Contract

TL;DR: `check-readme-patch.sh` runs the three `spec-draft.md` § Local
validation gates against a drafted README patch — link resolution,
command existence, and low-value section flagging — plus the
managed-section marker-grammar gate that mechanically enforces
`readme-ownership.md`'s `<id>` rules and the two Tier-1 claim existence
gates `core/claim-verification.md` defines, and reports every finding as
one stdout record in RC-8's record format, tagging `link`, `command`,
`signature`, and `self-citation` findings `in-patch` or `out-of-patch`.
It is read-only: RC-9 makes exclusion the caller's job, not the
checker's.

This file is the sole definition site for the report format, the scope
tag, the rule for which records block patch readiness, the exit codes,
the external-tool allowlist, and the low-value proxy list. It uses
`core/pipeline.md`'s stage sequence, `core/claim-model.md`'s
`unresolved-gap` disposition, and `core/claim-verification.md`'s Tier-1
recognition rule (RC-27) and match predicates (RC-28), and defines none
of them.

## External-tool allowlist

Declared here, at the top, because RC-10 clause 5 depends on this list
being visible and auditable rather than a pattern buried in the script.
A documented command whose `argv[0]` is on this list is verified without
needing a `package.json` script or a CI match:

`claude` · `git` · `jq` · `bash` · `python3` · `shasum` · `sha256sum`

This is what makes `claude plugin install cartographer@jcsl-tools` — the
line every consumer of this plugin runs — verifiable in `jcsl-tools`
itself, which has neither a `package.json` nor a `.github/workflows/`
directory (verified in-session; stated in `CONTRIBUTING.md` §
Prerequisites and § Testing). Without this exemption, every command in
every README here — including the install line — would be an
unverifiable gap and the dogfood gate would be unpassable.

## Invocation (RC-6)

```
check-readme-patch.sh <README_FILE> [REPO_ROOT]
```

`REPO_ROOT` defaults to `git -C <dir of README_FILE> rev-parse
--show-toplevel`, falling back to the README's own directory when that
fails (no git available, or the directory is not a repository). Pass
`REPO_ROOT` explicitly when checking a fixture subtree — see
`scripts/fixtures/readme-patch/` — otherwise a fixture nested inside this
repository would resolve to `jcsl-tools`'s own top level instead of the
fixture's synthetic root.

## The report is stdout, one record per line (RC-8)

`check-readme-patch.sh` writes no file. Its validation report is stdout,
one record per line:

```
<SEVERITY>|<RULE>|<FILE>:<LINE>|<SUBJECT>|<MESSAGE>|<SCOPE>
```

- `SEVERITY` ∈ `OK` | `GAP` | `LOW_VALUE` | `INFO`
- `RULE` ∈ `link` | `command` | `section-value` | `marker` | `signature` |
  `self-citation`
- `SUBJECT` = the link target, the command string, the section heading,
  the marker id (`-` for a malformed marker line — see § Managed-section
  marker grammar below), the cited symbol (`signature`), or the cited
  term (`self-citation`)
- `SCOPE` ∈ `in-patch` | `out-of-patch`. Those two hyphenated lowercase
  tokens are the literals; nothing else is legal in the field
- The final line of every run is `SUMMARY|gaps=<n>|low_value=<n>`, where
  `<n>` counts exactly the `GAP` and `LOW_VALUE` records that run just
  emitted

**The field count varies by `RULE`, and this is the rule.** A record whose
`RULE` is `link`, `command`, `signature`, or `self-citation` carries
**six** fields, the sixth being `<SCOPE>`. A record whose `RULE` is
`section-value` or `marker` carries **five** and no scope tag. A consumer
reading `$5` still gets `<MESSAGE>` on every record, so a positional
reader written against the five-field form keeps working; only a reader
that assumes a fixed field count needs to change.

`signature` and `self-citation` records take the scope tag because they
are line-positional findings about content inside or outside the managed
region, exactly as `link` and `command` findings are. A `marker` record
is not: its line delimits the region rather than sitting in it.

The scope tag is on **every** severity, not only failures — an `OK|link`
record carries it exactly as a `GAP|link` record does. The criteria the
tag implements speak of "a `link` or `command` finding", and a tag present
only on failures would make the report inconsistent with itself.

It is a separate field rather than a suffix inside `<MESSAGE>` for three
reasons: `<MESSAGE>` is free prose that already contains colons and commas
(`not verified: no package.json script, no npm-builtin verb, …`), so a
machine-read enum inside it would force every consumer to parse prose,
where a sixth field is `cut -d'|' -f6`; RC-9's consumer must branch on
scope mechanically, and a substring search against prose this same
contract permits rewording is not a sound branch; and a varying field
count is a real cost that is better stated as a rule than discovered.

## Scope attribution (the `<SCOPE>` field)

A `link`, `command`, `signature`, or `self-citation` finding whose line
falls **within** a well-formed managed-section marker pair is tagged
`in-patch`. One whose line falls **outside every** well-formed pair is
tagged `out-of-patch`.

"Within" is strictly between: a finding at line `L` is `in-patch` when
`start_line < L < end_line` for some pair. Neither marker line is itself
`in-patch` — a marker line delimits the patch region rather than being
content inside it.

"Well-formed" is `readme-ownership.md`'s term, and it is the **same**
predicate gate (d) computes: the checker reads the pair set
`scan_markers()` publishes (§ The well-formed-pair set) and computes no
second notion of well-formedness. A malformed pair is not a managed
section (`readme-ownership.md`), so a finding enclosed by one is
`out-of-patch` — including a pair that popped cleanly with matching ids
but was withheld for a `format`, `uniqueness`, or `nesting` violation.

The tag is purely positional, and deliberately says nothing about
blocking. When a candidate contains no well-formed pair at all, every
`link`, `command`, `signature`, and `self-citation` record is
`out-of-patch` — there is no marked region for anything to be inside.
That case is handled by RC-9's blocking rule below, not by the tag.

## Exit codes

| Exit | Meaning |
|---|---|
| `0` | no `GAP` records. `LOW_VALUE` records may be present — the flag is advisory per `spec-draft.md` ("flag as low-value", not "reject") and the run completes |
| `1` | one or more `GAP` records. Exit 1 alone does not block a patch: the caller excludes the subject of every `in-patch` `GAP` record and reports every `out-of-patch` one. See RC-9 for the two cases where exit 1 does block — a candidate with no well-formed marker pair, in which every `GAP` blocks, and a `GAP` record whose `RULE` is `marker`, which always blocks and is resolved by repairing the marker line rather than by removing a subject |
| `2` | usage or invocation error (missing/unreadable `README_FILE`, unusable `REPO_ROOT`) |

`LOW_VALUE` never changes the exit code. `GAP` always does. There is no
third path between them. `GAP|marker` records and `out-of-patch` `GAP`
records both still force exit 1.

**Exit code and blocking are two different questions.** The exit code
answers "did this run find a gap"; blocking answers "may the caller
report this patch ready". Scope is what separates them, and only RC-9
answers the second.

## The checker reports; the caller excludes (RC-9)

`check-readme-patch.sh` is read-only. It never rewrites `README_FILE` and
emits no filtered artifact — its only output is the stdout report above.
`spec-draft.md`'s "shall exclude it from the patch and report it as an
unresolved gap" is the **caller's** obligation:

> The skill shall not report a README patch ready while any `GAP` record
> tagged `in-patch` exists for it, and shall not report one ready while
> any `GAP` record whose `RULE` is `marker` exists for it. On exit 1 the
> skill shall remove the subject of each `in-patch` `GAP` record from the
> patch and carry that record verbatim into its unresolved-gaps report. A
> `marker` record carries no scope tag and is never resolved by removing
> its subject: its subject is a marker id and its line is a delimiter of
> the patch region, not content inside it. The skill shall repair the
> marker line each `marker` record names when that line is one this run
> authored or modified in the candidate, and shall otherwise report the
> patch blocked and carry the record verbatim into its unresolved-gaps
> report — a marker line carried unchanged from the on-disk README belongs
> to a section this contract authorizes no write to. A `GAP` record whose
> `RULE` is `signature` or `self-citation` is dispositioned exactly as a
> `link` or `command` record is, and never as a `marker` record is: it
> carries a scope tag, so the skill shall remove the subject of each
> `in-patch` one from the patch and report each `out-of-patch` one. A
> `GAP` record tagged `out-of-patch` is carried into the report as an
> informational finding and never blocks patch readiness. When the
> candidate README contains no well-formed managed-section marker pair,
> every `GAP` record blocks: with no marked patch region, there is no
> out-of-patch exemption to claim. A patch reported ready in violation of
> any of these is a contract violation.

**The join to a claim id, on a `signature` or `self-citation` record.**
RC-6 is unchanged: the checker never reads the claim ledger, so a Tier-1
record carries no claim id and RC-8's six fields gain no seventh. The
record carries the unresolved reference in `<SUBJECT>` and its location
in `<FILE>:<LINE>`, and the join is the caller's:

> The skill shall join each `signature` and `self-citation` record to the
> ledger row whose drafted sentence occupies the line `<FILE>:<LINE>`
> names, and shall name that row's claim id alongside the record in its
> report.

Non-firing branch, stated so neither side is left to inference:

> When no ledger row's drafted sentence occupies the line a `signature`
> or `self-citation` `GAP` record names, the record does not join. The
> skill carries it into the report verbatim as an informational finding
> with no claim id and the note `no drafted claim on this line`, and
> never invents, substitutes, or guesses a claim id. An unjoinable record
> is by construction tagged `out-of-patch` — a line this run did not
> draft lies outside the managed region — so the out-of-patch rule above
> already makes it non-blocking **when the candidate carries at least one
> well-formed marker pair**. When it carries none, the absolute rule
> above wins over the out-of-patch exemption and every `GAP` record
> blocks, unjoinable or not; there is no marked region for the exemption
> to be claimed against. An `in-patch` record that does not join
> is a contract violation rather than a reporting case: every line inside
> the managed region was drafted by this run and has a ledger row
> (`core/claim-model.md` § The claim ledger, "A drafted sentence that has
> no ledger row is a contract violation"). The run reports the unjoinable
> `in-patch` record and does not report the patch ready.

**Why a candidate with no well-formed pair blocks on everything.**
"Out-of-patch" means "outside the region this run owns and is rewriting".
With no marked region, there is no exemption to claim, so the absolute
rule stands. This is what keeps the exemption from opening a hole on
exactly the first run against a repository that has never been
cartographed.

**Why a `GAP|marker` record always blocks.** The marker grammar is what
defines the patch region. While any marker in the file is broken, the
`in-patch` / `out-of-patch` tag on every other record is computed against
a region this contract cannot vouch for — so blocking is the only reading
consistent with gate (d) existing at all. This holds regardless of whether
the candidate contains well-formed pairs elsewhere.

**Which marker records the run may repair, and which it may not.** A
marker line this run authored or modified in the candidate is the run's
own output: the run repairs it, and re-running clears that record. A
marker line carried unchanged from the on-disk README is a pre-existing
defect the run did not introduce, and the run may **not** rewrite it — a
malformed marker means `readme-ownership.md`'s branch 1 does not fire, the
enclosing section classifies `unknown`, and the action matrix authorizes
no write to it. That record blocks, and the run reports the patch
**blocked** rather than looping.

**The loop therefore terminates.** Every pass either repairs a
run-authored marker line or removes an `in-patch` subject. Both sets are
finite and both strictly shrink. When neither shrinks, the run stops —
ready if the only remaining records are `out-of-patch` `GAP`s in a
candidate with at least one well-formed pair, blocked if any pre-existing
`marker` record remains.

This is `core/pipeline.md` stage 4's hand-off, stated in the concrete
terms that stage promised: the checker's post-state is "reported as
`GAP`, exit 1"; "excluded and reported" is the caller's post-state. The
excluded item's ultimate disposition is `core/claim-model.md`'s
`unresolved-gap` — the same disposition a claim with no evidence
reference already carries, reached here by a different gate on a
different artifact (the draft, not the ledger). What stage 4 hands the
reduced candidate and this report to is stage 5, which verifies the
claims that survived rather than re-deciding the findings above.

**A re-entry stage 5 sends back is an ordinary stage-4 run.** Stage 5
may return the caller here once per run, against a candidate it reduced
by excluding a disproved claim (`core/pipeline.md` § The stage sequence
names that bounded re-entry; `core/claim-verification.md` RC-32 owns its
sequence). Nothing on this side changes for it: RC-9 applies unchanged,
including the loop and the termination argument above, and the re-entry
rewrites this report. This file decides what a stage-4 run does with the
records it finds; it does not decide how many times stage 4 is entered,
and the two questions never conflict.

## Internal link resolution (gate a)

An **internal link** is a markdown `[text](target)` link whose target is
either:

- a path, resolved relative to `REPO_ROOT` (an absolute URL — any
  `scheme://` target, including `mailto:` — is out of scope for Slice 1:
  no network, so it is skipped and produces no record); or
- an anchor-only fragment (`#anchor`), resolved against the headings of
  `README_FILE` itself, using the same GitHub-style slug algorithm
  `check-knowledge-grounding.sh` uses for `see:` markers.

A link resolves when the path exists under `REPO_ROOT`, or the anchor
matches a heading slug in `README_FILE`. A link that does not resolve is
`GAP|link|<file>:<line>|<target>|…`. A resolving link is
`OK|link|<file>:<line>|<target>|…`. Markdown links inside fenced code
blocks are not scanned — a fenced example is not a navigable link.
A path target carrying a trailing `#anchor` is checked on its path
portion only; the anchor is not independently validated for this gate
(Finding 3 — match on resolvability and existence, not formatting).

## Documented command verification (RC-10)

A **documented command** is every non-blank, non-`#` line inside a fenced
block whose info string is `bash`, `sh`, `shell`, or `console`, with a
leading `$ ` stripped.

A documented command is **verified** if any of these holds, checked in
this order — the first clause that matches decides the report message:

1. its `argv[0]` is `npm`/`pnpm`/`yarn` with `run <name>` and `<name>` is
   a key under `.scripts` of a `package.json` at `REPO_ROOT` (disjoint
   from clause 2 — `run` is not in the clause 2 verb set);
2. its `argv[0]` is `npm`, `pnpm`, or `yarn` and the second token is
   `install`, `ci`, `audit`, `outdated`, `list`, or `prune` — npm
   built-in verbs that require no `package.json` script. These record
   `OK|command|…|npm-builtin` and are not gaps;
3. the command string appears verbatim in a file under
   `REPO_ROOT/.github/workflows/`;
4. it invokes a path that exists under `REPO_ROOT` (e.g. `bash
   plugins/…/check-x.sh`) — any whitespace-delimited token in the
   command that resolves under `REPO_ROOT` satisfies this clause;
5. its `argv[0]` is on the external-tool allowlist above. These record
   `OK|command|…|external-tool` and are not gaps.

A command matching none of the five is
`GAP|command|<file>:<line>|<command>|…`.

Checking in this fixed order means a command like `bash
plugins/cartographer/scripts/check-x.sh` — whose `argv[0]` (`bash`) is
also on the allowlist — is reported via clause 4 (in-repo path), not
clause 5, because clause 4 is checked first and is the more specific
finding. The `external-tool` tag is reserved for commands no clause but
5 resolves — the case the install line needs.

## Low-value section flagging (gate c, RC-11)

A drafted section (a `##`-heading block, up to the next `##` heading) is
flagged `LOW_VALUE` when it contains **none** of these four
machine-detectable proxies for `spec-draft.md`'s "command, path,
constraint, or routing rule". They are proxies, not the spec's own
terms — "constraint" and "routing rule" have no shell-detectable form, so
this states the mechanical stand-in the check actually looks for, rather
than pretending the check reads intent:

| Spec term | Machine-detectable proxy |
|---|---|
| command | a fenced block labeled `bash`/`sh`/`shell`/`console` within the section |
| path | an inline code span containing `/`, or a markdown link whose target has no `scheme://` (a repo-relative path) |
| constraint | a normative verb (`must`\|`shall`\|`never`\|`always`\|`required`\|`do not`, case-insensitive) or a digit sequence within 20 characters of `lines`\|`chars`\|`tokens`\|`%` |
| routing rule | `use when`\|`invoke`\|`route`\|`→`\|`->` (case-insensitive) on a line that also contains a `/` — approximating "names a path, skill, or slash command", all of which contain a `/` in their written form |

Proxies are detected outside fenced content only, with one exception: the
command proxy is the fence's own opening info string, so it is detected
at the point the section's fence opens, not by scanning inside it.

A section carrying at least one proxy gets no record — only the absent
case is reported, as `LOW_VALUE|section-value|<file>:<line>|<heading>|…`.
The flag is advisory: it never changes the exit code (see Exit codes
above), per `arXiv:2602.11988`'s finding that concrete instructions are
followed while generic overviews are unhelpful-but-costly — a signal
worth surfacing, not a reason to block a patch.

## Managed-section marker grammar (gate d)

`scan_markers()` runs **first** in `MAIN`, before gates (a)-(c), and
mechanically enforces four of the five `<id>` rules
`readme-ownership.md` § Managed-section markers defines: **format**,
**uniqueness**, **matching**, and **nesting**. It also detects the two
orphan conditions `readme-ownership.md:48-52` names as non-firing
branches for classification (`orphan-start`, `orphan-end`) and a
malformed-marker-line condition — a `cartographer:managed:start`/`:end`
HTML comment carrying zero or two id tokens instead of exactly one,
which matches neither well-formed marker pattern. It scans outside
fenced code blocks only, reusing the same fence-toggle idiom gate (a)
(`check_links`) already uses, so a marker shown inside a fenced
example is not treated as a live marker.

**`derivation` is not mechanically enforced.** `readme-ownership.md`'s
derivation rule ("the kebab-case slug of the section's heading text")
has no normative slugger this script can check against —
`make_slug()` is a GitHub *anchor* slugger, not a derivation function,
and can itself emit ids the `format` rule rejects. Nothing in
`readme-ownership.md` fixes which heading a start marker binds to,
either. Both are visible gaps, stated here in the same style
`readme-ownership.md` used for the whole grammar before this gate
shipped: `derivation` is checked by a human reviewer, not this script.

Every violation is one `GAP|marker|<file>:<line>|<id>|<message>` record.
`marker` records carry five fields and take no scope tag (§ Scope
attribution is scoped to `link` and `command` findings only). Each increments
`GAPS`, so a marker violation participates in the same exit-1
consequence as gates (a) and (b): the caller may not report the patch
ready while any `GAP|marker` record is outstanding (RC-9). A malformed
marker line's `<SUBJECT>` is always `-`, because its raw id-shaped text
is arbitrary and may itself contain `|`, which this pipe-delimited
grammar cannot carry.

The exact message strings, byte-for-byte:

| Rule | `<MESSAGE>` |
|---|---|
| format | `marker id violates the format rule: must match ^[a-z0-9]+(-[a-z0-9]+)*$ and be at most 64 characters` |
| format (malformed marker line) | `marker line violates the format rule: expected exactly one id token between the marker keyword and -->` |
| uniqueness | `marker id violates the uniqueness rule: id already used by a start marker at line <N>` |
| matching | `marker pair violates the matching rule: end id does not match the start id at line <N>` |
| nesting | `marker violates the nesting rule: a managed block opened at line <N> is still open` |
| orphan-start | `start marker has no matching end marker` |
| orphan-end | `end marker has no matching start marker` |

**Record order.** Marker records print before link, command, and
section records, because `scan_markers()` runs first in `MAIN`;
`signature` and `self-citation` records print after all of them, because
`check_claims()` runs last. This is a contractual ordering, not an
incidental one — no assertion in `check-readme-patch.test.sh` is
order-sensitive, so it costs nothing to state and gives a consumer a
stable read.

**The well-formed-pair set.** `scan_markers()` also publishes, for
in-process callers of `check-readme-patch.sh` (§ Scope attribution's tag
is its one reader), the set of marker pairs that popped cleanly with
byte-identical ids, emitted no `format` record on either marker, whose
id emitted no `uniqueness` record, and inside whose `[start_line,
end_line]` range no `nesting` record fired — the last clause also
excludes a pair whose own start triggered nesting, since that start
line is its own range's lower bound. A pair that produced any record is
not well-formed and is excluded from the set, even if its own `start`/
`end` pop was otherwise clean.

## Tier-1 claim existence proxies (gate e)

`check_claims()` runs **last** in `MAIN` and implements the two Tier-1
rules `core/claim-verification.md` defines: RC-27 fixes how a
`signature` or `self-citation` claim is recognized in the candidate's own
text, and RC-28 fixes the match predicate each rule applies against its
cited target, including the rule that an identifier is interpolated
literally and a dotted identifier is matched whole. This file defines
neither rule. What it defines is the records they emit: their `RULE`
literals, their field count, their scope tag, and their blocking
disposition.

The gate scans outside fenced code blocks only, reusing the same
fence-toggle idiom gates (a) and (d) use — a fenced example is not a
live claim, exactly as it is not a navigable link.

**A qualifying link's target must be a regular file**, which is a
stricter test than gate (a)'s. Gate (a) asks whether a link is
navigable, so a directory target resolves and records `OK|link`. Both
Tier-1 predicates instead read their cited target as a file, so a
directory is not a cited source or a cited document at all, and RC-27's
no-qualifying-link branch applies: no record. Accepting one would emit a
blocking `in-patch` `GAP` whose message asserts a symbol is absent from
a "cited source file" that is not a file.

Every finding is one six-field record, `<SCOPE>` included:

```
<SEVERITY>|signature|<FILE>:<LINE>|<SYMBOL>|<MESSAGE>|<SCOPE>
<SEVERITY>|self-citation|<FILE>:<LINE>|<TERM>|<MESSAGE>|<SCOPE>
```

`<SEVERITY>` is `OK` when the cited target satisfies RC-28's predicate
and `GAP` when it does not. The four `<MESSAGE>` strings are fixed
byte-for-byte by `core/claim-verification.md` RC-28's message table,
which is their sole definition site — they are cited here, not restated,
so the two files cannot drift.

Each `GAP` increments `GAPS`, so a Tier-1 finding participates in the
same exit-1 consequence as gates (a), (b), and (d), and RC-9 above
governs which of them block.

**These records carry no claim id, and that is the design, not an
omission.** RC-6 is unchanged: the checker reads the candidate README
and the repository, never the claim ledger — a checker that depended on
the ledger would break the property stage 4 rests on. RC-9's join clause
above is where a record reaches a claim id, and its non-firing branch is
where an unjoinable record goes.

**Both predicates are proxies for transcription, never semantic
verification**, in the same register § Low-value section flagging uses
for RC-11's proxy table. A cited document can contain the cited term
without stating the claimed rule, and a cited source can contain the
identifier without documenting the claimed behavior. That known gap is
Tier 2's territory, and `core/claim-verification.md` states it out loud
rather than implying a verification neither predicate performs.

## Verification check

Before a checker change is trusted, confirm every one of these:

1. `check-readme-patch.test.sh` passes every fixture in
   `scripts/fixtures/readme-patch/`, both the negative case and its
   pass-once-fixed counterpart.
2. Every `GAP` record in the suite is paired with exit 1 in the same
   invocation, and every invocation whose only records are `LOW_VALUE`
   still exits 0.
3. The external-tool allowlist above is exactly the list RC-10 fixes —
   adding or removing an entry here without a corresponding contract
   change is a scope violation, not a bug fix.
4. `bash plugins/cartographer/scripts/check-core-profile-boundary.sh`
   exits 0 (this file lives under `core/` and is subject to RC-7 like
   every other file there; it names no profile directory path, so no
   exemption token is needed).
5. Every `link`, `command`, `signature`, and `self-citation` record
   carries six fields whose sixth is `in-patch` or `out-of-patch`, on
   every severity, and every `section-value` and `marker` record carries
   five and no scope tag. Assert this whole-line — a substring assertion
   cannot see a field appended to or dropped from the end of a record.
6. The scope tag is computed from the well-formed-pair set defined in
   § The well-formed-pair set above and from nothing else. A pair that
   popped cleanly with matching ids but
   was withheld for a `format`, `uniqueness`, or `nesting` violation must
   leave its enclosed findings `out-of-patch`; a suite with no fixture of
   that shape cannot tell a correct tag from one computed against the
   merely-paired set.
7. The marker-grammar gate mechanically enforces exactly four of the
   five `<id>` rules `readme-ownership.md` § Managed-section markers
   defines (format, uniqueness, matching, nesting) plus the two orphan
   conditions and the malformed-marker-line branch — never
   `derivation`, the deliberately-unenforced fifth rule, which stays a
   human-reviewer check per the gap note above.
8. Every `signature` and `self-citation` record was recognized outside a
   fenced block, on a line carrying a qualifying link for its rule, and
   reproduces `core/claim-verification.md` RC-28's message table
   byte-for-byte. The suite proves each non-firing branch by a record
   **count**, not by presence: a fixture that repeats its own defective
   line inside a fenced block and a claim line carrying no qualifying
   link must both leave the count at one, and a presence assertion
   cannot see a duplicate.
9. The cited identifier was interpolated literally — every character
   outside `[A-Za-z0-9_]` backslash-escaped — and a dotted identifier
   was matched whole, with no last-segment fallback. Assert this with a
   case where a dotted identifier meets a same-shape-different-separator
   string in the cited source (`store.open` against a source containing
   `storeXopen`): it must be a `GAP`. Nothing else in a suite separates
   a literal interpolation from a raw one, because every undotted
   identifier behaves identically under both.
10. Every `signature` and `self-citation` `GAP` record reaching the
    report either names the claim id RC-9's join produced or carries the
    note `no drafted claim on this line`, and no patch was reported
    ready while an unjoinable `in-patch` record of either rule existed.
