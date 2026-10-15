# jcsl-tools

Josh C.S. Lewis's personal Claude Code marketplace has six independently installable plugins. Kiln handles kickoff and builds. The other plugins cover review, research, context use, repository documentation, and plain-English writing. Each plugin carries files that Claude Code loads directly. This repository does not build those files.

## Plugins

| Plugin | What it does | Entry point |
|---|---|---|
| [`kiln`](plugins/kiln/) | Kickoff answers questions, explores ideas, and prepares reviewed plans. Build starts a separate implementation run from an approved plan or ticket. Five Classes provide research, design, planning, coding, and review. | `/kiln:kickoff <question, idea, ticket, or plan>` starts preparation. `/kiln:build <ticket or plan>` starts implementation. `/kiln:shape <idea>` opens the Designer directly. |
| [`gauntlet`](plugins/gauntlet/) | Multi-skill AI review harness. A thin host over a deterministic Party runtime that detects an artifact's type (code diff, plan, doc, skill, directive) and fields the review lanes it supports today (adversarial review, code-quality audit, threat review on a security signal, revision review on a re-review); lanes it doesn't yet field are reported as gaps and offered as operator-invoked follow-ups. | `/gauntlet:run [<pr-url>\|<path>]` |
| [`prospector`](plugins/prospector/) | Discovery-first research harness. Finds where an answer lives across Glean, GitHub, Jira, and the web before reading anything — then verifies every load-bearing claim and synthesizes a cited answer. | `/prospector:research` |
| [`context-economy`](plugins/context-economy/) | Six-Class Party (Steward, Assembler, Delegator, Chronicler, Enforcer, Observer) for spending Claude Code's context window economically — hard-gates before broad reads/greps, nudges a handoff before context fills, tracks session cost. | Fires automatically on trigger phrases; no slash command |
| [`cartographer`](plugins/cartographer/) | Repository cartographer — analyzes a repo's structure and evidence to draft a grounded, claim-classified README enrichment, flagging unsupported claims and stale content. | `cartograph-report` skill (auto-discovered; no slash command) |
| [`herald`](plugins/herald/) | Plain-English output style for Claude Code, Codex, and Cursor: natural replies that explain the why, a stricter register for README, docs, runbooks, CHANGELOG, and release notes, a PostToolUse markdown nudge, and a rewrite skill. | No slash command. The style applies whenever the plugin is enabled; the hook runs after every markdown write; the `herald` skill answers "rewrite in plain English". |

See each plugin's own README/SKILL.md for full usage. [ARCHITECTURE.md](./ARCHITECTURE.md) covers how the six plugins relate and the conventions shared across all of them (`${CLAUDE_PLUGIN_ROOT}` usage, progressive disclosure, finder/validator pairing).

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
claude plugin install cartographer@jcsl-tools
claude plugin install herald@jcsl-tools
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
