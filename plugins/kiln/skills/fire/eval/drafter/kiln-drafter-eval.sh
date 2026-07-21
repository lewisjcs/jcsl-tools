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

# Scenario 1: reconcile accurate, no ledger → all noop.
# Use `sort` (cardinality-preserving), NOT `unique` — `unique` would be blind to a
# truncation- or duplication-regression in the shared no-ledger jq branch (review finding).
got=$(bash "$SCRIPTS/reconcile.sh" "$FIX/reconcile-plan.json" "$FIX/reconcile-children-accurate.json" none | jq -c '[.[].action] | sort')
want=$(jq -c '.actions_sorted' "$EXP/drafter-reconcile-accurate.json")
[ "$got" = "$want" ] && pass "reconcile-accurate-noledger" || bad "reconcile-accurate-noledger" "got=$got want=$want"

# Scenario 2: reconcile partial, no ledger → 2 noop + 1 create (sorted)
got=$(bash "$SCRIPTS/reconcile.sh" "$FIX/reconcile-plan.json" "$FIX/reconcile-children-partial.json" none | jq -c '[.[].action] | sort')
want=$(jq -c '.actions_sorted' "$EXP/drafter-reconcile-partial.json")
[ "$got" = "$want" ] && pass "reconcile-partial-noledger" || bad "reconcile-partial-noledger" "got=$got want=$want"

# Scenario 2b: reconcile WITH ledger, body_hash-aware — the highest-value regression guard (R10):
# hash matches ledger → noop (never "update" just because a ledger entry exists); hash differs →
# update; no title match → create. Catches a regression to the old title-only with-ledger behavior,
# where a linked subtask could never resolve to noop.
got=$(bash "$SCRIPTS/reconcile.sh" "$FIX/reconcile-plan-with-body.json" "$FIX/reconcile-children-ledger.json" "$FIX/reconcile-ledger-map.json" | jq -c '[.[].action] | sort')
want=$(jq -c '.actions_sorted' "$EXP/drafter-reconcile-ledger.json")
[ "$got" = "$want" ] && pass "reconcile-with-ledger-body-hash" || bad "reconcile-with-ledger-body-hash" "got=$got want=$want"

# Scenario 3: EARS lint bad→1, good→0
bash "$SCRIPTS/ears-lint.sh" "$FIX/ears-bad.md" >/dev/null 2>&1; be=$?
bash "$SCRIPTS/ears-lint.sh" "$FIX/ears-good.md" >/dev/null 2>&1; ge=$?
be_want=$(jq '.bad_exit' "$EXP/drafter-ears.json"); ge_want=$(jq '.good_exit' "$EXP/drafter-ears.json")
[ "$be" = "$be_want" ] && [ "$ge" = "$ge_want" ] && pass "ears-lint" || bad "ears-lint" "bad=$be good=$ge"

# Scenario 4: ledger round-trip (covers the deterministic core the README claims).
# Proves: pretty-printed map normalizes + round-trips (jq length), desc-changed hash contract
# (same→exit1, diff→exit0), and fail-loud (missing file→exit2).
LTMP="$(mktemp -d)"; printf '## P\nX\n' > "$LTMP/da.md"; printf '## P\nY\n' > "$LTMP/db.md"
PMAP=$(jq -n '[{"title":"add backoff","jira_key":"TRANS-315"},{"title":"cap retries","jira_key":"TRANS-316"}]')
bash "$SCRIPTS/ledger.sh" write "$LTMP/lg" TRANS-310 "$LTMP/da.md" "$PMAP"
mlen=$(bash "$SCRIPTS/ledger.sh" subtask-map "$LTMP/lg" | jq 'length' 2>/dev/null)
bash "$SCRIPTS/ledger.sh" desc-changed "$LTMP/lg" "$LTMP/da.md"; same=$?
bash "$SCRIPTS/ledger.sh" desc-changed "$LTMP/lg" "$LTMP/db.md"; diff=$?
bash "$SCRIPTS/ledger.sh" write "$LTMP/x" T /tmp/no-such-desc-$$.md '[]' 2>/dev/null; missing=$?
lm_want=$(jq '.map_len' "$EXP/drafter-ledger.json"); s_want=$(jq '.same_exit' "$EXP/drafter-ledger.json")
d_want=$(jq '.diff_exit' "$EXP/drafter-ledger.json"); m_want=$(jq '.missing_exit' "$EXP/drafter-ledger.json")
if [ "$mlen" = "$lm_want" ] && [ "$same" = "$s_want" ] && [ "$diff" = "$d_want" ] && [ "$missing" = "$m_want" ]; then
  pass "ledger-roundtrip"
else
  bad "ledger-roundtrip" "map_len=$mlen(want $lm_want) same=$same(want $s_want) diff=$diff(want $d_want) missing=$missing(want $m_want)"
fi
rm -rf "$LTMP"

echo ""
[ "$fail" = 0 ] && echo "=== drafter eval: ALL PASS ===" || echo "=== drafter eval: FAILURES ==="
exit "$fail"
