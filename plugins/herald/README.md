# Herald

Herald makes every agent reply read as natural English that explains the why. A few named kinds of document follow a stricter technical-writing register. One prose source carries both registers into Claude Code, Codex, and Cursor.

## What it ships

- An output style, `output-styles/herald.md`. Claude Code applies it whenever the plugin is enabled. The file is the single source of the rules.
- A Cursor rule, `rules/herald.mdc`, with the same body and `alwaysApply: true`.
- A Codex session hook that prints the style body as developer context.
- A linter, `hooks/herald-lint.py`, that runs after a markdown write and reports misses as additional context. It never blocks.
- A rewrite skill, `skills/herald/SKILL.md`, that applies the document register to one file and reports what the linter still flags.

## The two registers

The reply register covers every chat message. It asks for natural English, the answer first, then the why, terms defined at first use, no filler, no slop words, and no em-dashes.

The document register covers README files, files under a docs or runbooks folder, CHANGELOG files, and release notes. It asks for short sentences, simple tenses, active voice, no contractions, no semicolons, and only the modals can, will, and must.

Everything else keeps its own shape. Tickets, plans, handoffs, decision records, ADRs, RFCs, commit messages, pull request bodies, and memory files get only the reply register's word rules.

## The linter

The linter reads the file the tool wrote and picks a tier. A file is document tier when its path matches a document glob and no pull-back applies. Three pull-backs exist. The first is a deny-listed path segment (adr, rfc, decisions, plans, handoffs, tickets, specs). The second is three or more list items that contain the word shall. The third is the frontmatter line `herald: universal`. The frontmatter line `herald: document` forces the document tier. The line `herald: off` skips the file.

The universal checks are slop words, em-dashes, filler openers and closers, hard-wrapped paragraphs, and local machine paths. The document tier adds sentence length (20 words in a numbered list item, 25 elsewhere). It also adds the banned modals, present perfect, contractions, semicolons, and an -ing verb after a comma.

A report holds at most 12 hits. After two reports for one file in one session the linter stays silent for that file. Any error exits 0 with no output.

The linter skips files inside an agent configuration folder. These are the Claude configuration folder, `~/.codex`, and `~/.cursor`. The linter also skips any file under a `.claude`, `.codex`, or `.cursor` folder of the project. It judges folder names relative to the session's working folder, so a project that lives under a `docs` folder is not all document tier. In a glob, `*` stays inside one folder and `**` crosses folders, and a glob can match at any folder. The path separator is a colon on macOS and Linux. The linter needs Python 3.9 or later.

Environment variables:

- `HERALD_EXCLUDE`: extra globs to skip, separated by the path separator.
- `HERALD_DOCUMENT_GLOBS`: extra document globs, separated by the path separator.
- `HERALD_NAMES`: personal names to flag, separated by commas. The default list is empty.

Run it by hand on one file:

```bash
python3 hooks/herald-lint.py --file README.md --tier document
```

## Install

Claude Code:

```bash
claude plugin marketplace update jcsl-tools
claude plugin install herald@jcsl-tools
```

Start a new session and run `/output-style`. It shows herald as the active style.

Codex:

```bash
codex plugin marketplace update
codex plugin add herald@jcsl-tools
```

Trust the Herald hooks when Codex asks. Start a new thread. The developer context shows the Herald text.

Cursor: install the plugin from the marketplace if the installed Cursor offers a private install path. If it does not, paste the body of `rules/herald.mdc` into the user rules. Cursor plugin hooks are not part of this release.

## Cutover from simple-english and explanatory-output-style

1. In Claude Code, install herald, then disable `simple-english@simple-english` and `explanatory-output-style@claude-plugins-official`. Remove any `outputStyle` line from the settings files. Start a new session and make sure that `/output-style` shows herald.
2. In Codex, add herald, trust its hooks, and set `enabled = false` on the two old plugins in `config.toml`. Start a new thread and make sure that the developer context shows the Herald text once.
3. In Cursor, install the plugin or paste the rule body into the user rules. To try the nudge from a user-level hook, add the entry below to the user `hooks.json` and edit one README. If the Cursor CLI ignores it, leave it for the next release.
4. Rewrite any memory file that tells the agent to use the old style. The style itself carries the rule now.
5. Smoke test in one session. Make sure that a status reply reads as natural English with the why. Make sure that one README edit produces the Herald nudge.

Cursor user-level hook entry:

```json
{
  "version": 1,
  "hooks": {
    "postToolUse": [
      { "command": "python3 /absolute/path/to/herald/hooks/herald-lint.py --host cursor" }
    ]
  }
}
```

## Tests

```bash
bash plugins/herald/hooks/herald-lint.test.sh
bash plugins/herald/tests/check-rules-parity.sh
```

The first runs the linter against fixtures and asserts the exit code, the tier, and the hit categories. The second keeps `hooks/rules.json`, the output style, and the Cursor rule equal.
