# jcsl-tools

Josh C.S. Lewis's personal Claude Code plugin marketplace — implementation workflow Parties and review/research skills. Owned and maintained by Josh alone.

Read [AGENTS.md](./AGENTS.md) for the full agent guardrail set and invariants, [ARCHITECTURE.md](./ARCHITECTURE.md) for how the marketplace and its five plugins fit together, and [CONTRIBUTING.md](./CONTRIBUTING.md) for setup and verification.

## Commands

| Task | Command |
|------|---------|
| Install a plugin locally | `claude plugin install <name>@jcsl-tools` |
| Verify Kiln guard hooks | `bash plugins/kiln/hooks/test-kiln-guards.sh` |
| Verify Gauntlet agent parity | `bash plugins/gauntlet/agents/check-grounding-parity.sh` |
| Verify a Context Economy hook | `bash plugins/context-economy/hooks/<hook-name>.test.sh` |

There is no install/build/lint/test command at the repo level — see [CONTRIBUTING.md](./CONTRIBUTING.md) for the full per-component verification table.

## Conventions

- Conventional Commits scoped to the plugin touched: `<type>(<plugin>): <description>`.
- Branch as `<type>/<plugin-or-scope>[-description]` (e.g. `feat/kiln-drafter`).
- PRs are the norm even for solo work — most commits on `main` carry a `(#N)` merge reference.
- Version bumps ride the content PR that motivates them — edit the plugin's `.claude-plugin/plugin.json` version in the same PR; no separate bump PRs.

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full details.

Key patterns to respect:
- This repo IS the marketplace manifest source — `.claude-plugin/marketplace.json` lists all five plugins by `source` path. A new plugin needs an entry here too, not just its own directory.
- Every hook script reference uses `${CLAUDE_PLUGIN_ROOT}` — never a hardcoded or relative path.
- Kiln's conductor is intentionally thin: a `PreToolUse` hook denies its file-editing tools mid-run. Don't propose "simplifying" Kiln by having the conductor edit source directly — that guarantee is load-bearing.

## Sharp Edges

- `plugins/kiln/agents/crafter/` and `plugins/kiln/agents/designer/` are directories, not flat `.md` files like every other agent — each holds a `references/` file its sibling `.md` loads explicitly. Don't flatten without checking both load paths.
- `plugins/kiln/skills/smith/langfuse/` mixes a tracked `docker-compose.yml` with gitignored `.env`/`local.env` — never commit the latter two.
- No CI is wired up. Manual verification (see Commands above) is the only gate before a PR merges.

## Testing

No repo-wide test runner. Per-component checks only — see [CONTRIBUTING.md](./CONTRIBUTING.md) → Testing.
