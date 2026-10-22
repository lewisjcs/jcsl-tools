---
name: build
description: Use when building or resuming an approved Kiln plan from Codex.
---

# Codex build host

This is the Codex dispatch portion of the top-level Kiln build skill. Use its approved-plan selection, task scaffold, consent, borrowed review, and terminal pull request rules. Set `PLUGIN_ROOT` to the absolute folder containing the top-level `skills/` and `runtime/` folders. Use `node <PLUGIN_ROOT>/runtime/bin/cli.mjs` as the CLI. Pass `--host codex` on a new `open`. A resumed run reads its saved host. This host accepts approved plans only.

Before `open`, confirm Node 22 or newer, a writable Kiln run store, native `spawn_agent` and `wait_agent` tools, and an active `CODEX_SESSION_ID`. Kiln reads the active turn's model and reasoning effort from that session and saves them with the run. If the ticket is in Jira, confirm `KILN_JIRA_VIEW` names a working read command. A Codex Jira read cannot use the Claude Code capture hook. Stop before opening a run when a required capability is absent.

Run `plan-approval-check`, `plan-scaffold`, `plan-check`, and `open` as the top-level skill describes. Show the build approval question and selected worktree. Save the person's clear consent with `reply`; do not infer it from a request to discuss the plan. For every result, follow the returned `next` action without reordering it.

Choose task-scaffold checks with expected results Codex can verify: `exit N`, an exact numeric count, `a count of at least N`, or a backticked output literal. For a silent syntax check, use `exit 0`. For output text, use a backticked deciding line. `KILN_CODEX_CHECK_EXPECT_UNSUPPORTED` names a scaffold check to restate before opening the run. Keep the approved plan and its approval bytes unchanged.

## Native member dispatch

For `hostBinding.kind` = `subagent`:

1. Run `classes --host codex --class <hostBinding.classId> --installed <hostBinding.bodyPath>`. Stop on a mismatch.
2. If `next.before.take` is true, run `writes snapshot --repo <next.write.repoRoot> --out <next.before.path>` before Crafter starts. If `next.readOnly.before.take` is true, run `writes snapshot --repo <next.readOnly.repoRoot> --out <next.readOnly.before.path>` before Inspector starts. Keep the same baseline on a retry.
3. Spawn exactly one native Codex subagent with `fork_context: false`. Use `worker` for Crafter and `default` for Inspector. Omit a model override so the subagent inherits the active Codex model and reasoning effort saved in `hostBinding`. The prompt must name the exact `next.actionId`, `next.briefPath`, and `hostBinding.bodyPath`. Tell the member to read the role body and brief before work. Give it every exact command in `next.checkCommands`. Tell the member to run each check through `tools.exec_command({cmd: "<the exact command>"})` with a literal `cmd` value and to print the returned runner output. The receipt reader looks for that call in the child's rollout. The prompt asks for exactly one JSON outcome array and no prose outside it.
4. Wait for that agent ID to complete. Keep the returned agent ID; never substitute a different child or a parent-thread summary. On an error or interruption, inspect the worktree and keep the Kiln action pending.
5. Run `node <PLUGIN_ROOT>/runtime/hosts/codex/bin/measure.mjs --agent <agent ID> --action <next.actionId> --brief <next.briefPath> --run <run dir> --cli <PLUGIN_ROOT>/runtime/bin/cli.mjs`. For an action with `next.write`, add `--repo <next.write.repoRoot> --before <next.before.path>`. For Inspector, add `--repo <next.readOnly.repoRoot> --before <next.readOnly.before.path>`. The script reads the child rollout, checks the final outcome against its Class contract and recorded checks, and writes the output and host-meta files. It refuses if Inspector changed the worktree. If it refuses on a reply or check mismatch, inspect the worktree and send one focused correction to the same subagent. Tell the member to rerun every command in `next.checkCommands` after the correction, even when only its reply changed. Wait for its corrected result and run measure again with the same agent ID. If measurement still refuses, report the code and leave the Kiln action pending. Never write or adjust receipt files by hand.
6. Run `receipt --ticket <ref> --action <next.actionId> --output <run dir>/handed/<next.actionId>-output.txt --host-meta <run dir>/handed/<next.actionId>-meta.json`. Read its ledger outcome and the next action. The runtime, not the host, decides retries and stops.

The check runner executes the saved task check itself and records the command, exit code, and output. Its exit-status line gives silent checks a quote. The member must quote only output that the runner returned. The measure script refuses a complete claim with a failed check, an old correction check, or a quote, exit code, or command that differs from the record. It also checks that the child submitted the runner command, belongs to the active parent session, and used the saved model and reasoning effort. The child rollout supplies actual token totals. Codex tool and path enforcement are best effort; the Class binding reports both degradations. A Codex subagent inherits the parent's sandbox and approval mode. Inspector's before-and-after worktree measurement refuses detected writes at receipt time.

## Other actions

For `person`, follow the top-level skill's reply rules. For `borrowed`, run the pinned Gauntlet review with its Codex host skill, then use Kiln's `borrowed` command and receipt mapping from the top-level skill. At terminal `complete`, follow its pull request consent and close rules. If a required Gauntlet Codex host or result is unavailable, report the gap and leave the Kiln action pending.

Before each receipt, check that the saved run still names the same pending action. Before reporting completion, confirm `next.terminal` and the saved status. Do not treat a subagent's final message alone as a Kiln result.
