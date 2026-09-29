# AGENTS.md

| What you need | Where to look |
|---|---|
| How this repo is structured | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| How to add/test a plugin component | [CONTRIBUTING.md](./CONTRIBUTING.md) |
| What each plugin does | [README.md](./README.md) |

## Guardrails

- This repo IS a plugin marketplace — `.claude-plugin/marketplace.json` is the manifest agents/tools read to discover plugins. Do not confuse it with a plugin's own `.claude-plugin/plugin.json`.
- Every hook script path in a `hooks.json` MUST use `${CLAUDE_PLUGIN_ROOT}`, never a hardcoded or relative path — plugins install to different locations depending on install method.
- `.compounds/` and `.worktrees/` are gitignored local state — never propose committing their contents.
- `plugins/kiln/` is a generated payload: the kiln repository's packager writes every file in it from a merged commit. Never hand-edit it; edit the canon there and repackage.
- `plugins/_archive/kiln-2.17/` is the previous Kiln, kept whole and unlisted. Never wire it back into the marketplace, and never commit anything under its `skills/smith/langfuse/` except `docker-compose.yml`.

## Safety & Permissions

- `.claude/settings.json` at repo root is personal machine state (`enabledPlugins`), gitignored — don't propose tracking it.
- Bumping a plugin's `version` in its `plugin.json` is a release action — confirm with the owner before bumping; it is not implied by an unrelated content change.

## Build & Quality

No package manager, build step, or test framework at the repo level — plugins are markdown + shell + Python with no compile step. Per-plugin verification loops (where they exist) are documented in [CONTRIBUTING.md](./CONTRIBUTING.md).
