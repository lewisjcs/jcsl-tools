# Evidentiary Marker Conventions

TL;DR: a claim-bearing section in `core/knowledge/` carries exactly one of
two short markers — a `see:` citation into `core/references/`, or a
`rationale:` tag for a documented internal decision with no external
research behind it. There is no third form.

This file is the sole source of truth for the evidentiary marker family.
It does not define the managed-section marker family
(`cartographer:managed:start`/`:end`) — that grammar belongs to
`core/readme-ownership.md`. The two families are unrelated; do not
conflate them.

## The two marker forms

A claim-bearing section must carry at least one marker, in one of exactly
two forms: a citation into a committed `core/references/` entry, or a
rationale tag documenting an internal decision. Never invent a third
form and never leave a claim-bearing section with zero markers. <!-- rationale: documented internal decision, no external research available -->

The two literal forms:

```markdown
<!-- see: references/<file>.md#<anchor> -->
<!-- rationale: documented internal decision, no external research available -->
```

## Path and anchor resolution (RC-4)

A `see:` marker's target path always resolves relative to `core/`, never
relative to the directory of the file that contains the marker. The
`#anchor` is mandatory: a path with no anchor, or an anchor that does not
match a heading in the target file, is unverified — the same failure
class as a missing target file, not a lesser warning. An anchor slug is
GitHub-style: lowercase the heading text, drop every character that is
not alphanumeric, a space, or a hyphen, then collapse each run of spaces
to a single hyphen. Never guess an anchor; take it from
`core/references/README.md`'s published slug list. <!-- rationale: documented internal decision, no external research available -->

## Citation vs. rationale (RC-5)

A `see:` marker is checked: its target file and anchor must resolve, or
the marker is flagged unverified. A `rationale:` marker is never checked
against a target, because it carries none by construction — its own
validity rule instead requires the text after `rationale:` to be
non-empty and to contain no URL and no arXiv ID. A rationale marker that
cites an external source is a citation in disguise; use `see:` and add
the entry to `core/references/` instead. <!-- rationale: documented internal decision, no external research available -->

## Verification check

Before committing a `core/knowledge/` file, confirm every claim-bearing
section carries a marker in one of the two forms above, then run
`bash plugins/cartographer/scripts/check-knowledge-grounding.sh` and
confirm it exits 0. A claim-bearing section with no marker is a defect in
the file, not the checker.
