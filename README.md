# jcsl-tools

Personal AI tooling plugin for Claude Code — Josh C.S. Lewis.

## Contents

### The Kiln

A complexity-proportionate implementation workflow Party of four AI Classes:

| Class | Role |
|---|---|
| `kiln-refiner` | Brainstorming and spec dialogue — fuzzy→defined transition |
| `kiln-planner` | Compounds impact analysis + implementation plan + Jira tasks |
| `kiln-smith` | Per-task TDD implementation |
| `kiln-inspector` | Per-task spec compliance and quality review |

Orchestrated by the `kiln` skill. Invoke with `/kiln EXT-XXXX` or `/kiln "raw idea"`.

## Installation

```sh
claude plugin install github:lewisjcs/jcsl-tools
```

Or from local development:

```sh
claude plugin install /path/to/jcsl-tools
```
