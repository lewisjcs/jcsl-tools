#!/bin/bash
# Kiln efficacy calibration harness (§6d) — MAINTAINER-PRIVATE, read-only.
# Reads engine-tagged progress.md ledgers and reports cost + accuracy split by engine.
# NOT a ship gate (design D6): never exits non-zero on a result; it only reports.
# Usage: synthesize-efficacy.sh <workspace-root>   (defaults to $PWD)
set -uo pipefail
ROOT="${1:-$PWD}"
LEDGERS=$(find "$ROOT/projects/active" -maxdepth 3 -name progress.md -path '*/kiln/*' 2>/dev/null)

if [ -z "$LEDGERS" ]; then
  echo "No Kiln ledgers found under $ROOT/projects/active/*/kiln/progress.md"
  exit 0
fi

compounds_runs=0; native_runs=0; compounds_tasks=0; native_tasks=0

while IFS= read -r ledger; do
  [ -n "$ledger" ] || continue
  engine=$(grep -m1 '^ENGINE:' "$ledger" 2>/dev/null | sed -E 's/^ENGINE: *([a-z]+).*/\1/')
  case "$engine" in
    compounds) compounds_runs=$((compounds_runs+1)) ;;
    native)    native_runs=$((native_runs+1)) ;;
    *)         echo "  (skip: no ENGINE header) $ledger" ;;
  esac
  # Per-task engine tags on DONE lines.
  compounds_tasks=$(( compounds_tasks + $(grep -c 'DONE:.*engine: compounds' "$ledger" 2>/dev/null || true) ))
  native_tasks=$(( native_tasks + $(grep -c 'DONE:.*engine: native' "$ledger" 2>/dev/null || true) ))
done <<EOF
$LEDGERS
EOF

echo "=== Kiln efficacy (engine split) ==="
echo "Runs:  compounds=$compounds_runs  native=$native_runs"
echo "Tasks: compounds=$compounds_tasks  native=$native_tasks"
echo ""
echo "Cost (tokens/turns): NOT in the ledger — pull from the session transcript or LangFuse"
echo "  per run and attribute by the run's ENGINE header. (manual input this pass)"
echo "Accuracy (Inspector pass-rate): derivable from task-N-<slug>-verdict.md files per run if retained;"
echo "  post-merge defect signal is a manual input (not in the ledger)."
echo ""
echo "This is a maintainer regression, NOT a ship gate (design D6). Exit 0 always."
exit 0
