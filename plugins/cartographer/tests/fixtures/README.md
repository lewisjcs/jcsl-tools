# Fixtures for Cartographer Checkers

This directory contains synthetic test inputs for the cartographer checkers:
- `check-knowledge-grounding.sh` (rules a, b, c, c′, d)
- `check-grounding-provenance.sh` (entry-level blame ordering)
- `check-core-neutrality.sh` (org-neutrality enforcement)
- `check-readme-patch.sh` (link, command, low-value, marker-grammar, and Tier-1 claim gates)
- `check-verification-report.sh` (the stage-5 verification-report grammar and both gate predicates)

## Structure

```
fixtures/
  README.md                           # This file
  grounding/<case>/core/{knowledge,references}/…
  boundary/<case>/{core,profiles}/…
  readme-patch/<case>/README.candidate.md plus the repo files it cites
  readme-patch/marker-grammar/<case>/README.candidate.md
  accuracy-verification/<case>/verification-report.md
  effectiveness-verification/<case>/verification-report.md
```

One directory per case, named for the failure shape it carries. A
`readme-patch/` case is checked with its own directory as `REPO_ROOT`, so
its links resolve against the fixture subtree rather than this
repository's top level. An `accuracy-verification/` or
`effectiveness-verification/` case is a whole verification report: it
carries records for both gates and all three summary lines, because the
predicates under test range over the whole file.

## Caveat: Synthetic test manifests

The `grounding/*/core/references/` fixtures contain synthetic `README.md` index files and minimal reference entries. These are test inputs only — they are not real shipped reference content, and the repo's `.github/workflows/` contains no corresponding synthetic files (a fixture workflow would never run, since CI reads workflows only from the repository root). Per RC-12, these synthetic manifests are permitted: the repo-root invariant in `CONTRIBUTING.md` § Prerequisites ("no `package.json`, no lockfile, no build system", "no CI pipeline") is unchanged.
