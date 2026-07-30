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
# Denominator is derived from skills on disk (5 shipped, excluding context-economy-retro).
assert "denominator is 5 (derived from disk)" "5" "$(jq -r '.firing.denominator' "$DA")"
assert "observer is expected_dormant (carve-out)" "true" "$(jq -r '.firing.expected_dormant | index("observer") != null' "$DA")"
assert "context-economy-retro NOT counted" "false" "$(jq -r '(.firing.fired + .firing.never_fired) | index("context-economy-retro") != null' "$DA")"
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

# Session BN: a resumed-from event whose handoff has NO real ce-session marker (an unstamped
# PENDING placeholder — stamp hook never ran). This must yield cross_clear == null, NOT a
# {linked_predecessor:"null"|"PENDING"} object. Regression guard for the bash-"null"-string bug:
# building the object made the `!= null` guards report every unlinked session as linked.
HFP="$TMP/handoff-pending.md"; printf '<!-- ce-session: PENDING -->\n# Handoff\n' > "$HFP"
TBN="$(mk_transcript 3)"
printf '{"session":"BN","kind":"resumed-from","handoff":"%s","turn":1,"load":50,"transcript":"%s"}\n' "$HFP" "$TBN" > "$SD/ce-events-BN.jsonl"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DBN="$SD/ce-retro-BN.json"
assert "resumed-from + PENDING marker → cross_clear null (not false link)" "null" "$(jq -r '.rework.cross_clear' "$DBN")"

# Session BM: resumed-from event, handoff file exists but has NO marker line at all → also null.
HFM="$TMP/handoff-nomarker.md"; printf '# Handoff\nno marker\n' > "$HFM"
TBM="$(mk_transcript 3)"
printf '{"session":"BM","kind":"resumed-from","handoff":"%s","turn":1,"load":50,"transcript":"%s"}\n' "$HFM" "$TBM" > "$SD/ce-events-BM.jsonl"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DBM="$SD/ce-retro-BM.json"
assert "resumed-from + markerless handoff → cross_clear null" "null" "$(jq -r '.rework.cross_clear' "$DBM")"


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

# Session D: post-assistant user turns "I know" / "not sure now" must NOT count as
# corrections — bare short cues like "no" are substrings of "know"/"now"/"not", but
# these turns don't actually contain the whole-word cue "no".
TD="$TMP/trd.jsonl"; : > "$TD"
printf '{"type":"assistant","message":{"id":"d1","model":"claude-opus-4","usage":{"cache_read_input_tokens":1}}}\n' >> "$TD"
printf '{"type":"user","message":{"role":"user","content":"I know"}}\n' >> "$TD"
printf '{"type":"assistant","message":{"id":"d2","model":"claude-opus-4","usage":{"cache_read_input_tokens":1}}}\n' >> "$TD"
printf '{"type":"user","message":{"role":"user","content":"not sure now"}}\n' >> "$TD"
printf '{"session":"D","kind":"boundary","boundary":"commit","turn":1,"load":10,"transcript":"%s"}\n' "$TD" > "$SD/ce-events-D.jsonl"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DD="$SD/ce-retro-D.json"
assert "D: 'I know'/'not sure now' are not corrections" "0" "$(jq -r '.rework.within_session.correction_turns' "$DD")"

# Session E: predecessor E1 + resume session E2 (linked via handoff marker) both Read
# the same overlapping file path → post_resume_rereads counts the intersection.
TE1="$TMP/tre1.jsonl"; : > "$TE1"
printf '{"type":"assistant","message":{"id":"e1a","model":"claude-opus-4","usage":{"cache_read_input_tokens":1},"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/shared.ts"}}]}}\n' >> "$TE1"
printf '{"type":"assistant","message":{"id":"e1b","model":"claude-opus-4","usage":{"cache_read_input_tokens":1},"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/only-in-e1.ts"}}]}}\n' >> "$TE1"
printf '{"session":"E1","kind":"skill","skill":"noop","turn":1,"load":10,"transcript":"%s"}\n' "$TE1" > "$SD/ce-events-E1.jsonl"

TE2="$TMP/tre2.jsonl"; : > "$TE2"
printf '{"type":"assistant","message":{"id":"e2a","model":"claude-opus-4","usage":{"cache_read_input_tokens":1},"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/shared.ts"}}]}}\n' >> "$TE2"
printf '{"type":"assistant","message":{"id":"e2b","model":"claude-opus-4","usage":{"cache_read_input_tokens":1},"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/only-in-e2.ts"}}]}}\n' >> "$TE2"
HFE="$TMP/handoff-e.md"; printf '<!-- ce-session: E1 -->\n# Handoff\n' > "$HFE"
printf '{"session":"E2","kind":"resumed-from","handoff":"%s","turn":1,"load":10,"transcript":"%s"}\n' "$HFE" "$TE2" > "$SD/ce-events-E2.jsonl"
bash "$H" --last 10 --state-dir "$SD" >/dev/null
DE2="$SD/ce-retro-E2.json"
assert "E2 links predecessor E1" "E1" "$(jq -r '.rework.cross_clear.linked_predecessor' "$DE2")"
assert "E2 post_resume_rereads counts overlapping file (1)" "1" "$(jq -r '.rework.cross_clear.post_resume_rereads' "$DE2")"

# --- NEW: langfuse cost lens folds into the digest ---
LF_STATE="$(mktemp -d)"
printf '{"kind":"skill","skill":"handoff","turn":3,"ts":"2026-07-30T10:00:00Z"}\n' > "$LF_STATE/ce-events-lfsess.jsonl"
LF_RESP="$(mktemp)"
cat > "$LF_RESP" <<'JSON'
{"data":[
  {"name":"Claude Code - Turn 1","sessionId":"lfsess","totalCost":1.5},
  {"name":"crafter · Turn 1","sessionId":"lfsess","totalCost":0.5}
],"meta":{}}
JSON
export CE_LANGFUSE_RESPONSE="$LF_RESP"
bash "$H" --last 1 --state-dir "$LF_STATE" >/dev/null
dg="$LF_STATE/ce-retro-lfsess.json"
assert "digest written" "true" "$( [ -f "$dg" ] && echo true || echo false )"
assert "cost.session_cost_usd = 2" "2" "$(jq -r '.cost.session_cost_usd' "$dg")"
assert "cost.delegation_cost_usd = 0.5" "0.5" "$(jq -r '.cost.delegation_cost_usd' "$dg")"
assert "langfuse in lenses_available" "true" "$(jq -r '.lenses_available | index("langfuse") != null' "$dg")"
unset CE_LANGFUSE_RESPONSE

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
