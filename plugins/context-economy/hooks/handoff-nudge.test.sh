#!/bin/bash
# Ship-gate for handoff-nudge.sh (UserPromptSubmit). Asserts FIRED/SILENT by grepping
# stdout for the nudge marker phrase. Throwaway $HOME.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$DIR/handoff-nudge.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
export CONTEXT_LOAD_NUDGE_TOKENS=120000

# transcript whose last assistant turn carries a given load (cache_read dominates).
make_transcript() {  # $1=load_tokens
  local load="$1" f="$TMP/t-$RANDOM.jsonl"
  printf '{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":0,"cache_read_input_tokens":%d,"cache_creation_input_tokens":0,"output_tokens":10}}}\n' "$load" > "$f"
  echo "$f"
}
mk_events() {  # $1=session  $2=include-boundary(yes/no)
  local s="$1" d="$HOME/.claude/hooks/state"; mkdir -p "$d"
  printf '{"kind":"skill","skill":"x","turn":5,"load":10}\n' > "$d/ce-events-$s.jsonl"
  [ "$2" = "yes" ] && printf '{"kind":"boundary","boundary":"commit","turn":6,"load":130000}\n' >> "$d/ce-events-$s.jsonl"
}
payload() { printf '{"session_id":"%s","transcript_path":"%s","user_prompt":"next"}' "$2" "$1"; }
run() { if printf '%s' "$1" | bash "$HOOK" | grep -q "checkpoint"; then echo FIRED; else echo SILENT; fi; }
run_rc() { printf '%s' "$1" | bash "$HOOK" >/dev/null 2>&1; echo "$?"; }
assert() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   — $1"; else FAIL=$((FAIL+1)); echo "  FAIL — $1 (exp $2 got $3)"; fi; }

echo "handoff-nudge.sh"

# 1. High load + boundary present → fires.
T="$(make_transcript 130000)"; mk_events s1 yes
assert "high load + boundary fires" "FIRED" "$(run "$(payload "$T" s1)")"

# 2. High load but NO boundary → silent (not a clean stopping point).
T="$(make_transcript 130000)"; mk_events s2 no
assert "high load without boundary is silent" "SILENT" "$(run "$(payload "$T" s2)")"

# 3. Boundary present but LOW load → silent.
T="$(make_transcript 40000)"; mk_events s3 yes
assert "low load with boundary is silent" "SILENT" "$(run "$(payload "$T" s3)")"

# 4. Missing transcript → silent, exit 0.
mk_events s4 yes
assert "missing transcript exits 0" "0" "$(run_rc "$(payload "$TMP/nope.jsonl" s4)")"

# 5. No event log yet → silent (no boundary knowable).
T="$(make_transcript 130000)"
assert "no event log is silent" "SILENT" "$(run "$(payload "$T" s5)")"

# 6. Freshness: fires once per NEW boundary, not every prompt on the same boundary.
T="$(make_transcript 130000)"; mk_events s6 yes
assert "first fire on new boundary" "FIRED" "$(run "$(payload "$T" s6)")"
assert "same boundary again is silent" "SILENT" "$(run "$(payload "$T" s6)")"
printf '{"kind":"boundary","boundary":"pr","turn":9,"load":130000}\n' >> "$HOME/.claude/hooks/state/ce-events-s6.jsonl"
assert "new boundary re-fires" "FIRED" "$(run "$(payload "$T" s6)")"

# 7. Escalation: second fire (on a NEW boundary) uses stronger wording ("Strongly consider").
T="$(make_transcript 130000)"; mk_events s7 yes
_=$(printf '%s' "$(payload "$T" s7)" | bash "$HOOK")   # fire #1 gentle
printf '{"kind":"boundary","boundary":"pr","turn":9,"load":130000}\n' >> "$HOME/.claude/hooks/state/ce-events-s7.jsonl"
out2="$(printf '%s' "$(payload "$T" s7)" | bash "$HOOK")"  # fire #2 on new boundary
assert "second fire (new boundary) escalates" "yes" "$(echo "$out2" | grep -q 'Strongly consider' && echo yes || echo no)"

# 8. Unwritable state dir → silent (fail-open the nudge itself, don't leak stderr, don't
#    re-fire every prompt because the position marker never got written).
T="$(make_transcript 130000)"; mk_events s8 yes
chmod 555 "$HOME/.claude/hooks/state"
out8="$(printf '%s' "$(payload "$T" s8)" | bash "$HOOK" 2>"$TMP/stderr8")"
assert "unwritable state dir is silent" "SILENT" "$(echo "$out8" | grep -q "checkpoint" && echo FIRED || echo SILENT)"
assert "unwritable state dir leaks no stderr" "" "$(cat "$TMP/stderr8")"
chmod 755 "$HOME/.claude/hooks/state"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
