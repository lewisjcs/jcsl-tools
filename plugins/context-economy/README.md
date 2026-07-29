# Context Economy Party

A Claude Code plugin implementing the **Context Economy Party** — six Classes working together to spend main-thread context economically without sacrificing accuracy.

**No build step, nothing to install** — five markdown skills, three bash hooks, one Python statusline widget. Every hook uses `jq` and `python3` when present and no-ops safely if either is missing.

## The Party

| Class | Role | Artifact |
|---|---|---|
| **Steward** | Router — names the lever before high-token actions | `skills/context-economy` |
| **Assembler** | Scopes context before it hits the main thread | `skills/context-assembly` |
| **Delegator** | Pushes bounded work off-thread with a four-part dispatch contract | `skills/delegating-to-subagents` |
| **Chronicler** | Checkpoints before `/clear` so work resumes lean | `skills/handoff` |
| **Enforcer** | Fires a mid-session, boundary-gated handoff nudge (primary) plus a turn-count Stop nudge (backstop, trial) | `hooks/handoff-nudge.sh`, `hooks/context-reset-nudge.sh` |
| **Observer** | Records skill-firing + task-boundary telemetry; surfaces session cost and cache-read share mid-session | `hooks/telemetry-record.sh`, `hooks/cost-statusline.py` |

**Party coverage rule:** Before any high-token action (multi-file read, broad grep, large log pull, Task/explore dispatch, session reset), name which Class owns the decision and invoke its skill.

## Scripts

| Script | What it does |
|--------|--------------|
| `cost-statusline.py` | Reads Claude Code `statusLine` payload from stdin, outputs `$cost · cache%` ANSI-colored widget. See `SETUP.md` for wiring instructions. |

## Skills

| Skill | What it does |
|---|---|
| `context-economy` | Steward lever router + clear-vs-compact doctrine + context budget (static/dynamic/enforced). Fires via `<HARD-GATE>` before multi-file reads, broad greps, and Task dispatches. |
| `context-assembly` | Assembler patterns: grep-first, read-narrow, delegate exploration, return contract. Invoked from context-economy before loading files or logs. |
| `delegating-to-subagents` | Delegator dispatch gate: delegate-vs-keep table, four-part contract, worked example, return contract. |
| `handoff` | Chronicler checkpoint: writes `.handoffs/<date>.md` + copy-pasteable resume prompt before `/clear`. |

## Hooks: Observer + Enforcer

Three hooks work together across the session lifecycle. All are reminders — none ever block the harness.

### `telemetry-record.sh` (PostToolUse, matcher `Skill|TodoWrite|Bash`)

Appends one JSONL event per Skill firing or task-boundary tool call (a completed `TodoWrite` item, a `git commit`, or a `gh pr create`) to `~/.claude/hooks/state/events-<session_id>.jsonl`. Each event carries a distinct-turn count and a token-load proxy (last assistant turn's `input_tokens + cache_read + cache_creation`). This log is the shared substrate the handoff nudge reads to detect boundaries — no config knobs.

### `handoff-nudge.sh` (UserPromptSubmit, matcher `*`) — **primary**

Fires when the token-load proxy is at or above `CONTEXT_LOAD_NUDGE_TOKENS` (default `120000`) **and** a new task boundary has landed since the last fire — a clean stopping point, not every prompt. Escalates wording on repeat fires within the same session.

```bash
export CONTEXT_LOAD_NUDGE_TOKENS=120000   # lower to nudge sooner
```

### `context-reset-nudge.sh` (Stop, matcher `*`) — **backstop, trial**

Fires once per session when **both** conditions hold: assistant turns ≥ `CONTEXT_NUDGE_TURNS` (default `150`) AND human turns ≥ `CONTEXT_NUDGE_MIN_USER_TURNS` (default `5`). The human-turn floor eliminates false positives from agentic fan-out sessions (150+ assistant turns from subagent loops with 1–3 human prompts). As a backstop, it sits behind the mid-session handoff nudge: it catches long-but-low-load sessions, or ones with no clean boundary, that the primary nudge does not. (trial)

```bash
export CONTEXT_NUDGE_TURNS=150          # lower to nudge sooner
export CONTEXT_NUDGE_MIN_USER_TURNS=5   # set to 0 to disable the floor
```

The turn-count gate defaults are calibrated against a 185-session fleet corpus. The hook fires at most once per session (fire-once marker), parses the transcript JSONL (deduped on `message.id`), and appends an auditable line to `~/.claude/hooks/state/context-nudge.log`. Any missing input exits 0 silently (fail-closed).

## Behavioral fixtures

Five operator-in-loop verification scenarios live in `fixtures/`. Each has a `prompt.md` and an `expected.md` with checkbox pass criteria.

| Fixture | Scenario | Class |
|---|---|---|
| `CE-01-delegate-search` | Find every usage of a function across a monorepo | Delegator |
| `CE-02-narrow-read` | Debug a 500+ line test failure | Assembler |
| `CE-03-handoff-boundary` | Checkpoint before switching tasks | Chronicler |
| `CE-04-clear-default` | Task boundary — new unrelated work | Steward |
| `CE-05-router-gate` | "Read all files in src/" | Steward HARD-GATE |

See `fixtures/README.md` for the verify procedure. Target: ≥3/5 pass before ship.

## Class manifests

`classes/*.class.json` — descriptive manifests (`schemaVersion: "1.0-descriptive"`) with `identity.constraints`, `rigor.grounding` (arXiv + internal baselines), `rigor.calibration` (fixture IDs), and `rigor.provenance` for each Class.

## Install

Enable through Claude Code plugin configuration. All three hooks register via `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` — no machine-specific paths, no edits to your personal `settings.json`. Restart Claude Code after enabling.

## Verify

```bash
bash hooks/telemetry-record.test.sh      # exits non-zero on any failure
bash hooks/handoff-nudge.test.sh         # exits non-zero on any failure
bash hooks/context-reset-nudge.test.sh   # exits non-zero on any failure
```

## Research grounding

Lean context is also higher-accuracy context:
- **NoLiMa** (arXiv 2502.05167): multi-fact reasoning degrades before the window fills
- **Lost in the Middle** (arXiv 2307.03172): front-load rules; narrow windows
- **Internal baseline**: ~86.6% of $ is cache-read; sessions >100 turns ≈ 92% of tokens

See `references/research-corpus.md` for full citations.
