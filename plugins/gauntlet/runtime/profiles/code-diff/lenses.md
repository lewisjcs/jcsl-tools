# code-diff profile

Applies when the artifact-family profile supplied for this run is
`jcsl:artifact-family:code-diff`. Read this alongside the family-neutral
personas and grounding contract — it refines what counts as a finding under
each lens and how the Validator disproves one, for a code diff specifically.

## Finder application

### Post-image anchoring

Before emitting a finding, confirm its evidence appears on the `+`
(post-image) side of a hunk. A finding whose only supporting evidence is on
the `-` (pre-image) side describes code the change REMOVES — it is a
pre-image false positive. Reject it; do not emit it. When a hunk both removes
and adds lines, anchor the finding to the `+` lines that remain after the
change.

### Lens applications

- **Hidden Assumptions** — type contracts, caller behavior, and ordering
  guarantees the diff relies on without enforcing them: missed edge cases,
  race conditions, error paths silently swallowed, unbounded inputs, type
  confusions, off-by-one errors in cursor-based pagination, and the like.
- **Failure Scenarios** — concurrency, partial failure, timeout, retry
  storms, data-shape variance.
- **Blast Radius** — downstream consumers, shared state, rollback safety.

### Location format

`file:line` — the post-diff source file path and line number. Cite the `+`
side of the hunk, or the surviving `+` lines when a hunk both removes and
adds.

Get the file path from the component's own header, never by guessing or
inferring one from content: each component you are shown is introduced by a
`--- component: <id> (role: ..., mediaType: ..., path: <path>) ---` line.
When that header states a `path`, use it verbatim as the file in `file:line`.
Only when a component's header carries no `path` — a rare case, since a real
code-diff bundle names its file — fall back to `(<component id>):line`
instead of inventing a path.

## Validator disproof strategies

1. Can the type system, framework, or runtime guarantee this can't happen?
2. Does the surrounding code already handle this case?
3. Is this theoretical, or realistic given how the code is actually used
   under real traffic patterns?
4. Read source files beyond the diff to verify, per the grounding contract's
   tool-discipline rule.

### Grounding-quality adjudication

Self-consistency is not evidence. When an incoming finding's reasoning is
internally coherent but its grounding points at the wrong artifact state —
the pre-image (`-` side) of a hunk, an installed-not-declared dependency
version, or a file or line absent from the post-change artifact — that
mis-grounding is itself a disproof basis. Mark the finding `disproved` as a
grounding false positive and name the wrong-state grounding in `evidence`.
Self-consistency is never grounds to raise confidence.

### False-positive rules

Findings that recommend any of the following against typed values are false
positives by team convention (see `references/code-quality-standards.md`):
adding null/undefined guards where the type system already excludes them,
wrapping framework operations in defensive try/catch, backwards-compatibility
shims for unreleased breaking changes, or validation at internal boundaries.
