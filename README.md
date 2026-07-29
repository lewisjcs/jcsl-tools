# jcsl-tools

Josh C.S. Lewis's personal Claude Code plugin marketplace — four independently installable plugins covering implementation workflow, multi-lens review, discovery-first research, and context-spend discipline. No build step, no server, no compiled artifact: every plugin is markdown (skills, agents) plus a handful of small shell/Python scripts that Claude Code loads directly.

## Plugins

| Plugin | What it does | Entry point |
|---|---|---|
| [`kiln`](plugins/kiln/) | Complexity-proportionate implementation Party. A thin conductor routes work through lanes (design, research, plan, execute, review) and dispatches specialized members (Designer, Scout, Planner, Crafter, Inspector, Curator, Drafter, Sifter, Finisher) — it never edits source itself. | `/kiln EXT-NNNN` \| `/kiln "raw idea"` \| `/kiln EXT-NNNN path/to/plan.md` |
| [`gauntlet`](plugins/gauntlet/) | Multi-skill AI review harness. Detects an artifact's type (code diff, plan, doc, skill, directive) and routes it through a finder/validator adversarial pair per domain, plus a security pass on everything. | `/gauntlet [<pr-url>\|<path>\|<directory>]` |
| [`prospector`](plugins/prospector/) | Discovery-first research harness. Finds where an answer lives across Glean, GitHub, Jira, and the web before reading anything — then verifies every load-bearing claim and synthesizes a cited answer. | `/prospector:research` |
| [`context-economy`](plugins/context-economy/) | Six-Class Party (Steward, Assembler, Delegator, Chronicler, Enforcer, Observer) for spending Claude Code's context window economically — hard-gates before broad reads/greps, nudges a handoff before context fills, tracks session cost. | Fires automatically on trigger phrases; no slash command |

See each plugin's own README/SKILL.md for full usage. [ARCHITECTURE.md](./ARCHITECTURE.md) covers how the four plugins relate and the conventions shared across all of them (`${CLAUDE_PLUGIN_ROOT}` usage, progressive disclosure, finder/validator pairing).

## Installation

Register this repo as a local marketplace in `~/.claude/settings.json`:

```json
"extraKnownMarketplaces": {
  "jcsl-tools": {
    "source": {
      "source": "directory",
      "path": "/absolute/path/to/jcsl-tools"
    }
  }
}
```

Then install whichever plugins you want:

```sh
claude plugin install kiln@jcsl-tools
claude plugin install gauntlet@jcsl-tools
claude plugin install prospector@jcsl-tools
claude plugin install context-economy@jcsl-tools
```

Restart Claude Code after installing or after any change to a plugin's `hooks.json` or `plugin.json`.

## Documentation

| Document | What it covers |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Marketplace/plugin structure, per-plugin component breakdown, cross-plugin conventions |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Setup, how to add a skill/agent/hook, per-component verification |
| [AGENTS.md](./AGENTS.md) | Agent-first routing table and guardrails |

## License

MIT — see [LICENSE](./LICENSE).

## For AI Agents

If you are an AI coding agent working in this repository, read [AGENTS.md](./AGENTS.md) first. It tells you where to find architectural context, development setup, and repo-specific rules.
