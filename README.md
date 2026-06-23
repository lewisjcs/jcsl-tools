# jcsl-tools

Personal AI tooling marketplace for Claude Code — Josh C.S. Lewis.

## Plugins

| Plugin | Description |
|---|---|
| [`kiln`](plugins/kiln/) | The Kiln — complexity-proportionate implementation workflow |
| [`gauntlet`](plugins/gauntlet/) | The Gauntlet — multi-skill AI review harness |

## Installation

Add to `~/.claude/settings.json` under `extraKnownMarketplaces`:

```json
"jcsl-tools": {
  "source": {
    "source": "directory",
    "path": "/path/to/jcslOS/repos/jcsl-tools"
  }
}
```

Both plugins ship a `.claude-plugin/plugin.json` manifest for auto-discovery. Install individual plugins:

```sh
claude plugin install kiln@jcsl-tools
claude plugin install gauntlet@jcsl-tools
```
