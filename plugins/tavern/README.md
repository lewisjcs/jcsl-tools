# Tavern

The Tavern keeps one guarded record of the current shift. A shift is the span of work between one `open` and one `close`. The record lists what is open, what each session holds, what is waiting, and what was pushed aside. It works with Claude Code and Codex.

Each session writes to the record under its own name. The record refuses a stale write, so two sessions cannot overwrite each other.

## What it ships

- Seven skills: six for the shift commands and one for `report`, which only the person starts.
- A start-up hook that prints the session status when a session starts.
- An end hook that marks the session ended when it stops.
- A bundled runtime at `runtime/bin/cli.mjs`. The runtime needs Node 22 or later and no npm install.

A hook never fails a session start. On any error, a hook prints nothing and exits with code 0.

## Commands

Type a command as `/tavern:<name>` in Claude Code, or `$<name>` in Codex.

| Command | What it does | Example |
|---|---|---|
| `open` | Starts a shift and builds the record. | `/tavern:open` prints the board and the next ticket. |
| `transfer` | Takes over the work of an earlier session. | `/tavern:transfer T3` takes ticket T3. |
| `next` | Moves to the next ticket. | `/tavern:next` takes the first ticket on the rail. |
| `add` | Puts a new ticket on the record. | `/tavern:add --title "Fix the footer" --source file:docs/footer.md` |
| `replan` | Changes the plan for the shift. Only the person starts it. | `/tavern:replan order T4 T2` |
| `close` | Ends the shift and lists the leftovers. | `/tavern:close`, then the numbers of the leftovers to clear. |
| `report` | Prints a block of counts about the boards. Only the person starts it. | `/tavern:report` |

### Set-up commands

Run these from a terminal as `node runtime/bin/cli.mjs <command>`. They need no host session.

| Command | What it does |
|---|---|
| `init` | Writes a `tavern.json` settings file in the working folder, with each guess from the folder marked. |
| `init --private` | Writes the settings file in the state folder, and registers the working folder as a root. |
| `selftest` | Runs a short shift in a `selftest-` folder under the state root, prints `PASS` or `FAIL`, and removes the folder. |

Any command that writes to the record opens a shift when none is open. A shift is left open when no session wrote to it for more than `leftOpenHours`. Such a command closes the left-open shift first, carries every ticket, and removes nothing. Then it does its work.

The command `close` is the exception. It closes a left-open shift as usual, with sidework. Sidework is the cleanup the close offers, such as old files and merged worktrees. A command that only reads never closes or opens a shift.

A session can take back the ticket it held at the last close. It does so once, on its next write to that ticket or on its `transfer`. It cannot take the ticket back when another session took it since.

## Set up a workspace

Paste this prompt into a session in the workspace folder. It installs the plugin, writes the settings file, and checks the result with almost no model use. The cheapest model is enough for it.

```
Set up the Tavern in this workspace. Do the steps in order. Show the output of every command. Stop at the first failure and show it. Do not try to fix a failure.

1. Ask me one question and wait for the answer: "Is this folder a repository shared with other people, or is it yours alone?"
2. Show me these lines and ask me to run them in a terminal opened in this folder. Tell me to skip a "marketplace add" line when that marketplace is already added. If I said the folder is shared, show --scope local in place of --scope project. Wait until I say they are done.
     claude plugin marketplace add lewisjcs/jcsl-tools
     claude plugin marketplace update jcsl-tools
     claude plugin install tavern@jcsl-tools --scope project
     codex plugin marketplace add lewisjcs/jcsl-tools
     codex plugin marketplace upgrade
     codex plugin add tavern@jcsl-tools
3. Show me these two settings and ask me to add them by hand. Wait until I say they are saved.
   Claude Code, in .claude/settings.local.json, inside permissions.allow:
     "Edit(~/.local/state/tavern/**)", "Read(~/.local/state/tavern/**)", "Write(~/.local/state/tavern/**)"
   Codex, in the config.toml of the Codex home, with my home folder written out in full:
     [sandbox_workspace_write]
     writable_roots = ["<home folder>/.local/state/tavern"]
4. Run: ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/jcsl-tools/tavern/*/runtime/bin/cli.mjs | sort -V | tail -1
   The line it prints is PROGRAM in the steps below.
5. Run: node PROGRAM init
   If I said the folder is shared, run this in its place: node PROGRAM init --private
   Show me everything it prints. Ask me the question on its "Ask the person" line. Change the settings file it named to match my answers, and show me the lines you changed.
6. Run: node PROGRAM selftest
   Its last line must be PASS.
7. Tell me these three things, then stop. Do not open a shift.
     - Start a new Claude Code session in this folder, and type /tavern:open for the first shift.
     - Trust the Tavern hooks when Codex asks.
     - Run "node PROGRAM selftest" once from a Codex thread in this folder, with PROGRAM written out in full.
```

## Install

Claude Code:

```sh
claude plugin marketplace add lewisjcs/jcsl-tools
claude plugin install tavern@jcsl-tools --scope project
```

Use `--scope local` in place of `--scope project` for a repository that other people share. Restart Claude Code after the install. Then add the permission rules in the next section.

To get a new release, run these lines, then restart Claude Code:

```sh
claude plugin marketplace update jcsl-tools
claude plugin update tavern@jcsl-tools
```

Codex:

```sh
codex plugin marketplace add lewisjcs/jcsl-tools
codex plugin add tavern@jcsl-tools
```

Trust the Tavern hooks when Codex asks. Start a new thread after you add the plugin. To get a new release, run `codex plugin marketplace upgrade`.

## State folder

The state root is `$XDG_STATE_HOME/tavern`. When that variable is not set, it is `~/.local/state/tavern`. Each workspace has one folder in the state root, named `<folder name>-<8 hex characters>`. A workspace root is a folder that holds a `tavern.json` settings file. A folder is also a workspace root when it is registered in `roots.json` and its private settings file exists. A workspace is the nearest workspace root above the working folder. At one folder, the tracked file wins.

- `boards/` holds the shift records.
- `notes.jsonl` holds one line per session note.
- `sessions/` holds one marker per ended session.
- `holding/` holds dated folders of files that approved sidework moved out of the workspace.
- `tavern.json` is the private settings file. It exists only after `init --private`.

The state root also holds `roots.json`, which lists the registered roots. A `selftest-` folder exists there only while `selftest` runs.

On Claude Code, the sandbox blocks a command from writing to the state folder. Add three permission rules to the `permissions.allow` list in a Claude Code settings file. Use the path of your state root. The example below uses the default.

```json
{
  "permissions": {
    "allow": [
      "Edit(~/.local/state/tavern/**)",
      "Read(~/.local/state/tavern/**)",
      "Write(~/.local/state/tavern/**)"
    ]
  }
}
```

No sandbox key is needed. The hooks run outside the command sandbox and need no rule.

On Codex, add the state folder to the `writable_roots` list in the `config.toml` file of the Codex home. Write your home folder out in full. If a `writable_roots` list exists, add the folder to it. Do not replace the list.

```toml
[sandbox_workspace_write]
writable_roots = ["<home folder>/.local/state/tavern"]
```

If `XDG_STATE_HOME` moves the state root, use the moved path in the Claude Code rules and in the Codex list.

## Report

The command `/tavern:report` prints a block of eleven lines. The first line is the title, `TAVERN REPORT (counts only)`. Each other line starts with its name.

- `tool` gives the Tavern version and the version of each host.
- `shifts` counts shifts opened, closed, left open, still open, and unreadable.
- `transfers` counts transfers in total, transfers that crossed hosts, and confirmed transfers.
- `ages` counts transfers by the age of the last checkpoint, and gives the longest age.
- `pivots` counts changes of plan.
- `tickets` counts tickets by status.
- `runs` counts runs by tool and by what became of each run.
- `sidework` counts offers, approvals, skips, closes with no sidework, and closes that did not run it.
- `refused` counts writes the record refused, by rule.
- `writes` counts writes to the record by host.

The block holds counts and fixed names only. It holds no title, reason, note, pointer, or path. The command writes nothing and does not open a shift.

## Settings file

The file `tavern.json` sits at the workspace root. After `init --private`, it sits in the workspace's folder in the state root instead. Every key in the table is required except `guesses`. An unknown key is an error. The file follows the schema `runtime/format/schemas/tavern-settings.schema.json`.

| Key | Type | What it sets |
|---|---|---|
| `contractId` | string | Must be `tavern:settings@1`. |
| `roadmaps.glob` | string | Which roadmap files to read. A `*` matches one whole path segment, and `**` is not allowed. |
| `roadmaps.milestonesHeading` | string | The heading text that starts the milestone list in a roadmap. |
| `roadmaps.currentMarker` | string | The text that marks the current milestone. |
| `repositories` | array of strings | Repository folders to check, relative to the workspace root. A `*` matches one path segment. |
| `pointerKinds` | array of strings | The pointer kinds a ticket can carry. At least one of `file`, `roadmap`, `branch`, `worktree`, `pr`, `run`, `key`, `link`, and `note`. |
| `leftOpenHours` | number above 0 | Hours without a write before an open shift counts as left open. |
| `maxTicketsNotFinal` | integer, 1 or more | The most tickets that can be open at once. Tickets that are final do not count. |
| `quietMinutes` | number, 0 or more | Quiet minutes before a transfer needs no question. |
| `sidework.oldFiles` | array | Folders to scan for old files. Each item has `folder`, `days`, and an optional `exclude` list of names. |
| `sidework.mergedWorktrees` | true or false | Whether the close lists worktrees whose pull request merged. |
| `sidework.untouchedShifts` | integer, 1 or more | How many shifts a ticket can wait without a change before the close lists it. |
| `sidework.holdingDays` | number above 0 | Days that moved files stay in `holding/`. |
| `guesses` | string, optional | A free note. The program does not read it. |

An example with made-up values:

```json
{
  "contractId": "tavern:settings@1",
  "roadmaps": {
    "glob": "plans/*/ROADMAP.md",
    "milestonesHeading": "## Milestones",
    "currentMarker": "(current)"
  },
  "repositories": ["repos/*"],
  "pointerKinds": ["file", "roadmap", "branch", "worktree", "pr", "link", "note"],
  "leftOpenHours": 16,
  "maxTicketsNotFinal": 12,
  "quietMinutes": 30,
  "sidework": {
    "oldFiles": [{ "folder": "scratch", "days": 30, "exclude": [".keep"] }],
    "mergedWorktrees": true,
    "untouchedShifts": 5,
    "holdingDays": 14
  }
}
```

## Requirements

- Node 22 or later.
- Claude Code or Codex.
- `gh` for pull request checks. A check that cannot run prints "not checked" with the reason, and the command still finishes.
