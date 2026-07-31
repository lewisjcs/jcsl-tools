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
  echo "${SMITH_CCUSAGE:-npx ccusage@latest}"
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
  # The read-only briefing + filtered local write. No gate, no PR (Plan B invariant).
  claude -p "/smith --emit-suggestions --last $LAST" --add-dir "$WS" 2>&1
  rc=$?
  echo "=== claude -p exit: $rc ==="
} >>"$LOG" 2>&1

# Fail-open: a nonzero claude run must not crash the launchd job into a loop.
exit 0
