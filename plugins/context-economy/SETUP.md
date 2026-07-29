# context-economy Setup

Complete installation and wiring instructions for the `context-economy` plugin.

## Prerequisites

- **python3** — stdlib only; no pip installs needed
- **jq** — required by all three lifecycle hooks (`telemetry-record.sh`, `handoff-nudge.sh`, `context-reset-nudge.sh`)
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

## Hooks and env var knobs

Three lifecycle hooks register via `hooks/hooks.json`. All are reminders — none block the harness.

| Hook | Event | Role | Env knob(s) | Default |
|------|-------|------|-------------|---------|
| `telemetry-record.sh` | `PostToolUse` (matcher `Skill\|TodoWrite\|Bash`) | Records skill-firing + task-boundary events to `~/.claude/hooks/state/events-<session>.jsonl` | — | — |
| `handoff-nudge.sh` | `UserPromptSubmit` (matcher `*`) | **Primary.** Mid-session, boundary-gated handoff nudge — fires when token load is high at a clean task boundary | `CONTEXT_LOAD_NUDGE_TOKENS` | `120000` |
| `context-reset-nudge.sh` | `Stop` (matcher `*`) | **Backstop (trial).** Turn-count nudge, raised behind the mid-session nudge; retained until Phase 2 retro data confirms the mid-session nudge suffices | `CONTEXT_NUDGE_TURNS`, `CONTEXT_NUDGE_MIN_USER_TURNS` | `150`, `5` |

Set in your shell profile or Claude Code environment to override:

```bash
export CONTEXT_LOAD_NUDGE_TOKENS=90000  # lower to nudge sooner (mid-session, primary)
export CONTEXT_NUDGE_TURNS=100          # lower to nudge sooner (Stop, backstop)
export CONTEXT_NUDGE_MIN_USER_TURNS=0   # set to 0 to disable the human-turn floor
```

The `context-reset-nudge.sh` turn-count defaults are calibrated against a 185-session fleet corpus (originally `CONTEXT_NUDGE_TURNS=100`; raised to `150` so the Stop backstop sits behind the mid-session nudge rather than co-firing with it). Change calibrated defaults only after reviewing the supporting calibration data.

## Verify the hooks

Run all three hook test suites (each exits non-zero on any failure):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/telemetry-record.test.sh"
bash "${CLAUDE_PLUGIN_ROOT}/hooks/handoff-nudge.test.sh"
bash "${CLAUDE_PLUGIN_ROOT}/hooks/context-reset-nudge.test.sh"
```

Each suite prints `ok` per scenario and a final `PASS=<n> FAIL=0` line.

## Verify the widget

Manual smoke test — replace the path with a real Claude Code session JSONL:

```bash
echo '{"transcript_path":"/path/to/session.jsonl"}' \
  | python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-statusline.py" --field both
```

Expected output: an ANSI-colored string of the form `$X.XX · YY%`. With a missing or empty path the command should exit 0 with no output (fail-silent).
