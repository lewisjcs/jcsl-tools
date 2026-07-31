#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$HERE/../references/cadence/smith-cadence.sh"
fail=0
assert_eq() { if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi; }

# --- Task 1: langfuse_live honors a pre-set SMITH_LANGFUSE_DOWN (short-circuit, no probe) ---
# Source the wrapper in a mode that defines functions but does not run main.
# NOTE: env vars are set as separate statements (not prefixed onto the `.` command) —
# bash's default (non-POSIX) mode does not persist a prefix assignment on a dot-source
# past the sourced command, so `VAR=1 . file` would silently lose VAR here.
( SMITH_CADENCE_LIB=1; SMITH_LANGFUSE_DOWN=1; . "$WRAPPER"; langfuse_live; echo "rc=$?" ) \
  | grep -q "^rc=1$" && echo "ok: preset-down short-circuits to down" || { echo "FAIL: preset-down"; fail=1; }

# --- probe points at an unreachable port -> down (fail-open) ---
( SMITH_CADENCE_LIB=1; SMITH_HEALTH_URL="http://127.0.0.1:1/api/public/health"; . "$WRAPPER"; langfuse_live; echo "rc=$?" ) \
  | grep -q "^rc=1$" && echo "ok: unreachable probe is down" || { echo "FAIL: unreachable probe"; fail=1; }

# --- main requires --workspace (fail LOUD: precondition, not a run) ---
out="$(bash "$WRAPPER" --last 3 2>&1)"; rc=$?
assert_eq "missing workspace exits 2" "2" "$rc"
echo "$out" | grep -q "workspace" && echo "ok: names the missing arg" || { echo "FAIL: missing-arg msg"; fail=1; }

[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
