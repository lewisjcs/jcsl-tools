# jcsl-tools

jcsl-tools is the personal plugin marketplace of Josh C.S. Lewis. A marketplace is a catalog of plugins for an agent host. A host is the AI coding application that loads a plugin. The marketplace holds six independently installable plugins.

All six plugins run on Claude Code. Kiln, Gauntlet, and Herald also run on Codex, and Herald also runs on Cursor. Kiln handles kickoff and builds. The other plugins cover review, research, context use, repository documentation, and plain-English writing.

## Plugins

| Plugin | What it does | Entry point |
|---|---|---|
| [`kiln`](plugins/kiln/) | Kickoff answers questions, explores ideas, and prepares reviewed plans. Build starts a separate implementation run from an approved plan or ticket. Five Classes (roles that each do one job) provide research, design, planning, coding, and review. | `/kiln:kickoff <question, idea, ticket, or plan>` starts preparation. `/kiln:build <ticket or plan>` starts implementation. `/kiln:shape <idea>` opens the Designer directly. `/kiln:prospector <question>` runs the Prospector directly for cited research. |
| [`gauntlet`](plugins/gauntlet/) | A multi-skill AI review harness. It is a thin host over a deterministic Party runtime (a program that runs a team of Classes). The runtime detects the artifact type (code diff, plan, doc, skill, or directive) and picks the review lanes (kinds of review) that fit it. Today it runs adversarial review, code-quality audit, threat review on a security signal, and revision review on a re-review. The runtime reports other lanes as gaps, and you can start each gap lane yourself. | `/gauntlet:run [<pr-url>\|<path>]` |
| [`prospector`](plugins/prospector/) | A discovery-first research harness. It finds where an answer lives across Glean, GitHub, Jira, and the web before it reads anything. Then it verifies every claim that the answer depends on and writes a cited answer. | `/prospector:research` |
| [`context-economy`](plugins/context-economy/) | A six-Class Party (Steward, Assembler, Delegator, Chronicler, Enforcer, Observer) that spends the Claude Code context window with care. It gates broad reads and searches until it names a cheaper option. It nudges you to write a handoff before the context window fills, and it tracks session cost. | No slash command. It starts when your words match a trigger phrase. |
| [`cartographer`](plugins/cartographer/) | A repository cartographer. It analyzes the structure and evidence of a repository and drafts a grounded, claim-classified README enrichment. It flags unsupported claims and stale content. | The `cartograph-report` skill. Claude Code finds it on its own, and it has no slash command. |
| [`herald`](plugins/herald/) | A plain-English output style for Claude Code, Codex, and Cursor. Replies read as natural English that explains the why. README files, docs, runbooks, CHANGELOG files, and release notes follow a stricter register. On Claude Code and Codex, a hook nudges after markdown writes. A rewrite skill applies the stricter register. | No slash command. Claude Code applies the style whenever the plugin is enabled. Codex loads it at session start, and Cursor loads it as an always-on rule. Ask the `herald` skill to "rewrite in plain English". |

The entry points in this table are the Claude Code forms. On Codex, Kiln and Gauntlet load the same skills, and you can ask for a skill by name.

See each plugin's own README/SKILL.md for full usage. [ARCHITECTURE.md](./ARCHITECTURE.md) covers how the six plugins relate and the conventions shared across all of them (`${CLAUDE_PLUGIN_ROOT}` usage, progressive disclosure, finder/validator pairing).

## Host support

Every host reads the same plugin folders. Full support means that every feature of the plugin works on that host.

| Plugin | Claude Code | Codex | Cursor |
|---|---|---|---|
| `kiln` | Full | Kickoff, shape, build, and direct Prospector. Tool and path limits are best effort. | None |
| `gauntlet` | Full | The `run` skill with four lanes: adversarial review, code-quality audit, threat review, and revision review. Plan, doc, and directive review need Claude Code. | None |
| `prospector` | Full | None | None |
| `context-economy` | Full | None | None |
| `cartographer` | Full | None | None |
| `herald` | Full | Full | The style rule and the rewrite skill. Cursor gets no markdown nudge. |

## Requirements

- Kiln and Gauntlet each ship a bundled JavaScript runtime. Both runtimes need Node 22 or later and no npm install.
- Both runtimes include Statblock, the shared kernel that checks Class and Party data. Statblock needs no separate install.
- On Codex, Kiln and Gauntlet need native subagents (the `spawn_agent` and `wait_agent` tools).
- The Herald linter needs Python 3.9 or later.
- The Context Economy hooks need `jq` and `python3`. Its status line widget uses `ccstatusline`.

## Installation

Claude Code and Codex both read the marketplace file `.claude-plugin/marketplace.json`. Add the marketplace once on each host. Then add the plugins that you want. To use a local clone, replace `lewisjcs/jcsl-tools` with the absolute path of the clone.

### Claude Code

```sh
claude plugin marketplace add lewisjcs/jcsl-tools
claude plugin install kiln@jcsl-tools
claude plugin install gauntlet@jcsl-tools
claude plugin install prospector@jcsl-tools
claude plugin install context-economy@jcsl-tools
claude plugin install cartographer@jcsl-tools
claude plugin install herald@jcsl-tools
```

Restart Claude Code after you install a plugin. Also restart it after any change to a plugin's `hooks.json` or `plugin.json`. To get a new release, run `claude plugin marketplace update jcsl-tools`.

### Codex

Codex supports Kiln, Gauntlet, and Herald.

```sh
codex plugin marketplace add lewisjcs/jcsl-tools
codex plugin add kiln@jcsl-tools
codex plugin add gauntlet@jcsl-tools
codex plugin add herald@jcsl-tools
```

When Codex asks, trust the Herald hooks. Start a new thread after you add a plugin. To get a new release, run `codex plugin marketplace upgrade`.

### Cursor

Cursor supports Herald only. If your Cursor offers a private plugin install, install Herald from the marketplace. If it does not, paste the body of `plugins/herald/rules/herald.mdc` into your user rules. The [Herald README](plugins/herald/README.md) gives the details.

## Plugin sources

Most plugins are written in this repository. Kiln is a generated payload. A packager in a separate source repository writes every file in `plugins/kiln/`. The Gauntlet runtime in `plugins/gauntlet/runtime/` is packaged the same way. Each payload carries a `PROVENANCE.json` file that names its source commit. No build step runs in this repository.

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
