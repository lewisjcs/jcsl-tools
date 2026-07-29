# AGENTS.md

| What you need | Where to look |
|---|---|
| How this repo is structured | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| How to add/test a plugin component | [CONTRIBUTING.md](./CONTRIBUTING.md) |
| What each plugin does | [README.md](./README.md) |

## Guardrails

- This repo IS a plugin marketplace — `.claude-plugin/marketplace.json` is the manifest agents/tools read to discover plugins. Do not confuse it with a plugin's own `.claude-plugin/plugin.json`.
- Every hook script path in a `hooks.json` MUST use `${CLAUDE_PLUGIN_ROOT}`, never a hardcoded or relative path — plugins install to different locations depending on install method.
- `plugins/kiln/agents/crafter/` and `plugins/kiln/agents/designer/` are directories alongside `crafter.md`/`designer.md`, not the more common flat-file layout used by every other agent in this repo. This is intentional (each holds a `references/` file the agent loads via `${CLAUDE_PLUGIN_ROOT}/agents/<name>/references/...`) — do not "clean up" by flattening without checking both files' load paths first.
- `.compounds/` and `.worktrees/` are gitignored local state — never propose committing their contents.
- `plugins/kiln/skills/smith/langfuse/.env` and `local.env` are gitignored — never commit credentials there.

## Safety & Permissions

- Never commit anything under `plugins/kiln/skills/smith/langfuse/` except `docker-compose.yml` — the `.env`/`local.env` siblings hold local credentials.
- `.claude/settings.json` at repo root is personal machine state (`enabledPlugins`), gitignored — don't propose tracking it.
- Bumping a plugin's `version` in its `plugin.json` is a release action — confirm with the owner before bumping; it is not implied by an unrelated content change.

## Build & Quality

No package manager, build step, or test framework at the repo level — plugins are markdown + shell + Python with no compile step. Per-plugin verification loops (where they exist) are documented in [CONTRIBUTING.md](./CONTRIBUTING.md).
