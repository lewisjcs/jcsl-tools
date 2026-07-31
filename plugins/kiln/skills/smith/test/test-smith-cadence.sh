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

# --- Task 3: render_plist substitutes every placeholder ---
INSTALLER="$HERE/../references/cadence/install-cadence.sh"
tmp_home="$(mktemp -d)"
out_plist="$tmp_home/rendered.plist"
(
  SMITH_CADENCE_LIB=1 . "$INSTALLER"
  R_WRAPPER="/x/smith-cadence.sh" R_WORKSPACE="/ws" R_LOG_DIR="/ws/logs" \
  R_HOUR="7" R_MINUTE="30" R_PATH="/usr/bin:/bin" \
  render_plist "$out_plist"
)
grep -q "__" "$out_plist" && { echo "FAIL: placeholder survived render"; fail=1; } || echo "ok: no placeholder survives"
grep -q "/x/smith-cadence.sh" "$out_plist" && echo "ok: wrapper substituted" || { echo "FAIL: wrapper subst"; fail=1; }
grep -q "<integer>7</integer>" "$out_plist" && echo "ok: hour substituted" || { echo "FAIL: hour subst"; fail=1; }

# --- rendered plist is valid ---
plutil -lint "$out_plist" >/dev/null 2>&1 && echo "ok: rendered plist lints" || { echo "FAIL: plutil lint"; fail=1; }

[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
