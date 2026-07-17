#!/bin/bash
# Kiln Drafter deterministic-core eval runner (R12). SHIP GATE: exits non-zero on any mismatch.
# Usage: kiln-drafter-eval.sh   (run from anywhere; resolves paths relative to itself)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../../../scripts/drafter"
FIX="$HERE/fixtures"; EXP="$HERE/expected"
fail=0
pass() { echo "  $1 ........ PASS"; }
bad()  { echo "  $1 ........ FAIL: $2"; fail=1; }

# Scenario 1: reconcile accurate, no ledger → all noop
got=$(bash "$SCRIPTS/reconcile.sh" "$FIX/reconcile-plan.json" "$FIX/reconcile-children-accurate.json" none | jq -c 'map(.action) | unique')
want=$(jq -c '.actions_unique' "$EXP/drafter-reconcile-accurate.json")
[ "$got" = "$want" ] && pass "reconcile-accurate-noledger" || bad "reconcile-accurate-noledger" "got=$got want=$want"

# Scenario 2: reconcile partial, no ledger → 2 noop + 1 create (sorted)
got=$(bash "$SCRIPTS/reconcile.sh" "$FIX/reconcile-plan.json" "$FIX/reconcile-children-partial.json" none | jq -c '[.[].action] | sort')
want=$(jq -c '.actions_sorted' "$EXP/drafter-reconcile-partial.json")
[ "$got" = "$want" ] && pass "reconcile-partial-noledger" || bad "reconcile-partial-noledger" "got=$got want=$want"

# Scenario 3: EARS lint bad→1, good→0
bash "$SCRIPTS/ears-lint.sh" "$FIX/ears-bad.md" >/dev/null 2>&1; be=$?
bash "$SCRIPTS/ears-lint.sh" "$FIX/ears-good.md" >/dev/null 2>&1; ge=$?
be_want=$(jq '.bad_exit' "$EXP/drafter-ears.json"); ge_want=$(jq '.good_exit' "$EXP/drafter-ears.json")
[ "$be" = "$be_want" ] && [ "$ge" = "$ge_want" ] && pass "ears-lint" || bad "ears-lint" "bad=$be good=$ge"

echo ""
[ "$fail" = 0 ] && echo "=== drafter eval: ALL PASS ===" || echo "=== drafter eval: FAILURES ==="
exit "$fail"
