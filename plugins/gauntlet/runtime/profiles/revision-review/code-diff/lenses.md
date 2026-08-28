# Code-diff revision-review lenses

Applies when the artifact-family profile supplied for this run is
`jcsl:artifact-family:code-diff`. This overlay is read alongside the
revision-verifier persona and protocol; it does not repeat the three-fate
rule, only how to read this family's evidence.

## Reading a range-diff

A range-diff compares the pushed range against the range it replaces,
hunk by hunk. Three shapes appear:

- A hunk with no counterpart on the other side is the author's new work —
  read it as you would any diff hunk.
- A hunk whose only change is context lines shifting (line numbers move,
  the code on both sides is identical once whitespace-of-position is
  discounted) is a rebase artifact, not a change the author made. Do not
  treat it as evidence of anything.
- A hunk where both sides show real content changes is the author's edit
  to a line that also moved — read the content change; the position shift
  is incidental.

When the tool that produced the bundle cannot compute a true range-diff (a
force-push with no shared ancestor, for instance), the bundle's `primary`
component is the whole diff instead — treat every hunk as the author's
current work, since there is nothing to compare it against.

## Locating a prior finding's line in the revised tree

A prior finding's `file`/`line` was anchored against the tree at the time
it was raised. If the named file still exists in the revised tree, search
outward from the recorded line for the finding's cited code — a small
number of lines moved by an unrelated edit above it is normal. If the file
was renamed, follow the rename in the diff. If the code the finding cites
is gone from the file entirely, that is evidence toward `resolved`, not a
lookup failure — say what you found in its place.

## What counts as a test exercising the path

A test "exercises" a named failure mode when it calls the changed code on
the same input shape the finding described and asserts on the outcome the
finding said was wrong. A test that merely imports the changed file, or
that asserts on an unrelated branch of the same function, does not count.
Cite the test by name and file, the same as you would cite a code anchor.
