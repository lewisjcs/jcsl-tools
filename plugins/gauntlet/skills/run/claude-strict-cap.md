# Claude Code strict-cap Party dispatch

Use this route only when the operator requests `--strict-turn-cap`. The preflight checks that `${PLUGIN_ROOT}/runtime/bin/dispatch.mjs` exists. The wrapper starts a fresh Claude SDK query with a configured 40-turn maximum. It does not appear as an Agent-tool subagent in the current session.

Save `next.promptBody` verbatim to `<runDir>/<actionId>-prompt.md`. Run one process per pending action:

```
node "${PLUGIN_ROOT}/runtime/bin/dispatch.mjs" \
  --agent-file "${PLUGIN_ROOT}/agents/<hostBinding.agent without gauntlet: prefix>.md" \
  --prompt-file <runDir>/<actionId>-prompt.md \
  --bundle <runDir>/bundle.json \
  --model <hostBinding.model> \
  --role <next.kind without dispatch- prefix> \
  --max-turns <hostBinding.maxTurns> \
  --output <runDir>/<role>-output-<attempt>.json \
  --meta <runDir>/<role>-host-meta-<attempt>.json
```

The wrapper checks the reviewed commit for a pinned pull request and records the raw reply, usage, turns, and tool calls. A non-success SDK result is host-failure output, including `error_max_turns`; pass it to the runtime without treating it as a clean finding set. Inspect unusually broad read targets in its stdout before another dispatch.

Pass the files unchanged to `receipt`. Continue with the returned `next` and `hostBinding`. Once `next.terminal` is true, call `result` for that lane. Check that both output files exist before every receipt; if the process fails before writing them, stop and report the process error.
