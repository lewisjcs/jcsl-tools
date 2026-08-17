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
hedged prose. Slice 1 ships the profile-independent `plugins/cartographer/core/`
pipeline only: evidence collection, a claim ledger, drafting, local
validation, and reporting, plus the ownership rules that decide which
README sections it may ever write. A repository needs no external system
— no Glean, no Backstage, no `catalog-info.yaml` — for the core to run
against it; those are Contentful-profile additions layered on top, not
core dependencies. The drafted output's effectiveness is unproven pending
Slice 3's evaluation harness — this is stated explicitly rather than
implied as measured.

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

Cartographer's Slice 1 entry point is the `cartograph-report` skill at
`plugins/cartographer/skills/cartograph-report/SKILL.md`. It auto-discovers
once the plugin is installed — no slash command or additional wiring is
required. Invoke it from a Claude Code session in the repository you want
oriented, onboarded, or reviewed for README drift; it reports a draft,
diff, and validation findings, and writes a patch only when explicitly
authorized.

## Architecture

This plugin splits into a profile-independent core (`plugins/cartographer/core/`)
and a `profiles/` tree for system-specific adapters — Contentful's is a
Slice 1 placeholder, see `plugins/cartographer/profiles/contentful/README.md`.
`plugins/cartographer/core/README.md` states and mechanically enforces
the boundary between them; a profile may add evidence sources and narrow
a core rule, but it may never weaken a core guarantee. See the repo's own
[ARCHITECTURE.md](ARCHITECTURE.md) for how this plugin fits alongside the
marketplace's other plugins.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a component to this
plugin and how to run its checks locally, including the Cartographer-specific
rows in its verification table.
