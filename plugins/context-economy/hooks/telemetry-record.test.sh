#!/bin/bash
# Ship-gate for telemetry-record.sh. Drives the hook with mock PostToolUse stdin and
# asserts the event line is appended with the right fields. Throwaway $HOME.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$DIR/telemetry-record.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"

make_transcript() {  # $1=distinct assistant turns
  local n="$1" f="$TMP/t-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<n; i++)); do
    printf '{"type":"assistant","message":{"id":"m%d","usage":{"input_tokens":10,"cache_read_input_tokens":1000,"cache_creation_input_tokens":5,"output_tokens":20}}}\n' "$i" >> "$f"
  done
  echo "$f"
}

make_transcript_distinct_load() {  # $1=count, $2=last_turn_load (as input+cache_read+cache_creation)
  local n="$1" last_load="$2" f="$TMP/t-$RANDOM.jsonl" i early_load=100
  : > "$f"
  for ((i=0; i<n; i++)); do
    if [ $((i)) -eq $((n-1)) ]; then
      # Last turn: distinct larger load
      printf '{"type":"assistant","message":{"id":"m%d","usage":{"input_tokens":%d,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":20}}}\n' "$i" "$last_load" >> "$f"
    else
      # Earlier turns: smaller load
      printf '{"type":"assistant","message":{"id":"m%d","usage":{"input_tokens":%d,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":20}}}\n' "$i" "$early_load" >> "$f"
    fi
  done
  echo "$f"
}
assert() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   — $1"; else FAIL=$((FAIL+1)); echo "  FAIL — $1 (expected [$2] got [$3])"; fi; }

# PostToolUse payload for a Skill tool call naming skill $3.
payload() {  # $1=transcript $2=session $3=skillname
  printf '{"session_id":"%s","transcript_path":"%s","tool_name":"Skill","tool_input":{"skill":"%s"}}' "$2" "$1" "$3"
}

echo "telemetry-record.sh"

# 1. A Skill fire appends exactly one event line naming the skill.
T="$(make_transcript 12)"
printf '%s' "$(payload "$T" sess1 context-economy:handoff)" | bash "$HOOK"
LOG="$HOME/.claude/hooks/state/events-sess1.jsonl"
assert "one event line written" "1" "$(wc -l < "$LOG" | tr -d ' ')"
assert "event names the skill" "context-economy:handoff" "$(jq -r '.skill' "$LOG")"
assert "event kind is skill" "skill" "$(jq -r '.kind' "$LOG")"
assert "turn count recorded (12)" "12" "$(jq -r '.turn' "$LOG")"

# 2. Non-Skill tool call is ignored (no event).
printf '%s' '{"session_id":"sess2","transcript_path":"'"$T"'","tool_name":"Read","tool_input":{"file_path":"/x"}}' | bash "$HOOK"
assert "non-Skill tool writes nothing" "0" "$([ -f "$HOME/.claude/hooks/state/events-sess2.jsonl" ] && wc -l < "$HOME/.claude/hooks/state/events-sess2.jsonl" | tr -d ' ' || echo 0)"

# 3. Missing session_id → silent, exit 0.
printf '%s' '{"transcript_path":"'"$T"'","tool_name":"Skill","tool_input":{"skill":"x"}}' | bash "$HOOK"; rc=$?
assert "missing session_id exits 0" "0" "$rc"

# 4. .load field captures last assistant turn's distinct load (input+cache_read+cache_creation).
T_LOAD="$(make_transcript_distinct_load 5 42)"
printf '%s' "$(payload "$T_LOAD" sess3 test-skill)" | bash "$HOOK"
LOG_LOAD="$HOME/.claude/hooks/state/events-sess3.jsonl"
assert ".load equals last turn's usage sum" "42" "$(jq -r '.load' "$LOG_LOAD")"

# 5. Malformed stdin is silent on stderr.
STDERR_OUT=$(printf 'not json {{{' | bash "$HOOK" 2>&1 1>/dev/null)
assert "malformed stdin is silent on stderr" "" "$STDERR_OUT"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
