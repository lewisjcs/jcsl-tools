# Codex native Party dispatch

Use this route for each pending Party action when the host is Codex. Check that `${PLUGIN_ROOT}/runtime/hosts/codex/bin/measure.mjs` exists. The runtime's `init` must have received the current parent rollout as `--codex-parent-trace`; it observes that session's model and reasoning effort for the lane.

1. For a bundle with `reviewedCommit`, check `git -C <bundle.repoRoot> rev-parse HEAD` against it before dispatch. The Party stages pull request reviews in their own worktree. The child must read source from that absolute `repoRoot`, even when its starting directory differs.
2. Set `ACTION_ID` to `next.actionId`, including any retry suffix. Prepare the exact prompt from the installed role body and pending action:

```
node "${PLUGIN_ROOT}/runtime/hosts/codex/bin/measure.mjs" prepare \
  --state <runDir>/state.json --action <ACTION_ID> \
  --prompt <runDir>/<ACTION_ID>-prompt.md
```

3. Pass the prepared file's complete bytes as one message to a fresh native `spawn_agent` with `agent_type: default` and `fork_context: false`. Omit model and reasoning-effort overrides so the child inherits the observed parent settings. Start independent lanes in parallel. Wait for each child to finish and retain its agent ID.
4. Locate exactly one child rollout JSONL whose session ID equals the returned agent ID. The parent and child rollouts are under the active Codex session store. Measure the completed action:

```
node "${PLUGIN_ROOT}/runtime/hosts/codex/bin/measure.mjs" measure \
  --state <runDir>/state.json --action <ACTION_ID> \
  --prompt <runDir>/<ACTION_ID>-prompt.md \
  --child-id <agent-id> --child-trace <child-rollout.jsonl> \
  --output <runDir>/<ACTION_ID>-raw.json \
  --host-meta <runDir>/<ACTION_ID>-host-meta.json
```

5. On success, pass those files unchanged to `receipt`, then follow the returned `next` and `hostBinding`. Close the completed child to free its slot. Run `result` once the lane is terminal. If preparation or measurement refuses, report its error and leave the action pending.

The helper checks the parent, child, pending action, prepared prompt, and observed model before writing a receipt. It reports `bindingStatus: degraded` because native Codex subagents have no enforced turn, tool, or path cap. Token usage and tool calls come from the child rollout when present. Turn counts remain unavailable until that rollout field is proven to measure turns.

Check before each receipt: the measured child ID equals the selected agent, the action ID is still pending, and the output files were written by the helper. Stop that lane on a mismatch.
