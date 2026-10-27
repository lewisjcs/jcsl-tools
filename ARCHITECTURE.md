# ARCHITECTURE.md

## What this repo is

`jcsl-tools` is a Claude Code **plugin marketplace**: a directory registered via `extraKnownMarketplaces` (or installed directly) that Claude Code reads to discover installable plugins. It is not an application — there is no server and no build step runs in this repo. Every plugin is a bundle of markdown (skills, agents) and shell, Python, and JavaScript components that Claude Code loads directly; gauntlet's runtime CLI among them, tracked as a pre-generated bundle (`plugins/gauntlet/runtime/bin/cli.mjs`) rather than built here.

```
jcsl-tools/
├── .claude-plugin/
│   └── marketplace.json      # marketplace manifest — lists all 6 plugins below
└── plugins/
    ├── kiln/                 # Kiln kickoff, build, and Classes (generated payload)
    ├── gauntlet/              # multi-skill review harness
    ├── prospector/            # discovery-first research harness
    ├── context-economy/       # context-spend discipline Party
    ├── cartographer/          # repository documentation cartographer
    ├── herald/                # plain-English output style, markdown nudge, rewrite skill
    └── _archive/kiln-2.17/    # the previous Kiln, kept whole, not listed
```

Each plugin directory is independently installable (`claude plugin install <name>@jcsl-tools`) and has its own `.claude-plugin/plugin.json` manifest, versioned independently of the others and of the marketplace manifest itself.

## Marketplace manifest vs. plugin manifest

Two different `.claude-plugin/plugin.json`-shaped files exist at two levels — don't conflate them:

| File | Scope | Key fields |
|---|---|---|
| `.claude-plugin/marketplace.json` | Whole repo | `plugins[]` array — one entry per installable plugin, each with its own `source` path |
| `plugins/<name>/.claude-plugin/plugin.json` | Single plugin | `name`, `version`, `description`, `author`, `license`, `keywords` |

A plugin's version is bumped independently in its own `plugin.json` — the marketplace manifest doesn't carry version numbers at all, only routing (`source`) and display metadata.

## The six plugins

### Kiln: kickoff, build, and Classes

`/kiln:kickoff` answers a question, explores an idea, or prepares a reviewed plan. It can call a Class directly when that Class's separate result helps. It stops before implementation. `/kiln:build` starts a separate Party run from an approved plan or ticket. The runtime chooses each next action, and the build skill performs the host call. `/kiln:shape` also opens the Designer without a run.

Kiln ships five Classes: Crafter, Designer, Planner, Inspector, and Prospector. Each Class has a manifest and an entry point on each host, Claude Code and Codex. The host skills are `kickoff`, `build`, `prospector`, and `shape`. The Codex portion of each skill lives under `runtime/hosts/codex/skills/`, and the shared skill sends a Codex session there. The Kiln packager copies those files, their references, the hooks, policy, and the bundled runtime from the merged Kiln source. `PROVENANCE.json` records the source commit and payload hash. Edit the canonical files in Kiln, then generate this payload again. The marketplace owns only `plugins/kiln/.claude-plugin/plugin.json`.

### Gauntlet — multi-skill review harness

Entry: `/gauntlet:run [<pr-url> | <path>] [--type <type>] [--full] [--go-live] [--no-go-live] [--force-lane <class>] [--skip-lane <class>]`. `--full` asks for a full re-review instead of a revision review.

Gauntlet is a thin host over a deterministic Party runtime (`runtime/bin/cli.mjs`). The runtime detects an artifact's type and picks the review lanes that fit it (the roster, read off `runtime/policy/roster-policy-v1.json`); the skill drives each lane the runtime fielded — today `adversarial-review`, `code-quality-audit`, `threat-review` (fielded on a security signal, runtime-driven), and, on a re-review of a pull request the gauntlet already posted for, `revision-review` (a single verifier that rules on the fate of every open prior finding), all runtime-driven Classes (a deterministic bundle → init → dispatch → receipt → result handshake) — and places the report the runtime wrote via `party-report`. Lanes the runtime does not yet field (`plan-review`, `doc-review`, `skill-audit`, `directive-review`, `go-live-review`) come back as typed gaps with the runtime's reason and are offered as operator-invoked follow-ups, never dispatched automatically; `--go-live` runs the go-live readiness lane. Most of those gap-lane skills still dispatch a **finder/validator pair** of agents in `agents/` — the finder proposes findings, the validator tries to disprove them, and only survivors reach the final report. `agents/check-grounding-parity.sh` verifies a shared sentinel-delimited contract block is byte-identical across those finder/validator agent files (6 typed finder/validator files across plan, doc, and directive review), so the "propose then adversarially verify" grounding rules can't silently drift between review lanes. `adversarial-review`, `code-quality-audit`, `threat-review`, and `revision-review` sit outside that parity script's checked set — their agents are vendored from the runtime bundle rather than authored to the sentinel-contract pattern.

Sibling skills (`code-quality-standards`, `doc-patterns`, `skill-authoring-principles`) are reference knowledge, not entry points — loaded by the domain skills, not invoked directly.

A decommissioned component moves to `_archive/` (e.g. `_archive/v1-adversarial-review/`, `_archive/v1-code-quality-audit/`) rather than being deleted — `_archive/` sits outside `skills/` and `agents/` plugin discovery, so it ships as inert bytes with zero trigger surface, kept for historical reference only.

### Prospector — discovery-first research harness

Entry: `/prospector:research`

The Prospector plugin has one research skill under `skills/research/`. It finds sources before it reads them, then checks claims and returns citations. Kiln's Prospector Class can call this skill by name when its brief does not name exact places to read.

### Context Economy — context-spend discipline Party

Not invoked via a slash command — its `context-economy` skill fires on a `<HARD-GATE>` matched by trigger phrases (long session, context filling up, about to grep broadly, etc.), routing to one of six "Classes":

| Class | Role | Artifact |
|---|---|---|
| Steward | Router — names the lever before high-token actions | `skills/context-economy` |
| Assembler | Scopes context before it hits the main thread | `skills/context-assembly` |
| Delegator | Pushes bounded work off-thread via a four-part dispatch contract | `skills/delegating-to-subagents` |
| Chronicler | Checkpoints before `/clear`; stamps the real session ID into each handoff file | `skills/handoff`, `hooks/handoff-stamp.sh` |
| Enforcer | Fires a mid-session handoff nudge + turn-count Stop backstop | `hooks/handoff-nudge.sh`, `hooks/context-reset-nudge.sh` |
| Observer | Records telemetry, surfaces cost/cache-read on the statusline | `hooks/telemetry-record.sh`, `hooks/cost-statusline.py` |

The `context-economy-retro` skill is a read-only retrospective over the recorded telemetry. It proposes advisory changes and never edits a skill or opens a PR.

`classes/*.class.json` are descriptive manifests (constraints, grounding citations, calibration fixture IDs) per Class — not executable config, just documentation of each Class's design rationale. `fixtures/` holds five operator-in-loop verification scenarios (`CE-01` through `CE-05`) with a `prompt.md`/`expected.md` pass-criteria pair each.

Context-economy was the first plugin with its own hook test suite (`*.test.sh` files alongside each hook script) and its own nested `README.md`/`SETUP.md`. Herald follows the same pattern with its own tests and `README.md`. Hooks that run unconditionally on every session deserve a heavier documentation footprint than plugins that run only on explicit invocation.

### Cartographer — repository documentation cartographer

Entry: `cartograph-report` skill (auto-discovered; no slash command)

Cartographer's pipeline reads a repository's own evidence — tracked files, manifests, CI configuration, and history — and turns it into a claim-classified README draft/patch, or a report of what it could not support. The skill folder `skills/cartograph-report/` is deliberately self-contained (`SKILL.md` + `core/` + `scripts/`): it is the promoted unit an external package manager copies whole, with provenance recorded by `tools/promote.sh` and org-neutrality of the shipped set enforced by `scripts/check-core-neutrality.sh`. Org-specific content enters only through the `profile/` seam defined in `core/profile-contract.md` — four fixed entry filenames that add evidence sources and conventions but can never override a core gate. `core/` holds the claim model, README ownership model, and six-stage pipeline; local validation (`scripts/check-readme-patch.sh`) and stage-5 verification (`scripts/check-verification-report.sh`) gate a draft before it is reported ready. Tests and fixtures live outside the skill folder in `tests/`, including a portability guard (`tests/check-portability.sh`) that keeps the skill folder free of harness-specific tokens.

### Herald — plain-English output style, markdown nudge, rewrite skill

Entry: none. The output style applies whenever the plugin is enabled (`force-for-plugin: true` in `output-styles/herald.md`), the PostToolUse hook runs after every markdown write, and the `herald` skill is auto-discovered.

Herald is one prose source for two registers: natural English for replies, and a stricter technical-writing register for a few named kinds of document. The source, `output-styles/herald.md`, holds both registers, with the stricter one covering README files, docs and runbooks folders, CHANGELOG files, and release notes. It is the plugin with three manifests: `.claude-plugin/` (output style, `hooks/hooks.json`), `.codex-plugin/` (skills and `hooks/hooks.codex.json`, whose SessionStart prints the style body through `hooks/herald-style.py`), and `.cursor-plugin/` (rules and skills; `rules/herald.mdc` is a byte-identical copy of the style body with Cursor frontmatter). `hooks/herald-lint.py` is a standard-library Python linter whose word lists, tier globs, and limits come from `hooks/rules.json`; `tests/check-rules-parity.sh` asserts the rules file, the style, and the Cursor rule agree. The hook returns `additionalContext` and exits 0 on every path, so it nudges and never blocks. Output styles never reach subagents, so the Kiln and Gauntlet Classes keep their own voice; the PostToolUse nudge does run on their markdown writes.

## Cross-plugin conventions

- **`${CLAUDE_PLUGIN_ROOT}`** is the only portable way to reference a plugin's own files from a hook command or agent instruction — every `hooks.json` in this repo uses it; a hardcoded or relative path breaks on any install method other than the exact local checkout. Cartographer's skill folder is the one deliberate exception: as a promoted unit that must run outside the plugin cache, it references its own files skill-root-relative and ships no environment-variable dependency — `tests/check-portability.sh` enforces this.
- **Progressive disclosure** — every plugin with a nontrivial skill (`kiln/build`, `prospector/research`) keeps its top-level `SKILL.md` thin and defers detail to sibling `.md` files loaded at specific points in the flow, not all upfront.
- **Standalone invocability** — a capability with its own use is its own entry point: the Kiln's Designer runs as `/kiln:shape "<idea>"` with no run, and the gauntlet's lanes run alone.
- **Finder/validator adversarial pairing** — Gauntlet's core review pattern: propose, then try to disprove, then report only what survives.

## Local, gitignored state (not part of the shipped artifact)

- `.worktrees/` — git worktrees created per the "always use worktrees for impl work" convention; ephemeral.
- `.superpowers/sdd/` — spec-driven-development scratch artifacts (task briefs/reports, review diffs) from past sessions; entirely gitignored (`*`).
