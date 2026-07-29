#!/bin/bash
# Ship-gate for context-reset-nudge.sh. Drives the hook with mock stdin across the
# behavioral scenarios and asserts fire/silent. Runs against a throwaway $HOME so it
# never touches real session state. Run: bash context-reset-nudge.test.sh
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$DIR/context-reset-nudge.sh"
PASS=0; FAIL=0

# Throwaway HOME so the fire-once marker dir is isolated and cleaned up.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"

# Build a transcript JSONL with N distinct assistant message ids (+ optional dupes).
make_transcript() {  # $1=distinct count  $2=dupe count of the first id
  local n="$1" dupes="${2:-0}" f="$TMP/t-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<n; i++)); do
    printf '{"type":"assistant","message":{"id":"m%d"}}\n' "$i" >> "$f"
  done
  for ((i=0; i<dupes; i++)); do
    printf '{"type":"assistant","message":{"id":"m0"}}\n' >> "$f"
  done
  echo "$f"
}

# Build a transcript of N assistant turns that carry NO message.id (the fallback path).
make_idless_transcript() {  # $1=count
  local n="$1" f="$TMP/ti-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<n; i++)); do printf '{"type":"assistant","message":{}}\n' >> "$f"; done
  echo "$f"
}

# Build a transcript that exists but is unparseable (zero valid assistant entries).
make_garbage_transcript() {
  local f="$TMP/tg-$RANDOM.jsonl"
  printf 'not json\n{broken\n[\n}\n' > "$f"
  echo "$f"
}

# Run the hook with a given stdin payload; echo "FIRED" if it emitted a nudge, else "SILENT".
run() {  # stdin via $1
  local out
  out="$(printf '%s' "$1" | bash "$HOOK")"
  if echo "$out" | grep -q "assistant turns"; then echo "FIRED"; else echo "SILENT"; fi
}

# Build a PATH dir holding every tool the hook needs EXCEPT $1 (omit nothing if $1 empty),
# so we can prove the hook stays silent when a hard dependency is absent.
restricted_path() {  # $1 = tool name to omit (optional)
  local omit="${1:-}" d="$TMP/bin-${omit:-all}-$RANDOM" t p
  mkdir -p "$d"
  for t in bash sh env cat jq python3 mkdir touch find rm dirname grep; do
    [ "$t" = "$omit" ] && continue
    p="$(command -v "$t")" && ln -s "$p" "$d/$t"
  done
  echo "$d"
}

# Run the hook under a specific PATH (command lookup of `bash` honours the prefix PATH).
run_path() {  # $1=PATH  $2=stdin payload
  local out
  out="$(printf '%s' "$2" | PATH="$1" bash "$HOOK")"
  if echo "$out" | grep -q "assistant turns"; then echo "FIRED"; else echo "SILENT"; fi
}

# Run the hook and echo its EXIT CODE. The headline contract — "never block Stop" — is an
# exit-code property (a Stop hook blocks by exiting non-zero), so it needs its own probe.
run_rc() {  # stdin via $1
  printf '%s' "$1" | bash "$HOOK" >/dev/null 2>&1
  echo "$?"
}

assert() {  # $1=label  $2=expected  $3=actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   — $1"
  else FAIL=$((FAIL+1)); echo "  FAIL — $1 (expected $2, got $3)"; fi
}

payload() {  # $1=transcript  $2=session_id  $3=stop_hook_active(true/false)
  printf '{"session_id":"%s","transcript_path":"%s","stop_hook_active":%s}' "$2" "$1" "$3"
}

export CONTEXT_NUDGE_TURNS=100
export CONTEXT_NUDGE_MIN_USER_TURNS=0   # disabled for asst-only scenarios (1-23)

echo "context-reset-nudge.sh"

# 1. Below threshold → silent.
T="$(make_transcript 99)"
assert "below threshold (99) is silent" "SILENT" "$(run "$(payload "$T" s1 false)")"

# 2. Exactly at threshold → fires (boundary-inclusive, matches EARS 'reaches').
T="$(make_transcript 100)"
assert "exactly at threshold (100) fires" "FIRED" "$(run "$(payload "$T" s2 false)")"

# 3. Above threshold → fires.
T="$(make_transcript 150)"
assert "above threshold (150) fires" "FIRED" "$(run "$(payload "$T" s3 false)")"

# 4. Fire-once: second call same session is silent (marker written by call #1).
T="$(make_transcript 150)"
_=$(run "$(payload "$T" s4 false)")          # first call fires + writes marker
assert "second call same session is silent" "SILENT" "$(run "$(payload "$T" s4 false)")"

# 5. stop_hook_active=true → silent (never fire during hook-driven continuation).
T="$(make_transcript 150)"
assert "stop_hook_active=true is silent" "SILENT" "$(run "$(payload "$T" s5 true)")"

# 6. Missing transcript file → silent (never block Stop on bad input).
assert "missing transcript is silent" "SILENT" "$(run "$(payload "$TMP/nope.jsonl" s6 false)")"

# 7. Duplicate message ids dedupe: 99 distinct + 50 dupes of m0 = 99 turns → silent.
T="$(make_transcript 99 50)"
assert "duplicate message ids dedupe (99 distinct stays below 100)" "SILENT" "$(run "$(payload "$T" s7 false)")"

# 8. python3 absent → silent. Hook must fail CLOSED on a missing hard dependency, never
#    fire with a blank count (regression: empty TURNS fell through the arithmetic guard).
T="$(make_transcript 150)"
assert "python3 absent is silent (fails closed)" "SILENT" "$(run_path "$(restricted_path python3)" "$(payload "$T" s8 false)")"

# 9. jq absent → silent. Without jq the payload cannot be parsed; the hook must not fire.
T="$(make_transcript 150)"
assert "jq absent is silent (fails closed)" "SILENT" "$(run_path "$(restricted_path jq)" "$(payload "$T" s9 false)")"

# 10. Non-numeric CONTEXT_NUDGE_TURNS → silent. A bad config must not coerce a fire.
T="$(make_transcript 150)"
assert "non-numeric threshold is silent" "SILENT" \
  "$(out="$(printf '%s' "$(payload "$T" s10 false)" | CONTEXT_NUDGE_TURNS=abc bash "$HOOK")"; \
     echo "$out" | grep -q 'assistant turns' && echo FIRED || echo SILENT)"

# 11. Sanity: full PATH (nothing omitted) still fires above threshold — proves the
#     restricted-PATH harness isn't masking a real fire.
T="$(make_transcript 150)"
assert "full PATH still fires above threshold" "FIRED" "$(run_path "$(restricted_path)" "$(payload "$T" s11 false)")"

# 12. Exit code is 0 when FIRING — "never block Stop" must hold even on the fire path.
T="$(make_transcript 150)"
assert "exit 0 on fire (never blocks Stop)" "0" "$(run_rc "$(payload "$T" s12 false)")"

# 13. Exit code is 0 when SILENT (below threshold) — the common path must never block.
T="$(make_transcript 50)"
assert "exit 0 on silent/below-threshold" "0" "$(run_rc "$(payload "$T" s13 false)")"

# 14. Exit code is 0 on bad input (missing transcript) — never block Stop on garbage.
assert "exit 0 on missing transcript" "0" "$(run_rc "$(payload "$TMP/nope.jsonl" s14 false)")"

# 15. Unwritable state dir → silent (fail closed, do NOT re-fire every Stop).
#     Make $HOME/.claude a regular FILE so mkdir -p "$HOME/.claude/hooks/state" fails.
BADHOME="$TMP/badhome-$RANDOM"; mkdir -p "$BADHOME"; : > "$BADHOME/.claude"
T="$(make_transcript 150)"
got="$(printf '%s' "$(payload "$T" s15 false)" | HOME="$BADHOME" bash "$HOOK" 2>/dev/null | grep -q 'assistant turns' && echo FIRED || echo SILENT)"
assert "unwritable state dir is silent (no re-fire)" "SILENT" "$got"

# 16. HOME unset → silent (no root-anchored /.claude write, no re-fire).
T="$(make_transcript 150)"
got="$(printf '%s' "$(payload "$T" s16 false)" | env -u HOME bash "$HOOK" 2>/dev/null | grep -q 'assistant turns' && echo FIRED || echo SILENT)"
assert "HOME unset is silent" "SILENT" "$got"

# 17. CONTEXT_NUDGE_TURNS=0 → silent. Zero is digits but not a positive threshold;
#     it must NOT fire on the first Stop of every session.
T="$(make_transcript 1)"
got="$(printf '%s' "$(payload "$T" s17 false)" | CONTEXT_NUDGE_TURNS=0 bash "$HOOK" 2>/dev/null | grep -q 'assistant turns' && echo FIRED || echo SILENT)"
assert "threshold 0 is silent (positive-integer only)" "SILENT" "$got"

# 18. id-less assistant entries count deterministically as distinct turns:
#     150 entries with no message.id reach the threshold and fire.
T="$(make_idless_transcript 150)"
assert "id-less turns count deterministically (150 fires)" "FIRED" "$(run "$(payload "$T" s18 false)")"

# 19. id-less below threshold stays silent (50 distinct id-less turns < 100).
T="$(make_idless_transcript 50)"
assert "id-less below threshold is silent (50)" "SILENT" "$(run "$(payload "$T" s19 false)")"

# 20. Existing-but-unparseable transcript → silent (count 0; named in the hook contract).
T="$(make_garbage_transcript)"
assert "unparseable transcript is silent" "SILENT" "$(run "$(payload "$T" s20 false)")"

# 21. On fire, an auditable line is appended to the fire-log with session id + turn count.
LOG="$HOME/.claude/hooks/state/context-nudge.log"
T="$(make_transcript 150)"
_=$(run "$(payload "$T" s21 false)")
got="$( [ -f "$LOG" ] && grep -q 'session=s21' "$LOG" && grep -q 'turns=150' "$LOG" && echo LOGGED || echo MISSING )"
assert "fire appends an auditable log line (session + turns)" "LOGGED" "$got"

# 22. On silent (below threshold), NOTHING is appended to the fire-log.
rm -f "$LOG"
T="$(make_transcript 50)"
_=$(run "$(payload "$T" s22 false)")
got="$( [ -f "$LOG" ] && grep -q 'session=s22' "$LOG" && echo LOGGED || echo NONE )"
assert "silent run writes no log line" "NONE" "$got"

# 23. Log-write failure must NOT suppress the nudge (logging is observability, not a gate).
#     Make the log path a directory so the append fails; the hook must still FIRE and exit 0.
rm -rf "$HOME/.claude/hooks/state/context-nudge.log"
mkdir -p "$HOME/.claude/hooks/state/context-nudge.log"   # now an append target that errors
T="$(make_transcript 150)"
assert "log-write failure still fires (best-effort log)" "FIRED" "$(run "$(payload "$T" s23 false)")"
assert "log-write failure still exits 0" "0" "$(run_rc "$(payload "$(make_transcript 150)" s23b false)")"
rm -rf "$HOME/.claude/hooks/state/context-nudge.log"

# ── Composite gate (MIN_USER_TURNS) scenarios ────────────────────────────────
# Build a transcript with N assistant turns and M human turns.
make_mixed_transcript() {  # $1=asst_count  $2=human_count
  local na="$1" nh="$2" f="$TMP/tm-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<na; i++)); do printf '{"type":"assistant","message":{"id":"a%d"}}\n' "$i" >> "$f"; done
  for ((i=0; i<nh; i++)); do printf '{"type":"human","message":{"id":"h%d"}}\n' "$i" >> "$f"; done
  echo "$f"
}

export CONTEXT_NUDGE_MIN_USER_TURNS=5

# 24. Agentic fan-out: 120 asst, 2 human → must NOT fire (human floor not met).
T="$(make_mixed_transcript 120 2)"
assert "agentic fan-out (120 asst / 2 human) is silent" "SILENT" "$(run "$(payload "$T" s24 false)")"

# 25. Deep session at boundary: 300 asst, 15 human → must fire.
T="$(make_mixed_transcript 300 15)"
assert "deep session (300 asst / 15 human) fires" "FIRED" "$(run "$(payload "$T" s25 false)")"

# 26. Short session below asst threshold: 50 asst, 8 human → must NOT fire.
T="$(make_mixed_transcript 50 8)"
assert "short session (50 asst / 8 human) is silent" "SILENT" "$(run "$(payload "$T" s26 false)")"

# 27. Exactly at both thresholds: 100 asst, 5 human → must fire (boundary-inclusive).
T="$(make_mixed_transcript 100 5)"
assert "exactly at thresholds (100 asst / 5 human) fires" "FIRED" "$(run "$(payload "$T" s27 false)")"

# 28. Below human floor by one: 150 asst, 4 human → must NOT fire.
T="$(make_mixed_transcript 150 4)"
assert "below human floor by one (150 asst / 4 human) is silent" "SILENT" "$(run "$(payload "$T" s28 false)")"

# 29. Sonnet-tier archetype: 155 asst, 13 human → must fire.
T="$(make_mixed_transcript 155 13)"
assert "sonnet archetype (155 asst / 13 human) fires" "FIRED" "$(run "$(payload "$T" s29 false)")"

# 30. Non-numeric MIN_USER_TURNS → skip human check (fail-open), fire on asst alone.
T="$(make_mixed_transcript 150 2)"
assert "non-numeric MIN_USER_TURNS skips check and fires on asst" "FIRED" \
  "$(out="$(printf '%s' "$(payload "$T" s30 false)" | CONTEXT_NUDGE_MIN_USER_TURNS=abc bash "$HOOK")"; \
     echo "$out" | grep -q 'assistant turns' && echo FIRED || echo SILENT)"

# 31. MIN_USER_TURNS=0 → human floor disabled (0 human turns still fires if asst >= threshold).
T="$(make_mixed_transcript 150 0)"
assert "MIN_USER_TURNS=0 disables human floor (fires)" "FIRED" \
  "$(out="$(printf '%s' "$(payload "$T" s31 false)" | CONTEXT_NUDGE_MIN_USER_TURNS=0 bash "$HOOK")"; \
     echo "$out" | grep -q 'assistant turns' && echo FIRED || echo SILENT)"

# ── Corpus-regression scenarios (S1–S8) ─────────────────────────────────────
# Build a transcript with N assistant turns and M human turns.
# Human lines use {"type":"human","message":{}} — no id field — matching real
# transcript shape (human messages are never deduplicated in the hook).
make_transcript_with_human() {  # $1=asst_count  $2=human_count
  local na="$1" nh="$2" f="$TMP/twh-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<na; i++)); do printf '{"type":"assistant","message":{"id":"m%d"}}\n' "$i" >> "$f"; done
  for ((i=0; i<nh; i++)); do printf '{"type":"human","message":{}}\n' >> "$f"; done
  echo "$f"
}

export CONTEXT_NUDGE_TURNS=100
export CONTEXT_NUDGE_MIN_USER_TURNS=5

# S1. Agentic fan-out minimal human: 124 asst, 1 human → SILENT (human floor not met).
T="$(make_transcript_with_human 124 1)"
assert "S1: agentic fan-out minimal human (124 asst / 1 human) is silent" "SILENT" "$(run "$(payload "$T" sS1 false)")"

# S2. Deep marathon: 350 asst, 20 human → FIRED (both conditions met).
T="$(make_transcript_with_human 350 20)"
assert "S2: deep marathon (350 asst / 20 human) fires" "FIRED" "$(run "$(payload "$T" sS2 false)")"

# S3. Short focused task: 50 asst, 8 human → SILENT (turn gate not met).
T="$(make_transcript_with_human 50 8)"
assert "S3: short focused task (50 asst / 8 human) is silent" "SILENT" "$(run "$(payload "$T" sS3 false)")"

# S4. Exact lower bound: 100 asst, 5 human → FIRED (boundary-inclusive).
T="$(make_transcript_with_human 100 5)"
assert "S4: threshold boundary exact lower (100 asst / 5 human) fires" "FIRED" "$(run "$(payload "$T" sS4 false)")"

# S5. Human floor near-miss: 150 asst, 4 human → SILENT (human floor not met by 1).
T="$(make_transcript_with_human 150 4)"
assert "S5: human floor near-miss (150 asst / 4 human) is silent" "SILENT" "$(run "$(payload "$T" sS5 false)")"

# S6. Sonnet marathon top: 155 asst, 13 human → FIRED.
T="$(make_transcript_with_human 155 13)"
assert "S6: Sonnet marathon top (155 asst / 13 human) fires" "FIRED" "$(run "$(payload "$T" sS6 false)")"

# S7. Corrections-heavy: 200 asst, 20 human → FIRED.
T="$(make_transcript_with_human 200 20)"
assert "S7: corrections-heavy (200 asst / 20 human) fires" "FIRED" "$(run "$(payload "$T" sS7 false)")"

# S8. Cost signal fallback (floor disabled): 80 asst, 10 human, MIN_USER_TURNS=0 → SILENT.
# Verifies that disabling the floor does NOT magically enable turn-gate firing below threshold.
T="$(make_transcript_with_human 80 10)"
assert "S8: floor disabled but asst<100 is silent (turn gate does not fire)" "SILENT" \
  "$(out="$(printf '%s' "$(payload "$T" sS8 false)" | CONTEXT_NUDGE_MIN_USER_TURNS=0 bash "$HOOK")"; \
     echo "$out" | grep -q 'assistant turns' && echo FIRED || echo SILENT)"

unset CONTEXT_NUDGE_TURNS CONTEXT_NUDGE_MIN_USER_TURNS

# ── type=user format regression (S9–S11) ────────────────────────────────────
# Claude Code changed interactive turn type from "human" to "user" (post-Jun-17-2026).
# These scenarios use the current transcript shape and are the primary regression guard.
make_user_transcript() {  # $1=asst_count  $2=user_count
  local na="$1" nu="$2" f="$TMP/tu-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<na; i++)); do printf '{"type":"assistant","message":{"id":"m%d"}}\n' "$i" >> "$f"; done
  for ((i=0; i<nu; i++)); do printf '{"type":"user","message":{}}\n' >> "$f"; done
  echo "$f"
}

export CONTEXT_NUDGE_TURNS=100
export CONTEXT_NUDGE_MIN_USER_TURNS=5

# S9. Interactive session with type=user turns: 110 asst, 6 user → FIRED.
T="$(make_user_transcript 110 6)"
assert "S9: type=user turns count toward floor (110 asst / 6 user) fires" "FIRED" "$(run "$(payload "$T" sS9 false)")"

# S10. type=user human floor not met: 150 asst, 3 user → SILENT.
T="$(make_user_transcript 150 3)"
assert "S10: type=user below floor (150 asst / 3 user) is silent" "SILENT" "$(run "$(payload "$T" sS10 false)")"

# S11. Mixed type=user and type=human both count: 100 asst, 3 user + 2 human = 5 total → FIRED.
T="$TMP/tmix-$RANDOM.jsonl"
: > "$T"
for ((i=0; i<100; i++)); do printf '{"type":"assistant","message":{"id":"m%d"}}\n' "$i" >> "$T"; done
for ((i=0; i<3; i++)); do printf '{"type":"user","message":{}}\n' >> "$T"; done
for ((i=0; i<2; i++)); do printf '{"type":"human","message":{}}\n' >> "$T"; done
assert "S11: mixed type=user and type=human both count (100 asst / 5 mixed human) fires" "FIRED" "$(run "$(payload "$T" sS11 false)")"

unset CONTEXT_NUDGE_TURNS CONTEXT_NUDGE_MIN_USER_TURNS

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
