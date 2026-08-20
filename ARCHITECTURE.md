# ARCHITECTURE.md

## What this repo is

`jcsl-tools` is a Claude Code **plugin marketplace**: a directory registered via `extraKnownMarketplaces` (or installed directly) that Claude Code reads to discover installable plugins. It is not an application — there is no server and no build step runs in this repo. Every plugin is a bundle of markdown (skills, agents) and shell, Python, and JavaScript components that Claude Code loads directly; gauntlet's runtime CLI among them, tracked as a pre-generated bundle (`plugins/gauntlet/runtime/bin/cli.mjs`) rather than built here.

```
jcsl-tools/
├── .claude-plugin/
│   └── marketplace.json      # marketplace manifest — lists all 5 plugins below
└── plugins/
    ├── kiln/                 # implementation workflow Party
    ├── gauntlet/              # multi-skill review harness
    ├── prospector/            # discovery-first research harness
    ├── context-economy/       # context-spend discipline Party
    └── cartographer/          # repository documentation cartographer
```

Each plugin directory is independently installable (`claude plugin install <name>@jcsl-tools`) and has its own `.claude-plugin/plugin.json` manifest, versioned independently of the others and of the marketplace manifest itself.

## Marketplace manifest vs. plugin manifest

Two different `.claude-plugin/plugin.json`-shaped files exist at two levels — don't conflate them:

| File | Scope | Key fields |
|---|---|---|
| `.claude-plugin/marketplace.json` | Whole repo | `plugins[]` array — one entry per installable plugin, each with its own `source` path |
| `plugins/<name>/.claude-plugin/plugin.json` | Single plugin | `name`, `version`, `description`, `author`, `license`, `keywords` |

A plugin's version is bumped independently in its own `plugin.json` — the marketplace manifest doesn't carry version numbers at all, only routing (`source`) and display metadata.

## The five plugins

### Kiln — complexity-proportionate implementation Party

Entry: `/kiln EXT-NNNN | /kiln "raw idea" | /kiln EXT-NNNN path/to/plan.md`

Kiln is a **thin conductor** (`skills/fire/SKILL.md`) that routes work through lanes (EXECUTE / PLAN / TRIVIAL / RESUME / DESIGN / RESEARCH / REVIEW) and dispatches specialized members — it never edits source itself. A plugin `PreToolUse` hook (`hooks/kiln-guard-conductor.sh`) enforces this at the tool layer: while a run's `.active` sentinel is present, the conductor's file-editing tools (Edit/Write/MultiEdit/NotebookEdit) and Compounds mutation calls are denied in the main thread. Two more guards run alongside it: `kiln-guard-branch.sh` (branch discipline) and `kiln-guard-spine.sh` (progress-spine discipline on every `Agent` dispatch).

**Members** (each a subagent in `agents/`, dispatched by the conductor — never self-invoking):

| Member | Role |
|---|---|
| `designer` | Design-dialogue partner for fuzzy/net-new requirements (DESIGN/RESEARCH lanes) |
| `scout` | Parallel research sweep for sparse tickets — reports gaps, never guesses |
| `planner` | Runs Compounds `plan_change`/`generate_tasks`, writes `tasklist.md` + `plan.md` |
| `walker` | HIGH-blast-only: role-plays executing the plan, surfaces ambiguity before code is written |
| `crafter` | Per-task implementation over the run's bound engine (`compounds` or `native`) |
| `inspector` | Per-task adversarial test-adequacy/spec-compliance review after each crafter |
| `curator` | Run-level close-out — `/verify`, closes Compounds project, opens the PR, transitions Jira |
| `drafter` | Renders an agreed spec into the ticket's team-format + EARS description |
| `sifter` | Read-only PR-review-comment triage (accept/push-back/needs-clarification) |
| `finisher` | Gated outward-write close-out for the review-feedback flow — posts replies, re-requests review |

**Engine binding:** every run binds one engine at classify time — `code` scenarios bind Compounds (MCP-driven plan/implement/verify loop via `mcp__compounds-dev__*` tools), `tool-authoring`/`doc` scenarios bind `native` (deterministic self-check, no Compounds call). The contract for both is `skills/fire/engines.md`, loaded by `crafter` and `planner`.

**Progressive disclosure:** `skills/fire/SKILL.md` is deliberately thin — `lanes.md`, `scenarios.md`, `gates.md`, `dispatch-contracts.md` load on demand at specific verbs, not all at once. This keeps the conductor's own context footprint small across a long-running multi-member dispatch.

`skills/smith/` is a separate, read-only retrospective skill (`/smith`) — reads past Kiln run ledgers and briefs on accuracy/friction/cost; it proposes, never edits. Its local-Langfuse dev setup lives in `skills/smith/langfuse/` (gitignored `.env`, tracked `docker-compose.yml`).

`skills/process-review-feedback/` and `skills/spec-ticket/` are standalone-invocable skills that also compose into the conductor's REVIEW lane and Drafter checkpoints respectively — per the repo's "every capability is standalone-invocable, the conductor is one caller" principle.

### Gauntlet — multi-skill review harness

Entry: `/gauntlet [<pr-url>|<path>|<directory>] [--go-live] [--security] [--doc-body] [--type <type>]`

Gauntlet detects an artifact's type (`code-pr`, `code-local`, `plan`, `doc`, `skill`, `directive`, `multi`) from path/content signals and routes it to the matching domain skill: `code-quality-audit` + `adversarial-review` for code diffs, `plan-review` for plans, `doc-review` for docs, `skill-audit` + `directive-review` for skill/directive prose, `security-gauntlet` always runs a second pass on every type. Most domain skills dispatch a **finder/validator pair** of agents in `agents/` — the finder proposes findings, the validator tries to disprove them, and only survivors reach the final report. `agents/check-grounding-parity.sh` verifies a shared sentinel-delimited contract block is byte-identical across those finder/validator agent files (8 typed finder/validator files across plan, doc, security, and directive review), so the "propose then adversarially verify" grounding rules can't silently drift between review lanes. `adversarial-review` and `code-quality-audit` are the exception: both run as runtime-driven Classes (a deterministic bundle → init → dispatch → receipt → result handshake) rather than the sentinel-contract pattern, so their agents sit outside the parity script's checked set.

Sibling skills (`code-quality-standards`, `security-principles`, `doc-patterns`, `skill-authoring-principles`) are reference knowledge, not entry points — loaded by the domain skills, not invoked directly.

A decommissioned component moves to `_archive/` (e.g. `_archive/v1-adversarial-review/`, `_archive/v1-code-quality-audit/`) rather than being deleted — `_archive/` sits outside `skills/` and `agents/` plugin discovery, so it ships as inert bytes with zero trigger surface, kept for historical reference only.

### Prospector — discovery-first research harness

Entry: `/prospector:research`

Smallest plugin (~290 lines total): one skill (`skills/research/`) implementing a discover → deepen → verify → synthesize method across Glean, GitHub, Jira, and the web. `sources.md`, `method.md`, and `output-shapes.md` load progressively rather than all at once, same discipline as Kiln's `fire` skill.

### Context Economy — context-spend discipline Party

Not invoked via a slash command — its `context-economy` skill fires on a `<HARD-GATE>` matched by trigger phrases (long session, context filling up, about to grep broadly, etc.), routing to one of six "Classes":

| Class | Role | Artifact |
|---|---|---|
| Steward | Router — names the lever before high-token actions | `skills/context-economy` |
| Assembler | Scopes context before it hits the main thread | `skills/context-assembly` |
| Delegator | Pushes bounded work off-thread via a four-part dispatch contract | `skills/delegating-to-subagents` |
| Chronicler | Checkpoints before `/clear` | `skills/handoff` |
| Enforcer | Fires a mid-session handoff nudge + turn-count Stop backstop | `hooks/handoff-nudge.sh`, `hooks/context-reset-nudge.sh` |
| Observer | Records telemetry, surfaces cost/cache-read on the statusline | `hooks/telemetry-record.sh`, `hooks/cost-statusline.py` |

`classes/*.class.json` are descriptive manifests (constraints, grounding citations, calibration fixture IDs) per Class — not executable config, just documentation of each Class's design rationale. `fixtures/` holds five operator-in-loop verification scenarios (`CE-01` through `CE-05`) with a `prompt.md`/`expected.md` pass-criteria pair each.

This is the only plugin with its own hook test suite (`*.test.sh` files alongside each hook script) and its own nested `README.md`/`SETUP.md` — a heavier documentation footprint than the other plugins in this repo, reflecting that it ships hooks that run unconditionally on every session rather than only on explicit invocation.

### Cartographer — repository documentation cartographer

Entry: `cartograph-report` skill (auto-discovered; no slash command)

Cartographer's pipeline reads a repository's own evidence — tracked files, manifests, CI configuration, and history — and turns it into a claim-classified README draft/patch, or a report of what it could not support. The skill folder `skills/cartograph-report/` is deliberately self-contained (`SKILL.md` + `core/` + `scripts/`): it is the promoted unit an external package manager copies whole, with provenance recorded by `tools/promote.sh` and org-neutrality of the shipped set enforced by `scripts/check-core-neutrality.sh`. Org-specific content enters only through the `profile/` seam defined in `core/profile-contract.md` — four fixed entry filenames that add evidence sources and conventions but can never override a core gate. `core/` holds the claim model, README ownership model, and six-stage pipeline; local validation (`scripts/check-readme-patch.sh`) and stage-5 verification (`scripts/check-verification-report.sh`) gate a draft before it is reported ready. Tests and fixtures live outside the skill folder in `tests/`, including a portability guard (`tests/check-portability.sh`) that keeps the skill folder free of harness-specific tokens.

## Cross-plugin conventions

- **`${CLAUDE_PLUGIN_ROOT}`** is the only portable way to reference a plugin's own files from a hook command or agent instruction — every `hooks.json` in this repo uses it; a hardcoded or relative path breaks on any install method other than the exact local checkout. Cartographer's skill folder is the one deliberate exception: as a promoted unit that must run outside the plugin cache, it references its own files skill-root-relative and ships no environment-variable dependency — `tests/check-portability.sh` enforces this.
- **Progressive disclosure** — every plugin with a nontrivial skill (`kiln/fire`, `prospector/research`) keeps its top-level `SKILL.md` thin and defers detail to sibling `.md` files loaded at specific points in the flow, not all upfront.
- **Standalone invocability** — every Kiln capability (Drafter via `/spec-ticket`, Smith via `/smith`) is independently invocable outside the conductor, not conductor-only.
- **Finder/validator adversarial pairing** — Gauntlet's core review pattern: propose, then try to disprove, then report only what survives.

## Local, gitignored state (not part of the shipped artifact)

- `.compounds/` — Compounds MCP's local project/task state for whichever repo the conductor is currently bound to; regenerated per machine, never committed.
- `.worktrees/` — git worktrees created per the "always use worktrees for impl work" convention; ephemeral.
- `.superpowers/sdd/` — spec-driven-development scratch artifacts (task briefs/reports, review diffs) from past sessions; entirely gitignored (`*`).
- `plugins/kiln/skills/smith/langfuse/.env` / `local.env` — local Langfuse credentials for Smith's cost-analysis dev loop.
