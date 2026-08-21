# Cartographer

Repository cartographer — drafts a grounded, claim-classified README
enrichment for a repository, flagging unsupported or stale content
instead of guessing.

## Overview

Cartographer reads a repository's own evidence — tracked files,
manifests, CI configuration, and history — and turns it into a
claim-classified README draft or patch, or a report of what it could not
support. Every drafted claim carries a ledger row and an evidence
reference; a claim with none is omitted and reported, never rendered as
hedged prose. Cartographer ships the profile-independent
`skills/cartograph-report/core/` pipeline — evidence collection, a claim
ledger, drafting, local validation, and reporting — plus the ownership
rules that decide which README sections it may ever write, and
per-working-tree run state that lets a later run re-check only what
changed. A repository needs no external system for the core to run
against it; org-specific evidence sources are additions a distribution
can layer on through the `profile/` seam (`core/profile-contract.md`),
never core dependencies. The drafted output's verification is scoped, not
total — stated here rather than implied as measured. Path, command, and
`signature`/`self-citation` existence claims are mechanically verified.
Behavioral and semantic claims, `signature`/`self-citation` claims whose
verdict remains `plausible`, and `other`-class claims are flagged in the
run's report, not verified. The effectiveness evidence to date is
interactive dogfood runs on two real repositories, not a benchmarked
baseline against not using the tool — a run of this skill is not, by
itself, proof it improves outcomes.

## Prerequisites

Claude Code must already be installed — it is the only runtime this
plugin requires. See `CONTRIBUTING.md` § Prerequisites for the small set
of tools (`git`, `bash`) the plugin's own checkers assume are present.

## Installation

```bash
claude plugin install cartographer@jcsl-tools
```

Restart Claude Code after installing.

## Usage

Cartographer's entry point is the `cartograph-report` skill at
`plugins/cartographer/skills/cartograph-report/SKILL.md`. It auto-discovers
once the plugin is installed — no slash command or additional wiring is
required. Invoke it from a Claude Code session in the repository you want
oriented, onboarded, or reviewed for README drift; it reports a draft,
diff, and validation findings, and writes a patch only when explicitly
authorized.

This skill requires an interactive Claude Code session. It does not
support headless (`claude -p`) invocation: that path hits a harness
permission boundary the plugin cannot route around. Do not invoke this
skill from a headless `claude -p` run expecting a completed report.
Stage 5's verification dispatches require a harness with a conforming
dispatch mechanism (`core/dispatch-contract.md`); on any harness without
one the run stops at stage 5 and reports the missing capability by name.

Each run checks whether a previous run in the same working tree left
usable state. When it does, the run re-checks only the README sections
whose evidence or body changed since that run and carries the rest
forward (targeted mode); otherwise it re-assesses every section (full
mode) — including when no prior state exists, the state is unreadable
or malformed, or the change footprint since that run is too large. The
recorded state lives in a git-ignored, per-working-tree file; it is
never committed and never part of a patch.

## Architecture

The skill folder `skills/cartograph-report/` is self-contained — it is
the exact unit an external package manager can copy and ship
(`SKILL.md` + `core/` + `scripts/`, the "parity set"). Org-specific
content never lives here: a distribution adds it work-side through the
`profile/` seam that `core/profile-contract.md` defines, and
`scripts/check-core-neutrality.sh` mechanically keeps the shipped set
org-neutral. Test suites and fixtures live outside the skill folder in
`tests/` and never ship. Promotion into another catalog is a
deterministic copy: `tools/promote.sh` replaces the parity set at the
target and records the source commit in `PROVENANCE.md`; re-running it
at the recorded commit and diffing the parity set is the drift check.
See [ARCHITECTURE.md](ARCHITECTURE.md)'s Cartographer subsection for
how this plugin fits alongside the marketplace's other plugins.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a component to this
plugin and how to run its checks locally, including the Cartographer-specific
rows in its verification table.
