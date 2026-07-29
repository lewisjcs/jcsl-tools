# context-economy Setup

Complete installation and wiring instructions for the `context-economy` plugin.

## Prerequisites

- **python3** — stdlib only; no pip installs needed
- **jq** — required by the Enforcer hook (`context-reset-nudge.sh`)
- **ccstatusline** — npm package for the statusLine widget: `npm install -g ccstatusline` or invoked via `npx`
- **Claude Code** — version that supports `statusLine.type = "command"` and `customCommands[]`

## Install the plugin

Enable via your Claude Code plugin configuration using the local directory path or the marketplace reference:

```
/plugin install context-economy@ais-tech-quality-toolkit
```

Or add the repo as an `extraKnownMarketplaces` entry and install from there. Restart Claude Code after enabling.

## Wire the statusLine widget

Add the following to your `~/.claude/settings.json` (or project `.claude/settings.json`):

```json
"statusLine": {
  "type": "command",
  "command": "npx -y ccstatusline@latest",
  "padding": 0,
  "refreshInterval": 10
}
```

Then add the Observer cost widget as a `customCommands` entry so ccstatusline can embed it:

```json
"customCommands": [
  {
    "name": "cost-statusline",
    "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/cost-statusline.py --field both",
    "preserveColors": true
  }
]
```

`preserveColors: true` passes the ANSI color codes through the powerline segment renderer. The `${CLAUDE_PLUGIN_ROOT}` variable is resolved by Claude Code to the plugin's install path at runtime.

## Env var knobs

The Enforcer hook (`context-reset-nudge.sh`) exposes two calibrated defaults:

| Variable | Default | Source |
|----------|---------|--------|
| `CONTEXT_NUDGE_TURNS` | `100` | Fleet N=185: asst_msgs≥100 → 81.6% of spend; 100% marathon recall |
| `CONTEXT_NUDGE_MIN_USER_TURNS` | `5` | Fleet N=185: human_turns≥5 eliminates 100% of agentic FPs |

Set in your shell profile or Claude Code environment to override:

```bash
export CONTEXT_NUDGE_TURNS=80          # lower to nudge sooner
export CONTEXT_NUDGE_MIN_USER_TURNS=0  # set to 0 to disable the human-turn floor
```

Both defaults are calibrated against a 185-session fleet corpus. Change them only after reviewing the supporting calibration data.

## Verify the hook

Run the full Enforcer hook test suite (40 scenarios; exits non-zero on any failure):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/context-reset-nudge.test.sh"
```

All 40 scenarios should print `ok` and the final line should read `PASS=40 FAIL=0`.

## Verify the widget

Manual smoke test — replace the path with a real Claude Code session JSONL:

```bash
echo '{"transcript_path":"/path/to/session.jsonl"}' \
  | python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-statusline.py" --field both
```

Expected output: an ANSI-colored string of the form `$X.XX · YY%`. With a missing or empty path the command should exit 0 with no output (fail-silent).
