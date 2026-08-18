# Local Validation Contract

TL;DR: `check-readme-patch.sh` runs the three `spec-draft.md` § Local
validation gates against a drafted README patch — link resolution,
command existence, and low-value section flagging — plus the
managed-section marker-grammar gate that mechanically enforces
`readme-ownership.md`'s `<id>` rules, and reports every finding as one
stdout record in RC-8's fixed format. It is read-only: RC-9 makes
exclusion the caller's job, not the checker's.

This file is the sole definition site for the report format, the exit
codes, the external-tool allowlist, and the low-value proxy list. It uses
`core/pipeline.md`'s stage sequence and `core/claim-model.md`'s
`unresolved-gap` disposition, and defines neither.

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
<SEVERITY>|<RULE>|<FILE>:<LINE>|<SUBJECT>|<MESSAGE>
```

- `SEVERITY` ∈ `OK` | `GAP` | `LOW_VALUE` | `INFO`
- `RULE` ∈ `link` | `command` | `section-value` | `marker`
- `SUBJECT` = the link target, the command string, the section heading, or
  the marker id (`-` for a malformed marker line — see § Managed-section
  marker grammar below)
- The final line of every run is `SUMMARY|gaps=<n>|low_value=<n>`, where
  `<n>` counts exactly the `GAP` and `LOW_VALUE` records that run just
  emitted

## Exit codes

| Exit | Meaning |
|---|---|
| `0` | no `GAP` records. `LOW_VALUE` records may be present — the flag is advisory per `spec-draft.md` ("flag as low-value", not "reject") and the run completes |
| `1` | one or more `GAP` records: the caller must exclude those items before reporting the patch ready |
| `2` | usage or invocation error (missing/unreadable `README_FILE`, unusable `REPO_ROOT`) |

`LOW_VALUE` never changes the exit code. `GAP` always does. There is no
third path between them.

## The checker reports; the caller excludes (RC-9)

`check-readme-patch.sh` is read-only. It never rewrites `README_FILE` and
emits no filtered artifact — its only output is the stdout report above.
`spec-draft.md`'s "shall exclude it from the patch and report it as an
unresolved gap" is the **caller's** obligation:

> The skill shall not report a README patch ready while any `GAP` record
> exists for it. On exit 1 the skill shall remove the subject of each
> `GAP` record from the patch and carry that record verbatim into its
> unresolved-gaps report. A patch reported ready with an outstanding
> `GAP` record is a contract violation.

This is `core/pipeline.md` stage 4's hand-off, stated in the concrete
terms that stage promised: the checker's post-state is "reported as
`GAP`, exit 1"; "excluded and reported" is the caller's post-state. The
excluded item's ultimate disposition is `core/claim-model.md`'s
`unresolved-gap` — the same disposition a claim with no evidence
reference already carries, reached here by a different gate on a
different artifact (the draft, not the ledger).

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
`marker` records carry five fields and take no scope tag (Task 4's tag
is scoped to `link` and `command` findings only). Each increments
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
section records, because `scan_markers()` runs first in `MAIN`. This is
now a contractual ordering, not an incidental one — no existing
assertion in `check-readme-patch.test.sh` is order-sensitive, so this
change is safe.

**The well-formed-pair set.** `scan_markers()` also publishes, for
in-process callers of `check-readme-patch.sh` (Task 4's stage-4 scope
tag reads it), the set of marker pairs that popped cleanly with
byte-identical ids, emitted no `format` record on either marker, whose
id emitted no `uniqueness` record, and inside whose `[start_line,
end_line]` range no `nesting` record fired — the last clause also
excludes a pair whose own start triggered nesting, since that start
line is its own range's lower bound. A pair that produced any record is
not well-formed and is excluded from the set, even if its own `start`/
`end` pop was otherwise clean.

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
5. The marker-grammar gate mechanically enforces exactly four of the
   five `<id>` rules `readme-ownership.md` § Managed-section markers
   defines (format, uniqueness, matching, nesting) plus the two orphan
   conditions and the malformed-marker-line branch — never
   `derivation`, the deliberately-unenforced fifth rule, which stays a
   human-reviewer check per the gap note above.
