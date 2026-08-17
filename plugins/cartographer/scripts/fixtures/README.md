# Fixtures for Cartographer Checkers

This directory contains synthetic test inputs for the three cartographer checkers:
- `check-knowledge-grounding.sh` (rules a, b, c, c′, d)
- `check-grounding-provenance.sh` (ancestry-based ordering)
- `check-core-profile-boundary.sh` (boundary enforcement)

## Structure

```
fixtures/
  README.md                           # This file
  grounding/<case>/core/{knowledge,references}/…
  boundary/<case>/{core,profiles}/…
```

## Caveat: Synthetic test manifests

The `grounding/*/core/references/` fixtures contain synthetic `README.md` index files and minimal reference entries. These are test inputs only — they are not real shipped reference content, and the repo's `.github/workflows/` contains no corresponding synthetic files (a fixture workflow would never run, since CI reads workflows only from the repository root). Per RC-12, these synthetic manifests are permitted: the repo-root invariant in `CONTRIBUTING.md` § Prerequisites ("no `package.json`, no lockfile, no build system", "no CI pipeline") is unchanged.

Task 3 authors these fixtures. Task 6 adds only `readme-patch/` subdirectories and modifies nothing else here.
