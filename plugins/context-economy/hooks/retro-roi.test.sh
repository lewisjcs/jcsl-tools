#!/bin/bash
# Ship-gate for retro-roi.py. Builds transcripts with KNOWN per-turn usage and
# asserts the realized/counterfactual/foregone arithmetic exactly.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
ROI="$DIR/retro-roi.py"
PASS=0; FAIL=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
assert() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   — $1"; else FAIL=$((FAIL+1)); echo "  FAIL — $1 (expected [$2] got [$3])"; fi; }

# Transcript: 5 opus turns. Turns 3,4,5 (0-indexed 2,3,4) are the tail after a
# boundary at turn index 2. Each tail turn replays 1,000,000 cache_read tokens.
# Opus cache_read fallback rate = $0.50/MTok → each tail turn = $0.50 realized.
# 3 tail turns → realized = $1.50.
mk() {
  local f="$TMP/roi.jsonl" i
  : > "$f"
  for i in 0 1 2 3 4; do
    printf '{"type":"assistant","message":{"id":"m%d","model":"claude-opus-4","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":1000000}}}\n' "$i" >> "$f"
  done
  echo "$f"
}
echo "retro-roi.py"
T="$(mk)"
# Force fallback pricing (no network in tests): unset any cache by pointing HOME at TMP.
export HOME="$TMP"
OUT="$(python3 "$ROI" "$T" 2)"
assert "tail_turns from boundary index 2 = 3" "3" "$(echo "$OUT" | jq -r '.tail_turns')"
assert "realized tail = 3 turns × \$0.50 = 1.5" "1.5" "$(echo "$OUT" | jq -r '.realized_tail_usd')"
assert "model tag is optimistic" "optimistic" "$(echo "$OUT" | jq -r '.model')"
# Counterfactual < realized (reset prefix re-grows from a small floor), foregone = realized - cf.
assert "foregone = realized - counterfactual" "true" "$(echo "$OUT" | jq -r '(.realized_tail_usd - .counterfactual_usd - .savings_foregone_usd) | (. < 0.0001 and . > -0.0001)')"
assert "counterfactual is less than realized" "true" "$(echo "$OUT" | jq -r '.counterfactual_usd < .realized_tail_usd')"

# Missing transcript → error object, exit 0.
OUT2="$(python3 "$ROI" "$TMP/nope.jsonl" 0)"; rc=$?
assert "missing transcript exits 0" "0" "$rc"
assert "missing transcript returns error" "true" "$(echo "$OUT2" | jq -r 'has("error")')"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
