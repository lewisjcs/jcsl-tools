---
name: observer
description: Use when asked about session cost, cache percentage, spend so far, or whether a session is expensive. Triggers include "what is my session cost", "how much have I spent", "cache percentage", "am I in a heavy session", "cost so far", "cache read share", "session getting expensive".
---

# Observer

## When NOT to use

Skip when the statusLine widget is already visible and shows current values — the widget is the Observer's continuous output, no additional invocation needed.

## Overview

The Observer surfaces session cost and cache-read share so a bloating context is visible before the bill, not after. It is the sixth Party Class and its primary mechanism is `hooks/cost-statusline.py` — a fail-silent Python script that reads the Claude Code `statusLine` payload and emits an ANSI-colored cost · cache% widget.

Invoke this skill when you need to understand cost/cache state before a high-token action, or when the statusLine widget is not wired (see `SETUP.md`).

## Reading the signals

| Signal | Value | Color | Action |
|--------|-------|-------|--------|
| cache_read share | ≥ 85% | Red | Invoke Steward — context reset likely needed |
| cache_read share | 60–84% | Yellow | Watch — approaching high-cache territory |
| cache_read share | < 60% | Green | Healthy |
| Session cost | ≥ $10 | Red | Invoke Steward — heavy session, consider handoff+clear |
| Session cost | $3–$9 | Yellow | Watch — cost accumulating |
| Session cost | < $3 | Green | Healthy |

> Rates auto-refresh from LiteLLM every 24h — if ccusage shows a different number within that window, ccusage is authoritative (it fetches live every run).

**Check:** Read the current cache % and cost before proceeding. If cache ≥ 85% or cost ≥ $10, invoke the context-economy Steward skill before the next high-token action.

## Invoking the script

Run directly from any shell with the Claude Code `statusLine` payload on stdin:

```bash
echo '{"transcript_path":"/path/to/session.jsonl"}' \
  | python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-statusline.py" --field both
```

`--field cache` outputs only the cache% widget; `--field cost` outputs only the cost widget; `--field both` outputs `$cost · cache%`. No argument outputs the full standalone line including model and context fill.

The script reads `transcript_path` from the JSON payload, deduplicates assistant messages by `message.id`, and exits 0 silently on any parse or IO error — it will never block a tool call.

**Check:** After invoking, note the cache % and cost. Map to the signal table above and invoke Steward if thresholds are exceeded.

## Wiring as a statusLine widget

To have the cost · cache% widget appear continuously in your Claude Code statusLine, follow the wiring instructions in `SETUP.md`. The wiring is manual — the plugin system cannot inject `statusLine` settings automatically.

**Check:** Before a long multi-file read or Task dispatch: invoke this skill, note cache % and cost, then invoke Steward if cache ≥ 85% or cost ≥ $10.
