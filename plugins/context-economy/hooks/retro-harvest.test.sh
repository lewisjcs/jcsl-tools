#!/bin/bash
# Ship-gate for retro-harvest.sh. Seeds fake spine files + transcripts and asserts
# digest shape, last-N bounding, firing coverage, and marker-link vs null.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
H="$DIR/retro-harvest.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
SD="$HOME/.claude/hooks/state"; mkdir -p "$SD"
assert() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   — $1"; else FAIL=$((FAIL+1)); echo "  FAIL — $1 (expected [$2] got [$3])"; fi; }

mk_transcript() {  # $1=turns → path
  local n="$1" f="$TMP/tr-$RANDOM.jsonl" i; : > "$f"
  for ((i=0;i<n;i++)); do printf '{"type":"assistant","message":{"id":"m%d","model":"claude-opus-4","usage":{"cache_read_input_tokens":1000000}}}\n' "$i" >> "$f"; done
  echo "$f"
}

# Session A: fires handoff skill + a commit boundary at turn 2. transcript has 5 turns.
TA="$(mk_transcript 5)"
{
  printf '{"session":"A","kind":"skill","skill":"context-economy:handoff","turn":1,"load":100,"transcript":"%s"}\n' "$TA"
  printf '{"session":"A","kind":"boundary","boundary":"commit","turn":2,"load":500,"transcript":"%s"}\n' "$TA"
} > "$SD/ce-events-A.jsonl"

echo "retro-harvest.sh"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DA="$SD/ce-retro-A.json"
assert "digest A written" "true" "$([ -f "$DA" ] && echo true || echo false)"
assert "firing includes handoff" "true" "$(jq -r '.firing.fired | index("handoff") != null' "$DA")"
assert "context-assembly is dormant" "true" "$(jq -r '.firing.never_fired | index("context-assembly") != null' "$DA")"
assert "denominator is 5" "5" "$(jq -r '.firing.denominator' "$DA")"
assert "one boundary captured" "1" "$(jq -r '.boundaries | length' "$DA")"
assert "boundary carries optimistic ROI" "optimistic" "$(jq -r '.boundaries[0].model' "$DA")"
assert "no resumed-from → cross_clear null" "null" "$(jq -r '.rework.cross_clear' "$DA")"
assert "turns_total is max turn" "2" "$(jq -r '.turns_total' "$DA")"

# Session B: has a resumed-from marker pointing at a handoff file that names predecessor A.
HF="$TMP/handoff.md"; printf '<!-- ce-session: A -->\n# Handoff\n' > "$HF"
TB="$(mk_transcript 4)"
{
  printf '{"session":"B","kind":"resumed-from","handoff":"%s","turn":1,"load":50,"transcript":"%s"}\n' "$HF" "$TB"
} > "$SD/ce-events-B.jsonl"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DB="$SD/ce-retro-B.json"
assert "B links predecessor A via marker" "A" "$(jq -r '.rework.cross_clear.linked_predecessor' "$DB")"
assert "B link_source is marker" "marker" "$(jq -r '.rework.cross_clear.link_source' "$DB")"


# Session C: transcript with a short user-correction turn + a repeated Read of the same path.
TC="$TMP/trc.jsonl"; : > "$TC"
printf '{"type":"assistant","message":{"id":"a1","model":"claude-opus-4","usage":{"cache_read_input_tokens":1}}}\n' >> "$TC"
printf '{"type":"user","message":{"role":"user","content":"no, that is wrong"}}\n' >> "$TC"
printf '{"type":"assistant","message":{"id":"a2","model":"claude-opus-4","usage":{"cache_read_input_tokens":1},"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/dup.ts"}}]}}\n' >> "$TC"
printf '{"type":"assistant","message":{"id":"a3","model":"claude-opus-4","usage":{"cache_read_input_tokens":1},"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/dup.ts"}}]}}\n' >> "$TC"
printf '{"session":"C","kind":"boundary","boundary":"commit","turn":1,"load":10,"transcript":"%s"}\n' "$TC" > "$SD/ce-events-C.jsonl"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DC="$SD/ce-retro-C.json"
assert "C counts 1 correction turn" "1" "$(jq -r '.rework.within_session.correction_turns' "$DC")"
assert "C counts 1 repeated file read" "1" "$(jq -r '.rework.within_session.repeated_file_reads' "$DC")"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
