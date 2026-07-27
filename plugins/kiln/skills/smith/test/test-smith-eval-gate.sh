#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../smith-eval-gate.sh"
FIX="$HERE/fixtures/eval-gate"
fail=0
assert_eq() { if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi; }
assert_exit() { # $1=desc $2=expected-code $3=actual-code
  if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected exit $2 got $3"; fail=1; else echo "ok: $1"; fi; }

# --- diff: good marker matches its fixture -> PASS, exit 0 ---
out="$(bash "$SCRIPT" diff "$FIX/marker-01-good.txt" "$FIX/expected-01.json")"; rc=$?
assert_eq  "diff good: says PASS" "PASS" "$out"
assert_exit "diff good: exit 0" "0" "$rc"

# --- diff: wrong lane -> FAIL names the field, exit 1 ---
out="$(bash "$SCRIPT" diff "$FIX/marker-01-wronglane.txt" "$FIX/expected-01.json")"; rc=$?
assert_eq  "diff wrong-lane: names lane" "true" "$(printf '%s' "$out" | grep -q 'FAIL: lane' && echo true || echo false)"
assert_exit "diff wrong-lane: exit 1" "1" "$rc"

# --- diff: wrong gate -> FAIL names the gate, exit 1 ---
out="$(bash "$SCRIPT" diff "$FIX/marker-03-wronggate.txt" "$FIX/expected-03.json")"; rc=$?
assert_eq  "diff wrong-gate: names PLAN-GATE" "true" "$(printf '%s' "$out" | grep -q 'PLAN-GATE' && echo true || echo false)"
assert_exit "diff wrong-gate: exit 1" "1" "$rc"

# --- diff: unparseable marker -> exit 2 (fail-loud, NOT a pass) ---
bash "$SCRIPT" diff "$FIX/marker-garbage.txt" "$FIX/expected-01.json" >/dev/null 2>&1; rc=$?
assert_exit "diff garbage: exit 2 (fail-loud)" "2" "$rc"

# --- anti-gaming: clean diff (touches lanes.md) -> exit 0 ---
bash "$SCRIPT" anti-gaming "$FIX/diff-clean.patch" >/dev/null 2>&1; rc=$?
assert_exit "anti-gaming clean: exit 0" "0" "$rc"

# --- anti-gaming: diff touches expected/ -> exit 3, names it ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-touches-fixture.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming fixture: exit 3" "3" "$rc"
assert_eq  "anti-gaming fixture: names expected/" "true" "$(printf '%s' "$out" | grep -q 'expected/' && echo true || echo false)"

# --- anti-gaming: --no-prefix diff (no a/ b/ prefix) touching expected/ -> exit 3 ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-noprefix-touches-fixture.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming no-prefix: exit 3" "3" "$rc"
assert_eq  "anti-gaming no-prefix: names expected/" "true" "$(printf '%s' "$out" | grep -q 'expected/' && echo true || echo false)"

# --- anti-gaming: subdir-rooted diff (no plugins/kiln/skills/fire/ segment) touching expected/ -> exit 3 ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-subdirrooted-touches-fixture.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming subdir-rooted: exit 3" "3" "$rc"
assert_eq  "anti-gaming subdir-rooted: names expected/" "true" "$(printf '%s' "$out" | grep -q 'expected/' && echo true || echo false)"

# --- anti-gaming: pure-rename diff (diff --git/rename from/rename to, no ---/+++) moving scenario -> exit 3 ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-rename-touches-scenario.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming rename: exit 3" "3" "$rc"
assert_eq  "anti-gaming rename: names scenarios/" "true" "$(printf '%s' "$out" | grep -q 'scenarios/' && echo true || echo false)"

# --- tally: all pass -> RECOMMENDED, exit 0 ---
out="$(bash "$SCRIPT" tally "$FIX/results-all-pass.txt" "$FIX/thresholds.yaml")"; rc=$?
assert_eq  "tally all-pass: RECOMMENDED" "true" "$(printf '%s' "$out" | grep -q 'RECOMMENDED' && echo true || echo false)"
assert_exit "tally all-pass: exit 0" "0" "$rc"

# --- tally: one regression -> OBSERVATION-ONLY names it, exit 1 ---
out="$(bash "$SCRIPT" tally "$FIX/results-one-fail.txt" "$FIX/thresholds.yaml")"; rc=$?
assert_eq  "tally one-fail: OBSERVATION-ONLY" "true" "$(printf '%s' "$out" | grep -q 'OBSERVATION-ONLY' && echo true || echo false)"
assert_eq  "tally one-fail: names scenario 09" "true" "$(printf '%s' "$out" | grep -q '09' && echo true || echo false)"
assert_exit "tally one-fail: exit 1" "1" "$rc"

exit $fail
