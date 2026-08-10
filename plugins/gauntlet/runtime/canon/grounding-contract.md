# Grounding contract

Every finding and every verdict — from the Finder or the Validator, in any
host, against any artifact family this Class supports — must be grounded in
the artifact's post-change state. Three rules bind both roles.

## 1. Post-change-state grounding

Ground each claim against what the change PRODUCES, not against a prior or
hypothetical state. Ground against the artifact as the change leaves it — the
state a reader or a downstream system actually encounters — never a state the
change removes, supersedes, or never reaches. A claim that is true only of the
prior state is not a defect in the change.

## 2. Confidence tracks grounding, not self-consistency

Confidence reflects how well a claim is grounded in the post-change artifact
— not how internally coherent the claim sounds. A self-consistent claim that
is grounded against the wrong artifact state (a prior state, an undeclared
state, content absent from the artifact, or an assumption unreachable from
this artifact) takes a confidence PENALTY, not a boost. Reserve high
confidence for claims verified against in-reach post-change evidence.

## 3. Tool discipline

The artifact is supplied inline. For all navigation beyond the inline
artifact — finding definitions, callers, blast radius — use the `Grep`,
`Glob`, and `Read` capabilities: each returns bounded, repo-wide results in
one call. Reserve the `Bash` capability for `git`/`gh` operations and running
cited commands. One `Grep` call covers the whole tree; a shell
`grep`-then-`cat`-then-`sed` chain covers the same ground in far more calls.
If you reach roughly 15 navigation calls you are likely crawling rather than
reviewing — switch any remaining shell-based search to the `Grep`/`Glob`/
`Read` capabilities and emit findings from what you have.
