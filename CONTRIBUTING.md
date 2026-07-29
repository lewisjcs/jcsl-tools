# CONTRIBUTING.md

## Prerequisites

| Tool | Notes |
|---|---|
| Claude Code | The only runtime — plugins here are markdown + shell/Python, no compile step |
| `jq` | Required by `context-economy`'s hooks (`telemetry-record.sh`, `handoff-nudge.sh`, `context-reset-nudge.sh`) |
| `python3` | Required by `context-economy/hooks/cost-statusline.py` (stdlib only, no pip installs) |
| `gh` (GitHub CLI) | Used by Kiln's Curator (PR creation) and Gauntlet (`code-pr` mode metadata) |
| `bash` + `shasum`/`sha256sum` | Required by `gauntlet/agents/check-grounding-parity.sh` |

No `package.json`, no lockfile, no build system — there is nothing to `npm install`.

## Getting Started

```bash
git clone git@github.com:lewisjcs/jcsl-tools.git
cd jcsl-tools
```

Register the repo as a local marketplace in `~/.claude/settings.json`:

```json
"extraKnownMarketplaces": {
  "jcsl-tools": {
    "source": { "source": "directory", "path": "/absolute/path/to/jcsl-tools" }
  }
}
```

Then install the plugin(s) you're working on:

```bash
claude plugin install kiln@jcsl-tools
claude plugin install gauntlet@jcsl-tools
claude plugin install prospector@jcsl-tools
claude plugin install context-economy@jcsl-tools
```

Restart Claude Code after installing or after any change to a `hooks.json` or `plugin.json` — component and hook registration happens at plugin-enable time, not live.

## Adding a component to an existing plugin

- **New skill** → `plugins/<plugin>/skills/<skill-name>/SKILL.md`, kebab-case directory name, required YAML frontmatter (`name`, `description`). Auto-discovered — no manifest edit needed.
- **New agent** → `plugins/<plugin>/agents/<agent-name>.md`, required frontmatter (`name`, `description`, `tools`, `model`). Auto-discovered.
- **New hook** → add to the plugin's `hooks/hooks.json`; reference the script via `${CLAUDE_PLUGIN_ROOT}/hooks/<script>`, never a hardcoded or relative path.
- **New plugin entirely** → add a `plugins/<name>/.claude-plugin/plugin.json` (see any existing plugin for the shape), then add a matching entry to the root `.claude-plugin/marketplace.json` `plugins[]` array pointing `source` at `./plugins/<name>`.

## Testing

There's no repo-wide test command — verification is per-component, where a component has it:

| Component | Verify with |
|---|---|
| Kiln guard hooks | `bash plugins/kiln/hooks/test-kiln-guards.sh` — offline unit tests, feeds synthetic `PreToolUse` stdin JSON to each guard and asserts allow/deny. No Claude session needed. |
| Gauntlet finder/validator agents | `bash plugins/gauntlet/agents/check-grounding-parity.sh` — asserts the shared grounding-contract sentinel block is byte-identical across all 10 agent files. |
| Context Economy hooks | `bash plugins/context-economy/hooks/<hook-name>.test.sh` for each of `cost-statusline`, `telemetry-record`, `handoff-nudge`, `context-reset-nudge`. Exits non-zero on any failure. |
| Context Economy behavioral fixtures | Five operator-in-the-loop scenarios in `plugins/context-economy/fixtures/` (`CE-01`–`CE-05`), each with a `prompt.md` + `expected.md` checkbox rubric. See `fixtures/README.md`. Target ≥3/5 pass before shipping a change that touches Steward/Assembler/Delegator behavior. |
| Kiln/Gauntlet skills generally | No automated harness — verify by exercising the skill's entry point (`/kiln`, `/gauntlet`, etc.) against a real or fixture scenario. |

There is no CI pipeline (`.github/workflows/`) wired up yet — these checks are run manually before a commit lands on `main`.

## Commit Convention

Conventional Commits, scoped to the plugin touched: `<type>(<plugin>): <description>` — e.g. `feat(kiln): add Curator close-out member`, `fix(gauntlet): pin finder/validator agents to Sonnet 4.6`. Observed types: `feat`, `fix`, `chore`. A `doc-review`-scoped fix (`fix(doc-review): ...`) has also been used when the change is narrow to one Gauntlet skill rather than the whole plugin — scope to whatever is most specific and accurate.

## Branch Strategy

Branch names follow `<type>/<plugin-or-scope>[-description]`, e.g. `feat/kiln-drafter`, `fix/gauntlet-pin-sonnet-4-6`. This is the convention going forward. Older branches using a `<plugin>/<description>` form without a leading type (`gauntlet/hardening`, `kiln/p1-reliability-core`) predate it — don't follow that pattern for new work.

## Pull Requests

Nearly every commit on `main` (29 of 36 at last count) carries a `(#N)` suffix — PRs are the norm, not direct pushes, even for a single-person repo. No PR template exists yet.

## File-Level Guidance

| Path | Why restricted |
|---|---|
| `plugins/kiln/skills/smith/langfuse/.env`, `local.env` | Local Langfuse credentials — gitignored, never commit |
| `.compounds/`, `.worktrees/` | Local machine state — gitignored, regenerated per machine |
| `.claude/settings.json` (repo root) | Personal `enabledPlugins` state — gitignored |
| `plugins/kiln/agents/crafter/references/`, `plugins/kiln/agents/designer/references/` | Loaded by `crafter.md`/`designer.md` via `${CLAUDE_PLUGIN_ROOT}` path — moving without updating both callers breaks the agent |
