#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../smith-harvest.sh"
FIX="$HERE/fixtures"
fail=0
assert_eq() { # $1=desc $2=expected $3=actual
  if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi
}

# --- Task 1: structured verdict parse (legacy verdict-N.md convention) ---
out="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$out"
assert_eq "run_id" "clean-run" "$(jq -r '.run_id' "$out")"
assert_eq "task1 spec" "pass" "$(jq -r '.tasks[0].spec' "$out")"
assert_eq "task1 quality" "approved" "$(jq -r '.tasks[0].quality' "$out")"
assert_eq "task1 criteria_met" "4" "$(jq -r '.tasks[0].criteria_met' "$out")"
assert_eq "task1 critical" "0" "$(jq -r '.tasks[0].critical_findings' "$out")"

# --- Task 1: structured verdict parse (current task-N-<slug>-verdict.md convention) ---
out2="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/new-convention-run/kiln" --out "$out2"
assert_eq "new-convention run_id" "new-convention-run" "$(jq -r '.run_id' "$out2")"
assert_eq "new-convention task n" "1" "$(jq -r '.tasks[0].n' "$out2")"
assert_eq "new-convention task spec" "pass" "$(jq -r '.tasks[0].spec' "$out2")"
assert_eq "new-convention task quality" "approved" "$(jq -r '.tasks[0].quality' "$out2")"
assert_eq "new-convention task criteria_met" "4" "$(jq -r '.tasks[0].criteria_met' "$out2")"
assert_eq "new-convention task critical" "0" "$(jq -r '.tasks[0].critical_findings' "$out2")"

# --- Task 2: friction + timestamps ---
assert_eq "fix_loops" "1" "$(jq -r '.fix_loops' "$out")"
assert_eq "friction has deviation" "true" \
  "$(jq -r '[.friction[] | test("DEVIATION")] | any' "$out")"
assert_eq "first_ts" "2026-07-13T17:26:00Z" "$(jq -r '.first_ts' "$out")"
assert_eq "last_ts" "2026-07-13T18:52:00Z" "$(jq -r '.last_ts' "$out")"

# --- Task 2 fix: mixed-precision same-minute timestamps order chronologically ---
out3="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/mixed-precision/kiln" --out "$out3"
assert_eq "mixed-precision first_ts (minute-only, earlier)" "2026-07-13T14:48Z" \
  "$(jq -r '.first_ts' "$out3")"
assert_eq "mixed-precision last_ts (full-second, later)" "2026-07-13T14:48:45Z" \
  "$(jq -r '.last_ts' "$out3")"

exit $fail
