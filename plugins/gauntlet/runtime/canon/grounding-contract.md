# Grounding contract

Every claim a role emits — from any role in this Class, in any host,
against any artifact family this Class supports — must be grounded in the
artifact's post-change state. Three rules bind every role.

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

The Class's protocol states how the artifact reaches a role. It arrives inline
in the dispatch or by reference to a bundle it reads. Start with the supplied
artifact. For navigation beyond it, name the symbol or relationship that
requires the read, then use `Grep`, `Glob`, or `Read` with a path or search
pattern tied to that question. A repository-wide search needs a specific
symbol and bounded output. Reserve `Bash` for `git`/`gh` operations and
running cited commands.

When `Bash` does carry a read or a search, write every path in absolute form
and never start the command with `cd`: a relative path resolves against a
working directory the host does not guarantee, and a `cd` can force an approval
stop mid-run.

If you reach roughly 15 navigation calls, stop expanding the tree. State the
unresolved question from the artifact and finish with findings supported by
the evidence already read. A broad scan is not evidence of an integration
unless the changed code creates a path to what the scan found.

Never modify the tree under review. It may be the operator's live working
tree, with uncommitted work in it; do not `git stash`, `checkout`, or
`reset`, and do not edit, comment out, or otherwise mutate a file to see
what a test does without it.

The dispatch prompt carries one line, `Origin authorship: self` or
`Origin authorship: other`, saying whose change this is. On a `self` origin
the change is this repository's own work and you may run its tests, type
checker, and linter as the tree stands. On an `other` origin the change
came from outside: read its tests, never run them, because executing a
stranger's test is executing a stranger's code. Only the flag reaches you;
the author's identity never does. A check you would need to run on an
`other` origin, or would need to mutate the tree to perform, is not
performed — say so in the finding instead of guessing its result.

## Evidence hierarchy

When grounding or disproving a claim, prefer stronger evidence classes over
weaker ones: execution (run the code path) over independent re-derivation
(recompute the claim from source without assuming it), re-derivation over
citation (quote the line that says it), citation over deliberation (argue
that it is plausible). Reach for the strongest class the artifact and your
tools allow before settling for a weaker one.

Agreement is not evidence. Any number of passes, roles, or models endorsing
the same claim raises no evidence class; only verification does.
