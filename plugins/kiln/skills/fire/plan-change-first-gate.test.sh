#!/usr/bin/env bash
# BE-002: plan_change-first hard-gate tests
# RED phase — all checks expected to fail before implementation

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL_MD="$REPO_ROOT/plugins/kiln/skills/fire/SKILL.md"
SCENARIO="$REPO_ROOT/plugins/kiln/evals/scenarios/07-plan-change-first-gate.md"
FIXTURE="$REPO_ROOT/plugins/kiln/evals/fixtures/07-plan-change-first-gate.json"

PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

# Test 1: SKILL.md contains the gate header
grep -q "GATE: plan_change-first" "$SKILL_MD" 2>/dev/null; check "SKILL.md contains ## GATE: plan_change-first header" $?

# Test 2: SKILL.md contains the hard-stop message
grep -q "PLAN_CHANGE-FIRST GATE" "$SKILL_MD" 2>/dev/null; check "SKILL.md contains PLAN_CHANGE-FIRST GATE hard-stop text" $?

# Test 3: Gate appears before Block 4 (i.e., at top of Block 3)
awk '/GATE: plan_change-first/{gate=NR} /## Block 4/{b4=NR} END{exit !(gate>0 && b4>0 && gate<b4)}' "$SKILL_MD" 2>/dev/null; check "plan_change-first gate appears before Block 4 in SKILL.md" $?

# Test 4: Eval scenario file exists
test -f "$SCENARIO"; check "eval scenario 07-plan-change-first-gate.md exists" $?

# Test 5: Gold fixture file exists
test -f "$FIXTURE"; check "gold fixture 07-plan-change-first-gate.json exists" $?

# Test 6: Fixture has correct expected_gate value
_gate="$(jq -r '.expected_gate' "$FIXTURE" 2>/dev/null || true)"
[ "$_gate" = "plan_change_first" ]; check "fixture .expected_gate == plan_change_first" $?

# Test 7: Fixture has expected_outcome = fires
_outcome="$(jq -r '.expected_outcome' "$FIXTURE" 2>/dev/null || true)"
[ "$_outcome" = "fires" ]; check "fixture .expected_outcome == fires" $?

# Test 8: Fixture has correct expected_action
_action="$(jq -r '.expected_action' "$FIXTURE" 2>/dev/null || true)"
[ "$_action" = "halt with plan_change-first message" ]; check "fixture .expected_action == halt with plan_change-first message" $?

# Test 9: Scenario mentions plan_change
grep -q "plan_change" "$SCENARIO" 2>/dev/null; check "eval scenario references plan_change" $?

# Test 10: Gate prose instructs run plan_change(step="start") — must appear at least twice (original Block 3 + gate)
_count="$(grep -c 'plan_change(step="start")' "$SKILL_MD" 2>/dev/null || true)"
[ "$_count" -ge 2 ]; check 'SKILL.md has at least 2 references to plan_change(step="start") (original + gate)' $?

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
