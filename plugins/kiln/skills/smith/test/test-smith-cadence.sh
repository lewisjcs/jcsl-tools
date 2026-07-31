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

# --- Task 5: main fails OPEN — a nonzero `claude -p` must not crash the launchd job ---
# The safety-critical property of the whole cadence: a broken morning writes nothing
# and the wrapper still returns 0, so launchd never crash-loops (design §6(e)).
# Stub `claude` (PATH-prepended) to exit nonzero; assert the wrapper exits 0 anyway.
stub_dir="$(mktemp -d)"
cat > "$stub_dir/claude" <<'STUB'
#!/usr/bin/env bash
echo "stubbed claude: simulated failure" >&2
exit 7
STUB
chmod +x "$stub_dir/claude"
ws_dir="$(mktemp -d)"
( PATH="$stub_dir:$PATH"; SMITH_LANGFUSE_DOWN=1; bash "$WRAPPER" --workspace "$ws_dir" --last 3 >/dev/null 2>&1 )
rc=$?
assert_eq "fail-open: nonzero claude still exits 0" "0" "$rc"
# The failed run must leave a log (audit trail) but never a partial suggestions file.
ls "$ws_dir/projects/active/kiln-smith/smith-suggestions/.cadence-logs/"*.log >/dev/null 2>&1 \
  && echo "ok: fail-open run still wrote its log" || { echo "FAIL: no cadence log written"; fail=1; }
sug_files="$(find "$ws_dir/projects/active/kiln-smith/smith-suggestions" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "fail-open: no partial suggestions .md written" "0" "$sug_files"

# --- Fix round 1: main fails LOUD when /smith never ran (plugin not loaded in cwd) ---
# Distinguishes "claude ran /smith and it errored" (stays fail-open, above) from
# "claude never resolved /smith at all" (a configuration failure — must surface, not retry
# silently forever under launchd). Stub `claude` to print "Unknown command: /smith" and
# exit 0 (mirrors the real silent-failure signature), then assert the wrapper exits nonzero
# and the log records the ERROR line.
stub_dir2="$(mktemp -d)"
cat > "$stub_dir2/claude" <<'STUB'
#!/usr/bin/env bash
echo "Unknown command: /smith"
exit 0
STUB
chmod +x "$stub_dir2/claude"
ws_dir2="$(mktemp -d)"
( PATH="$stub_dir2:$PATH"; SMITH_LANGFUSE_DOWN=1; bash "$WRAPPER" --workspace "$ws_dir2" --last 3 >/dev/null 2>&1 )
rc=$?
assert_eq "fail-loud: unresolved /smith exits nonzero" "1" "$rc"
log_file2="$(find "$ws_dir2/projects/active/kiln-smith/smith-suggestions/.cadence-logs/" -maxdepth 1 -name '*.log' 2>/dev/null | head -n1)"
if [ -n "$log_file2" ] && grep -q "ERROR: /smith did not run" "$log_file2"; then
  echo "ok: fail-loud run logs the ERROR line"
else
  echo "FAIL: fail-loud ERROR line missing from log"; fail=1
fi

# --- Bug fix: resolve_ccusage default must include the `session --json`
# subcommand+flag, not just the binary — the harvester consumes this value
# as a full command (smith-harvest.sh:171 default is `ccusage session --json`),
# and a bare `npx ccusage@latest` prints a human table, not JSON. ---
resolved="$( ( SMITH_CADENCE_LIB=1; unset SMITH_CCUSAGE; . "$WRAPPER"; resolve_ccusage ) )"
case "$resolved" in
  *"session --json") echo "ok: resolve_ccusage default ends with session --json" ;;
  *) echo "FAIL: resolve_ccusage default missing session --json subcommand — got [$resolved]"; fail=1 ;;
esac

[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
