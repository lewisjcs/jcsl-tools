# `core/` — Index

TL;DR: `core/` holds the generalized Cartographer workflow — the claim
model, the README ownership model, the pipeline, and the authoring
guidance those three draw on. Nothing here depends on a profile, and the
boundary is checked, not just asserted.

## Files

| File | What it owns |
|---|---|
| [claim-model.md](./claim-model.md) | The three evidence classes, the `unresolved-gap` disposition, the claim ledger, and the omit-and-report rule. Sole definition site for those terms. |
| [readme-ownership.md](./readme-ownership.md) | The ownership × freshness classification, the twelve-cell action matrix, and the managed-section marker grammar. Sole definition site for the ownership and freshness values. |
| [pipeline.md](./pipeline.md) | The five-stage sequence, the report contract, the repository-bound vs working-only artifact split, and the core/profile independence guarantee. |
| [knowledge/](./knowledge/) | Terse, always-loaded authoring guidance the core draws on while drafting. Every claim-bearing section carries one short marker. |
| [references/](./references/) | The fuller cited research behind `knowledge/`, loaded on demand only — never at drafting time. |

The local-validation contract (`local-validation.md`) is added by this
slice's local-validation task; `pipeline.md` stage 4 states the hand-off
it owns.

## The core never depends on a profile

The core runs its whole pipeline against a repository with no profile
integration configured, using repository-local evidence only, and
declares no required runtime dependency on any module under
`profiles/contentful/`. <!-- boundary-exempt: prose -->
It never assumes Glean, Backstage, a `catalog-info.yaml`, or a visibility
policy exists; a repository that has none of them is an ordinary subject,
not a degraded one.

A profile may add evidence sources and may narrow a core rule. It may not
weaken a core guarantee. The full statement, with its enforcement, is in
`pipeline.md`.

## Two vocabularies that both use the word "evidence"

They are unrelated, and no rule of one reaches the other:

1. **Claim evidence** — facts about the repository under analysis,
   classified by `claim-model.md`. This is what the pipeline collects and
   what a drafted claim cites.
2. **Evidentiary markers** — the short `see:` and `rationale:` comments
   that ground this plugin's own `knowledge/` files against its
   `references/` files. This is documentation hygiene for the files
   shipped here, not evidence about anyone's repository.

The marker forms are defined once, in
[knowledge/evidentiary-marker-conventions.md](./knowledge/evidentiary-marker-conventions.md).
The two literal forms, reproduced here for orientation only:

```markdown
<!-- see: references/<file>.md#<anchor> -->
<!-- rationale: documented internal decision, no external research available -->
```

A `see:` marker's path resolves relative to `core/`, never relative to
the directory of the file holding the marker, and its `#anchor` is
mandatory.

The managed-section markers
(`cartographer:managed:start` / `:end`) are a third, separate family,
owned by `readme-ownership.md`. Sharing the HTML-comment shape does not
make two families one.

## What the Slice 1 checks cover

| Check | Reads | Enforces |
|---|---|---|
| scripts/check-knowledge-grounding.sh | `knowledge/` and `references/` | A claim-bearing knowledge section carries a marker; full citations live in `references/`; a `see:` target and anchor resolve; a `rationale:` text is non-empty and cites no external source; every `references/` entry is indexed. |
| scripts/check-grounding-provenance.sh | `knowledge/` | The reference entry a `see:` marker cites was not committed after the knowledge line citing it, by line-level blame; landing together (as a squash merge does) passes. |
| scripts/check-core-profile-boundary.sh | Every `.md` file under `core/` | No line names the profile directory unless it carries the `boundary-exempt: prose` token, and no such line hides inside a fenced block. |

The contract files at the top of this directory are not scanned by the
grounding rules: those rules run against `knowledge/` and `references/`
only. The boundary check is the one that reads every file here, including
this one.

## Verification check

After editing any file in this directory, run all three checks above and
confirm each exits 0. A failure names the file and line; fix the named
file rather than the check.
