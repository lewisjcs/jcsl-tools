#!/usr/bin/env bash
# The Smith — headless cadence wrapper (Plan B).
# Invoked by launchd (or /loop, or by hand) to run the read-only
# `/smith --emit-suggestions` briefing unattended. Fails OPEN: a broken
# morning writes nothing and returns 0-ish; the next run catches up.
set -uo pipefail

# --- library mode: `SMITH_CADENCE_LIB=1 . smith-cadence.sh` defines funcs, runs no main ---
langfuse_live() {
  # Honor an already-decided liveness (matches smith-langfuse-cost.sh's batch cache).
  [ "${SMITH_LANGFUSE_DOWN:-}" = "1" ] && return 1
  local url="${SMITH_HEALTH_URL:-http://localhost:3000/api/public/health}"
  curl -fsS -o /dev/null --max-time 5 "$url" 2>/dev/null && return 0 || return 1
}

resolve_ccusage() {
  # Bare `ccusage` is not on launchd's minimal PATH (reference_smith_ccusage_path_gap).
  # The harvester's own default is `ccusage session --json` (smith-harvest.sh:171) —
  # the value here must include that subcommand+flag, not just the binary, or the
  # harvester runs a bare invocation that prints a human table instead of JSON.
  echo "${SMITH_CCUSAGE:-npx ccusage@latest session --json}"
}

[ "${SMITH_CADENCE_LIB:-}" = "1" ] && return 0

# --- main ---
WS=""; LAST="10"; LOG_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) WS="$2"; shift 2 ;;
    --last) LAST="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    *) echo "smith-cadence: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$WS" ] || { echo "smith-cadence: --workspace <dir> is required" >&2; exit 2; }
[ -d "$WS" ] || { echo "smith-cadence: workspace not a dir: $WS" >&2; exit 2; }

# Harden our own PATH for non-launchd callers (/loop, cron, or a bare shell
# invocation) whose PATH may lack the native-installer bin dir. Idempotent-ish:
# a duplicate entry here is harmless.
export PATH="$HOME/.local/bin:$PATH"

[ -n "$LOG_DIR" ] || LOG_DIR="$WS/projects/active/kiln-smith/smith-suggestions/.cadence-logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/$STAMP.log"

{
  echo "=== smith-cadence run $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  # Cost seam (a): bare-ccusage PATH gap.
  export SMITH_CCUSAGE="$(resolve_ccusage)"
  # Cost seam (b): Langfuse liveness -> fail open to ccusage-only, stamped.
  if langfuse_live; then
    echo "langfuse: live"
  else
    export SMITH_LANGFUSE_DOWN=1
    echo "langfuse: DOWN — cost lens falls open to ccusage-only this run"
  fi
  # Plugin + settings discovery keys off cwd, not --add-dir (reference_kiln_hooks_workspace_anchor).
  # Without this cd, launchd's cwd (often /) leaves the kiln plugin out of scope and
  # `/smith` resolves to "Unknown command" while `claude -p` still exits 0 (silent failure).
  if cd "$WS" 2>/dev/null; then
    # The read-only briefing + filtered local write. No gate, no PR (Plan B invariant).
    out="$(claude -p "/smith --emit-suggestions --last $LAST" --add-dir "$WS" 2>&1)"
    rc=$?
    printf '%s\n' "$out"
    echo "=== claude -p exit: $rc ==="
    if printf '%s\n' "$out" | grep -qi "unknown command"; then
      echo "ERROR: /smith did not run (plugin not loaded in this cwd?) — failing loud"
      exit 1
    fi
    if [ "$rc" -eq 127 ] || printf '%s\n' "$out" | grep -qi "command not found"; then
      echo "ERROR: claude binary not found on PATH (exit 127) — failing loud"
      exit 1
    fi
  else
    echo "ERROR: cannot cd to workspace $WS — skipping claude run"
    exit 1
  fi
} >>"$LOG" 2>&1

# Fail-open: a genuine nonzero claude RUN (the command executed but errored) must not
# crash the launchd job into a loop. A command that never ran at all (caught above) has
# already exited 1 from inside the block, so this exit 0 only covers the fail-open case.
exit 0
