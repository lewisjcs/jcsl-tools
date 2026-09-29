---
name: build
description: Build a ticket with the kiln Party. Use when asked to "build this ticket", "build <ticket>", "kiln <ticket>", "run the kiln on <ticket>", "/kiln-next:build <ticket reference or idea>", or to continue a build that stopped in an earlier session. One run per ticket, on the ticket key; the runtime decides what is next; you dispatch, measure, and append. Never implements a task yourself.
---
<!-- canon: hosts/claude-code/skills/build/SKILL.md in the kiln repo. The plugin copy is generated; edit the canon and repackage. -->

# Build

You are the build host. The ticket is the handle. The runtime decides what is next. You dispatch, measure, and append. You never implement a task yourself, never reorder or skip an action, never parse or fix a member's outcome, and never decide the next step yourself.

## Preflight

- `node --version` is 22 or newer. CLI = `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs"`. Never `cd`; pass absolute paths. A markdown ticket is always passed as its absolute path, the same path every session, because the run is keyed on it.
- Input: a ticket reference (`owner/repo#N`, an issue URL, a Jira key, or a markdown path) or an idea in quotes. An idea needs a file to live in: ask the person for the path once, then `open --ticket <path> --idea "<the idea>"`. A Jira key refuses with `KILN_TICKET_SOURCE_UNBUILT`: say so and stop.
- Make sure that every installed Class matches canon before any dispatch. Run `classes`. For each entry with `borrowed: false`, run `classes --class <classId> --installed <path>`. The path is the entry's body under the installed plugin. For a `play.kind` of `agent`, it is `${CLAUDE_PLUGIN_ROOT}/agents/<the file name of bodyPath>`. For a `play.kind` of `skill`, it is `${CLAUDE_PLUGIN_ROOT}/skills/<the folder name of bodyPath>/SKILL.md`. The borrowed entry is checked at its action (see below). A mismatch is a stop.
- Any CLI command that exits non-zero prints `{"error": {"code", "message", "details"}}` on stderr. Show it to the person and stop. Never work around it.

## Open

`open --ticket <ref>`. Print the `fillState` lines in prose: what the ticket gives, what is missing, who fills it, and the forecast. Print the roster line. If `resumed` is true, say the run continues from the last session. Then continue with `next` from the reply.

## The loop

Repeat until `next.terminal` is true. Every `open`, `receipt`, and `reply` reply carries `next`; run `next --ticket <ref>` only when you have no reply in hand. The run dir is `dir` from `open` or `show --ticket <ref>`.

**`hostBinding.kind` is `person`.** Read the file at `next.questionPath` and show its text to the person in chat verbatim. Add plain words only around it, never in place of it: for a write or build question, the file holds the diff that the person consents to. Wait for the reply in chat. Write the reply, verbatim, to `<run dir>/handed/<actionId>-reply.txt`. Then run `reply --ticket <ref> --action <actionId> --file <that path>`. Never answer for the person. At a write, build, or pull request stop, only a bare `yes`, `y`, `ok`, or `approve` is consent; any other text re-asks. A reply that is `abandon` and nothing else ends the run.

**`hostBinding.kind` is `agent`.**
1. If `next.write` is present, snapshot the tree first. On attempt 1 (`next.attempt` is 1), run `writes snapshot --repo <next.write.repoRoot> --out <run dir>/writes/<actionId>.before.json`. On attempt 2, take no new snapshot. The runtime measures a retry against the tree before attempt 1. The before file is the attempt-1 file: the action id with its last `-2` changed to `-1`.
2. Dispatch exactly one Agent call: `subagent_type` = `hostBinding.agentType`, `model` mapped from `hostBinding.model` (`claude-sonnet-5` to `sonnet`, `claude-haiku-4-5` to `haiku`, `claude-opus-5` to `opus`), prompt = `next.promptBody` verbatim. Never paste ticket or repo content in yourself. Note the wall-clock seconds and the agentId the Agent result names.
3. Write the member's full reply, untouched, to `<run dir>/handed/<actionId>-output.txt`. The reply is the `message` field of the `SubagentHandback` tool call in the dispatch transcript, never the transcript's last plain text block. Do not extract, repair, or author an outcome.
4. Measure usage into `<run dir>/handed/<actionId>-meta.json`, shaped `{"modelBinding": {"model": "<hostBinding.model>"}, "usage": {...}, "toolCalls": [...], "writes": {...}}`. Usage comes from the dispatch transcript `agent-<agentId>.jsonl`. Never compute the project folder name from the working directory. Let `<config-dir>` be `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, and find the transcript with `ls <config-dir>/projects/*/*/subagents/agent-<agentId>.jsonl`. The agentId is unique, so one file matches. Then:

    ```
    jq -s '[.[] | select(.type=="assistant")] | group_by(.message.id) | map(last)
      | {inputTokens: (map(.message.usage.input_tokens)|add), cacheWriteTokens: (map(.message.usage.cache_creation_input_tokens)|add), cacheReadTokens: (map(.message.usage.cache_read_input_tokens)|add), turns: length}' <transcript>
    ```

    Add `latencySeconds` from your wall clock. Never record `outputTokens`. Each `toolCalls` item is `{"tool": "<name>", "target": "<path or command head>"}`: collect `tool_use` blocks from every streamed assistant line and dedupe by block id. For a Bash call, the target is the command's first 120 characters. The runtime cross-checks evidence commands against it, so never leave a Bash target out. If `next.write` was present, run `writes measure --repo <next.write.repoRoot> --before <the before file>` and put its output under `writes`. If `next.write` was absent, leave the `writes` key out. If the transcript cannot be found, leave both `usage` and `toolCalls` out of the meta file, and say so in chat. They are then named omissions. Never write an empty `toolCalls` list: the runtime reads it as measured with no calls and rejects every evidence command.
5. `receipt --ticket <ref> --action <actionId> --output <the output file> --host-meta <the meta file>`. Read `ledger.outcome`, `runStatus`, `breach`, `omissions`, `issues`, and `next`. A `next` with `attempt` 2 is the runtime handing you the retry: dispatch it like any action. `KILN_ACTION_STALE`, `RUNTIME_*`, and `KILN_RUN_TERMINAL` are the runtime protecting the record: surface them and never work around them.

**`hostBinding.kind` is `skill`.** The designer plays in this thread. Invoke it with the Skill tool: `/<hostBinding.invoke> --ticket <ref> --cli ${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs`. It writes `<run dir>/handed/<actionId>-output.txt` and `-meta.json`. Then run `receipt` with those two files.

**`hostBinding.kind` is `borrowed`.** A second review of the branch.
1. Stage the diff. `show --ticket <ref>` prints `repo` as `{root, branch}`. The default branch is `git -C <repo.root> symbolic-ref --short refs/remotes/origin/HEAD`. Then `git -C <repo.root> diff $(git -C <repo.root> merge-base <default branch> HEAD) HEAD > <run dir>/handed/<actionId>.diff`.
2. Load `/<hostBinding.invoke>` with the Skill tool and follow its procedure in this thread, with the staged diff as its code-diff artifact. Before its first dispatch, check the installed review. The review plugin root is the folder above `runtime/` in the command path that the loaded skill names. Run `classes --class <the borrowed entry's classId> --installed <review plugin root>/<the entry's installedManifest>`. A mismatch is a stop. Skip its triage step. The runtime rules on the findings, not you or the person.
3. The review writes `result.json` and `evidence.json` in its own run directory (its `runDir`). Then run `borrowed --result <runDir>/result.json --evidence <runDir>/evidence.json --scope branch`. Write its `outcome` array, as JSON, to `<run dir>/handed/<actionId>-output.txt` and `{"modelBinding": {"model": "main-thread"}, "usage": <its usage>}` to `<run dir>/handed/<actionId>-meta.json`, and run `receipt`. Leave `toolCalls` out: the review's tool calls are not measured here, and an empty list would read as measured with none. Never triage the findings yourself.

## Terminal

When `next.terminal` is true, `next.status` names the end: `complete`, `abandoned`, or `gap`.

`complete`: the person said yes to the pull request. Check if the repository is public: `gh repo view "$(git -C <repo.root> remote get-url origin)" --json isPrivate -q .isPrivate`. If it prints `false`, run `pr --ticket <ref> --public`. If it prints `true`, run `pr --ticket <ref>`. If it prints anything else, stop and say so. Never run `pr` without `--public` on an unknown visibility: on a public repo, that form puts the full text of each finding in the pull request body. Read `evidenceBlockPath`, `worktree`, `branch`, and `titlePath`. Push the branch: `git -C <worktree> push -u origin <branch>`. Open the pull request for that worktree's branch, with no `cd`: `gh pr create --repo "$(git -C <worktree> remote get-url origin)" --head <branch> --title "$(cat <titlePath>)" --body-file <evidenceBlockPath>`. Pass the title through `$(cat <titlePath>)`, not `"<title>"` pasted in. A command substitution's output is not parsed again. The ticket author's raw text (a backtick, a `$(...)`, a `"`) reaches `gh` as one plain argument instead of expanding or breaking the command. The pull request URL is the last line it prints. If either command exits non-zero, show its output to the person and stop. Then `close --ticket <ref> --pr-url <url>` and `readout --ticket <ref>`. Print the member table and the floor line from the file at `readoutPath`. Nothing else: no merge, no cleanup of the worktree.

`abandoned` or `gap`: run `readout --ticket <ref>`, print the table, and say which stop ended the run. A `gap` names a deterministic check the runtime failed twice; the ledger's last outcome says which (`show --ticket <ref>` prints the last ledger entries). The ended run stays on the ticket key: a later `open` returns it with an `again` line. To start over, only when the person asks, run `open --ticket <ref> --again`. It moves the ended run's directory aside as `<dir>.abandoned-<UTC time>`, keeps it readable there, and opens a fresh run.

## Never

Never reorder, collapse, or skip an action. Never decide whether a second member runs. Never invent, drop, or relabel a finding or a ruling. Never open the pull request without the person's yes. Never write to a GitHub issue or Jira ticket except through `reply` and `close`.
