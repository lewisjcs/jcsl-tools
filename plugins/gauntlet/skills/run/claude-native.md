# Claude Code native Party dispatch

Use this route for each pending Party action when the host is Claude Code and the operator did not request `--strict-turn-cap`. The runtime controls the sequence. The Agent tool provides a fresh visible subagent for each action.

1. If `bundle.json` has `reviewedCommit`, check that `git -C <bundle.repoRoot> rev-parse HEAD` equals it. Stop that lane on a mismatch. Call the Agent tool with `subagent_type: hostBinding.agent` and `prompt: next.promptBody` verbatim. Start independent lanes in parallel. Within each lane, wait for its dispatch and receipt before starting its next action.
2. Save the agent's complete reply unchanged to `<runDir>/<role>-output-<attempt>.json`. Set `<role>` to `next.kind` without `dispatch-`.
3. Write `<runDir>/<role>-host-meta-<attempt>.json` with one `modelBinding` entry for that role and `"bindingStatus": "degraded"`. Use the model pinned by the agent definition and `hostBinding.model`; verify they agree. Include `reasoningEffort` when pinned. The Agent tool does not expose the observed model, so record the pin as a declared binding and keep actual model identity unverified.
4. Read the child transcript named by the Agent tool's `agentId` and record measurable `usage` and `toolCalls`. A Claude subagent transcript lives under the active project's `subagents/agent-<agentId>.jsonl`. For token and turn counts, take the last streamed record for each assistant message ID before summing. Do not sum all streamed records: that counts one message several times. Do not record `outputTokens` from the transcript's stream-start placeholder. Leave a field absent when the host cannot measure it. This query returns the measurable token split and turn count:

```
jq -s '[.[] | select(.type=="assistant")] | group_by(.message.id) | map(last)
  | {inputTokens: (map(.message.usage.input_tokens)|add), cacheWriteTokens: (map(.message.usage.cache_creation_input_tokens)|add), cacheReadTokens: (map(.message.usage.cache_read_input_tokens)|add), turns: length}' <subagent-transcript>
```
5. Pass the raw reply and host metadata to `receipt`. Continue with the returned `next` and `hostBinding`, including the runtime's one retry. Once `next.terminal` is true, call `result` for that lane.

This host route measures turns after the subagent returns. Its 40-turn budget is advisory during execution. If a transcript shows more than 40 turns, report the overrun with the final Party result; do not claim the run was capped.

Check before each receipt: the Agent tool returned one action's reply, the metadata names exactly that role, and the raw file contains the entire reply. Stop that lane when any check fails.
