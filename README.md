# jcsl-tools

Personal AI tooling marketplace for Claude Code — Josh C.S. Lewis.

## Plugins

| Plugin | Description |
|---|---|
| [`kiln`](plugins/kiln/) | The Kiln — complexity-proportionate implementation workflow Party |

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

Then install individual plugins:

```sh
claude plugin install kiln@jcsl-tools
```
