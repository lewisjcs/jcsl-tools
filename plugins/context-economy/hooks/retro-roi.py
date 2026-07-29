#!/usr/bin/env python3
"""Realized-vs-optimistic-counterfactual tail cost for one boundary.

Realized: cache-read cost actually paid on the bloated prefix from the boundary
turn to session end. Counterfactual (OPTIMISTIC): if context had been reset at
the boundary, the prefix re-grows linearly from a small floor — ignores any
re-orientation/rework cost, hence optimistic. All error paths print an error
object and exit 0 (fail-open, never fabricate).
"""
import sys, os, json

# Import the statusline's rate + cost primitives (single source of truth for rates).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from importlib import import_module
    _cs = import_module("cost-statusline")  # hyphenated module name
except Exception:
    _cs = None

# Optimistic counterfactual constants (first-guess; tune once real spine data exists).
CF_FLOOR_TOKENS = 20000      # reset prefix starts here
CF_GROWTH_PER_TURN = 3000    # linear re-growth per post-reset turn


def _turns(path):
    """Yield (model, usage) per distinct assistant turn, dedup by message.id."""
    seen = set()
    with open(path, "r", errors="replace") as fh:
        for line in fh:
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("type") != "assistant":
                continue
            msg = rec.get("message") or {}
            mid = msg.get("id"); usage = msg.get("usage") or {}
            if not mid or not usage or mid in seen:
                continue
            seen.add(mid)
            yield msg.get("model", ""), usage


def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "usage: retro-roi.py <transcript> <boundary_turn>", "model": "optimistic"}))
        return
    path, bnd = sys.argv[1], sys.argv[2]
    if not os.path.isfile(path):
        print(json.dumps({"error": "no transcript", "model": "optimistic"}))
        return
    try:
        boundary = int(bnd)
    except ValueError:
        print(json.dumps({"error": "bad boundary turn", "model": "optimistic"}))
        return

    pricing = _cs.load_pricing() if _cs else {}
    turns = list(_turns(path))
    tail = turns[boundary:] if 0 <= boundary < len(turns) else []
    if not tail or _cs is None:
        print(json.dumps({"error": "no tail turns or primitives unavailable", "model": "optimistic"}))
        return

    realized = 0.0
    for model, usage in tail:
        realized += _cs.cost_for(model, usage, pricing)

    # Counterfactual: same tail length, each turn pays cache_read on a re-growing
    # prefix (floor + growth×i) at the tail's representative model rate.
    rep_model = tail[0][0]
    cf = 0.0
    for i, _ in enumerate(tail):
        cf_tokens = CF_FLOOR_TOKENS + CF_GROWTH_PER_TURN * i
        cf += _cs.cost_for(rep_model, {"cache_read_input_tokens": cf_tokens}, pricing)

    realized = round(realized, 4)
    cf = round(cf, 4)
    print(json.dumps({
        "realized_tail_usd": realized,
        "counterfactual_usd": cf,
        "savings_foregone_usd": round(realized - cf, 4),
        "model": "optimistic",
        "tail_turns": len(tail),
    }))


if __name__ == "__main__":
    main()
