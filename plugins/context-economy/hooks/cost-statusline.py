#!/usr/bin/env python3
"""
Live session cost statusline — makes the structural cost driver *felt*.

The 2026-06-16 audit found the dominant local cost is not mistakes but
structure: ~98.7% Opus and ~94.9% of tokens are `cache_read` (replayed
context). You can't manage what you can't see mid-session — this surfaces it
above the prompt so a bloating context is visible *before* the bill, not after.

Reads the statusLine JSON payload on stdin (Claude Code `~/.claude/settings.json`),
parses the session transcript the same way analyze-sessions.py parses the corpus
(dedup assistant usage by message.id, validated $/MTok rates), and prints:

    $<session cost>  ·  <cache read-share>%

cache-share and cost are color-graded so a heavy session reads "hot" at a
glance. Degrades silently when no parseable usage is found.

Pricing: auto-refreshes from LiteLLM every 24h. When the cache is fresh,
the script uses the identical source ccusage fetches at runtime. When stale
or absent on first run, FALLBACK_PRICING is used for that single invocation.

Performance: computed totals are cached keyed by transcript size, so idle
redraws are instant and a re-parse happens only when the transcript grew.

All error paths exit 0 silently — this widget must never block Stop.
"""
import sys
import os
import json
import hashlib
import time
import urllib.error
import urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/context-economy-statusline")

# Lazy LiteLLM pricing refresh — same URL ccusage uses at runtime.
LITELLM_URL = 'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json'
PRICING_TTL = 86400  # seconds — 24h cache

# $/MTok fallback rates (input, output, cache_write, cache_read).
# Used only when the LiteLLM cache is absent and the fetch fails.
# Validated against ccusage v20.0.14.
FALLBACK_PRICING = {
    "opus":   {"in": 5.0,  "out": 25.0,  "cache_write": 6.25,  "cache_read": 0.50},
    "sonnet": {"in": 3.0,  "out": 15.0,  "cache_write": 3.75,  "cache_read": 0.30},
    "haiku":  {"in": 1.00, "out": 5.0,   "cache_write": 1.25,  "cache_read": 0.10},
    "fable":  {"in": 10.0, "out": 50.0,  "cache_write": 12.50, "cache_read": 1.00},
}

# ANSI — widget mode must not emit `\033[0m` (resets bg too); ccstatusline applies
# backgroundColor then adds its own reset after preserveColors content.
DIM = "\033[90m"
FG_RESET = "\033[39m"  # foreground only — keeps powerline segment background
RESET = "\033[0m"      # standalone full-line mode only
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"


def load_pricing() -> dict:
    """Return live LiteLLM pricing dict (model-id → rate fields) or {} on any failure.

    Check CACHE_DIR/pricing.json freshness (< PRICING_TTL seconds old) → load;
    if missing/stale try urllib.request.urlopen fetch → write cache; if fail return {}.
    """
    os.makedirs(CACHE_DIR, exist_ok=True)
    pricing_file = os.path.join(CACHE_DIR, "pricing.json")
    try:
        stat = os.stat(pricing_file)
        if time.time() - stat.st_mtime < PRICING_TTL:
            with open(pricing_file) as fh:
                return json.load(fh)
    except (OSError, json.JSONDecodeError, KeyError):
        pass  # intentional: fail-silent, widget must never block

    # Cache missing or stale — attempt live fetch.
    try:
        with urllib.request.urlopen(LITELLM_URL, timeout=2) as resp:
            data = resp.read()
        pricing = json.loads(data)
        try:
            with open(pricing_file, "wb") as fh:
                fh.write(data)
        except OSError:
            pass  # intentional: fail-silent, widget must never block
        return pricing
    except (urllib.error.URLError, OSError, json.JSONDecodeError):
        pass  # intentional: fail-silent, widget must never block

    return {}


def classify(model: str) -> str:
    """Map model string to FALLBACK_PRICING family key.

    Checks fable/mythos before sonnet/opus/haiku so the Fable family
    is not shadowed by a shorter match.
    """
    m = (model or "").lower()
    for fam in ("fable", "mythos", "opus", "sonnet", "haiku"):
        if fam in m:
            # mythos maps to fable family
            return "fable" if fam == "mythos" else fam
    return "other"


def cost_for(model: str, usage: dict, live_pricing: dict) -> float:
    """Compute cost for one assistant message.

    Priority:
    1. Exact model-id lookup in live_pricing (LiteLLM fields × 1e6 → $/MTok).
    2. classify(model) → FALLBACK_PRICING family.
    """
    if live_pricing and model in live_pricing:
        p = live_pricing[model]
        try:
            in_rate = (p.get("input_cost_per_token") or 0) * 1e6
            out_rate = (p.get("output_cost_per_token") or 0) * 1e6
            cw_rate = (p.get("cache_creation_input_token_cost") or 0) * 1e6
            cr_rate = (p.get("cache_read_input_token_cost") or 0) * 1e6
            return (
                usage.get("input_tokens", 0) * in_rate
                + usage.get("output_tokens", 0) * out_rate
                + usage.get("cache_creation_input_tokens", 0) * cw_rate
                + usage.get("cache_read_input_tokens", 0) * cr_rate
            ) / 1_000_000.0
        except (TypeError, KeyError):
            pass  # intentional: fail-silent, widget must never block

    fam = classify(model)
    p = FALLBACK_PRICING.get(fam)
    if not p:
        return 0.0
    return (
        usage.get("input_tokens", 0) * p["in"]
        + usage.get("output_tokens", 0) * p["out"]
        + usage.get("cache_creation_input_tokens", 0) * p["cache_write"]
        + usage.get("cache_read_input_tokens", 0) * p["cache_read"]
    ) / 1_000_000.0


def parse_transcript(path: str, live_pricing: dict) -> dict:
    """Sum cost + token mix over a CC-style JSONL transcript. Dedup assistant
    usage by message.id (CC repeats lines)."""
    if not path or not os.path.isfile(path):
        return {}
    seen = set()
    cost = 0.0
    cache_read = 0
    all_tokens = 0
    with open(path, "r", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue  # intentional: fail-silent, widget must never block
            if rec.get("type") != "assistant":
                continue
            msg = rec.get("message") or {}
            usage = msg.get("usage") or {}
            mid = msg.get("id")
            if not mid or not usage or mid in seen:
                continue
            seen.add(mid)
            model = msg.get("model", "")
            cost += cost_for(model, usage, live_pricing)
            cr = usage.get("cache_read_input_tokens", 0)
            cache_read += cr
            all_tokens += (
                usage.get("input_tokens", 0)
                + usage.get("output_tokens", 0)
                + usage.get("cache_creation_input_tokens", 0)
                + cr
            )
    return {
        "cost": round(cost, 4),
        "cache_read": cache_read,
        "all_tokens": all_tokens,
    }


def cached_totals(path: str, live_pricing: dict) -> dict:
    """Return parse_transcript(path), cached keyed by file size so idle redraws
    don't re-parse. Re-parses only when the transcript grew."""
    if not path or not os.path.isfile(path):
        return {}
    try:
        size = os.path.getsize(path)
    except OSError:
        return {}  # intentional: fail-silent, widget must never block
    os.makedirs(CACHE_DIR, exist_ok=True)
    key = hashlib.sha1(path.encode(), usedforsecurity=False).hexdigest()[:16]
    cache_file = os.path.join(CACHE_DIR, f"{key}.json")
    try:
        with open(cache_file) as fh:
            c = json.load(fh)
        if c.get("size") == size:
            return c["totals"]
    except (OSError, json.JSONDecodeError, KeyError):
        pass  # intentional: fail-silent, widget must never block
    totals = parse_transcript(path, live_pricing)
    try:
        with open(cache_file, "w") as fh:
            json.dump({"size": size, "totals": totals}, fh)
    except OSError:
        pass  # intentional: fail-silent, widget must never block
    return totals


def color_for_cache(share: float) -> str:
    return RED if share >= 85 else YELLOW if share >= 60 else GREEN


def color_for_cost(cost: float) -> str:
    return RED if cost >= 10 else YELLOW if cost >= 3 else GREEN


def main() -> None:
    # `--field cache|cost|both` emits ONE bare metric for embedding as a ccstatusline
    # custom-command widget (preserveColors renders the grading). No arg = the
    # full standalone line for a direct statusLine command.
    field = None
    if len(sys.argv) > 1 and sys.argv[1] == "--field":
        if len(sys.argv) <= 2:
            return  # intentional: fail-silent, widget must never block
        field = sys.argv[2]

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return  # intentional: fail-silent, widget must never block

    path = payload.get("transcript_path")
    live_pricing = load_pricing() if path and os.path.isfile(path) else {}
    totals = cached_totals(path, live_pricing) if path and os.path.isfile(path) else {}
    cost = totals.get("cost") if totals else None
    share = (
        100.0 * totals["cache_read"] / totals["all_tokens"]
        if totals and totals.get("all_tokens")
        else None
    )

    if field == "cache":
        if share is not None:
            sys.stdout.write(f"{color_for_cache(share)}{share:.0f}%{FG_RESET}")
        return
    if field == "cost":
        if cost is not None:
            sys.stdout.write(f"{color_for_cost(cost)}${cost:,.2f}{FG_RESET}")
        return
    if field == "both":
        # Compact + no \033[0m — full reset kills ccstatusline powerline bg.
        bits = []
        if cost is not None:
            bits.append(f"{color_for_cost(cost)}${cost:,.2f}{FG_RESET}")
        if share is not None:
            bits.append(f"{color_for_cache(share)}{share:.0f}%{FG_RESET}")
        sys.stdout.write(f"{DIM}·{FG_RESET}".join(bits))
        return

    model = (payload.get("model") or {}).get("display_name") or "?"
    ctx = (payload.get("context_window") or {}).get("used_percentage")
    ctx_str = f"{int(ctx)}" if isinstance(ctx, (int, float)) else "?"
    parts = [f"{CYAN}{model}{RESET}"]
    if cost is not None and share is not None:
        parts.append(f"{color_for_cost(cost)}${cost:,.2f}{RESET}")
        parts.append(f"{color_for_cache(share)}cache {share:.0f}%{RESET}")
    parts.append(f"{DIM}ctx {ctx_str}%{RESET}")
    sys.stdout.write(f"{DIM}  ·  {RESET}".join(parts))


if __name__ == "__main__":
    main()
