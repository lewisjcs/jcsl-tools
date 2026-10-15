# jcsl-tools

Josh C.S. Lewis's personal Claude Code marketplace has six independently installable plugins. Kiln handles kickoff and builds. The other plugins cover review, research, context use, repository documentation, and plain-English writing. Each plugin carries files that Claude Code loads directly. This repository does not build those files.

## Plugins

| Plugin | What it does | Entry point |
|---|---|---|
| [`kiln`](plugins/kiln/) | Kickoff answers questions, explores ideas, and prepares reviewed plans. Build starts a separate implementation run from an approved plan or ticket. Five Classes (roles that each do one job) provide research, design, planning, coding, and review. | `/kiln:kickoff <question, idea, ticket, or plan>` starts preparation. `/kiln:build <ticket or plan>` starts implementation. `/kiln:shape <idea>` opens the Designer directly. |
| [`gauntlet`](plugins/gauntlet/) | A multi-skill AI review harness. It is a thin host over a deterministic Party runtime (a program that runs a team of Classes). The runtime detects the artifact type (code diff, plan, doc, skill, or directive) and picks the review lanes (kinds of review) that fit it. Today it runs adversarial review, code-quality audit, threat review on a security signal, and revision review on a re-review. The runtime reports other lanes as gaps, and you can start each gap lane yourself. | `/gauntlet:run [<pr-url>\|<path>]` |
| [`prospector`](plugins/prospector/) | A discovery-first research harness. It finds where an answer lives across Glean, GitHub, Jira, and the web before it reads anything. Then it verifies every claim that the answer depends on and writes a cited answer. | `/prospector:research` |
| [`context-economy`](plugins/context-economy/) | A six-Class Party (Steward, Assembler, Delegator, Chronicler, Enforcer, Observer) that spends the Claude Code context window with care. It gates broad reads and searches until it names a cheaper option. It nudges you to write a handoff before the context window fills, and it tracks session cost. | No slash command. It starts when your words match a trigger phrase. |
| [`cartographer`](plugins/cartographer/) | A repository cartographer. It analyzes the structure and evidence of a repository and drafts a grounded, claim-classified README enrichment. It flags unsupported claims and stale content. | The `cartograph-report` skill. Claude Code finds it on its own, and it has no slash command. |
| [`herald`](plugins/herald/) | A plain-English output style for Claude Code, Codex, and Cursor. Replies read as natural English that explains the why. README files, docs, runbooks, CHANGELOG files, and release notes follow a stricter register. A PostToolUse hook nudges after markdown writes, and a rewrite skill applies the stricter register. | No slash command. The style applies whenever the plugin is enabled. The hook runs after every markdown write. Ask the `herald` skill to "rewrite in plain English". |

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

Then install the plugins that you want:

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

MIT. See [LICENSE](./LICENSE).

## For AI Agents

If you are an AI coding agent working in this repository, read [AGENTS.md](./AGENTS.md) first. It tells you where to find architectural context, development setup, and repo-specific rules.
