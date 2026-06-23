#!/usr/bin/env bash
# BE-005: Tests for composed implementation loop with enhanced Crafter and Inspector
# RED: write tests first, run to confirm failure, then implement

set -uo pipefail

PASS=0
FAIL=0
ERRORS=()

pass() { echo "PASS: $1"; ((PASS++)); }
fail() { echo "FAIL: $1"; ((FAIL++)); ERRORS+=("$1"); }

SKILL="plugins/kiln/skills/fire/SKILL.md"
CONTRACTS="plugins/kiln/skills/fire/dispatch-contracts.md"
INSPECTOR="plugins/kiln/agents/inspector.md"

# Test 1: SKILL.md must reference implement_task_finalize
if grep -q "implement_task_finalize" "$SKILL"; then
  pass "SKILL.md references implement_task_finalize"
else
  fail "SKILL.md does not reference implement_task_finalize"
fi

# Test 2: SKILL.md must reference implement_task( (the initial call)
if grep -q "implement_task(" "$SKILL"; then
  pass "SKILL.md references implement_task( call"
else
  fail "SKILL.md does not reference implement_task( call"
fi

# Test 3: Combined count — at least 2 matches for implement_task_finalize or implement_task(
COUNT=$(grep -c "implement_task_finalize\|implement_task(" "$SKILL" || true)
if [ "$COUNT" -ge 2 ]; then
  pass "SKILL.md has >= 2 implement_task references (got $COUNT)"
else
  fail "SKILL.md has < 2 implement_task references (got $COUNT)"
fi

# Test 4: SKILL.md Block 5e must call implement_task_finalize with phase="validate"
if grep -q 'phase="validate"' "$SKILL"; then
  pass "SKILL.md implement_task_finalize called with phase=validate"
else
  fail "SKILL.md implement_task_finalize not called with phase=validate"
fi

# Test 5: SKILL.md implement_task_finalize only fires on PASS (guarded by spec: ✅ AND quality: approved)
if grep -q 'spec.*✅.*quality.*approved\|PASS.*implement_task_finalize\|implement_task_finalize.*PASS' "$SKILL"; then
  pass "SKILL.md implement_task_finalize gated on PASS condition"
else
  fail "SKILL.md implement_task_finalize not clearly gated on PASS condition"
fi

# Test 6: SKILL.md escalation path must NOT call implement_task_finalize
# The escalation block should appear after the finalize block or be clearly separated
# Check that ESCALATION and implement_task_finalize are not co-located without a guard
if grep -q "ESCALATION.*implement_task_finalize\|do NOT call implement_task_finalize" "$SKILL"; then
  pass "SKILL.md explicitly states NOT to call finalize on escalation"
else
  fail "SKILL.md does not explicitly guard against finalize on escalation"
fi

# Test 7: inspector.md must include criteria_met evidence field
if grep -q "criteria_met" "$INSPECTOR"; then
  pass "inspector.md has criteria_met field"
else
  fail "inspector.md missing criteria_met field"
fi

# Test 8: inspector.md must include criteria_total evidence field
if grep -q "criteria_total" "$INSPECTOR"; then
  pass "inspector.md has criteria_total field"
else
  fail "inspector.md missing criteria_total field"
fi

# Test 9: inspector.md must include critical_findings evidence field
if grep -q "critical_findings" "$INSPECTOR"; then
  pass "inspector.md has critical_findings field"
else
  fail "inspector.md missing critical_findings field"
fi

# Test 10: inspector.md must include changed_files evidence field
if grep -q "changed_files" "$INSPECTOR"; then
  pass "inspector.md has changed_files field"
else
  fail "inspector.md missing changed_files field"
fi

# Test 11: inspector.md must have test-first ordering check
if grep -q "Tests Written\|test-first\|TDD" "$INSPECTOR"; then
  pass "inspector.md has test-first ordering check"
else
  fail "inspector.md missing test-first/TDD ordering check"
fi

# Test 12: inspector.md test-first check must flag empty Tests Written as Critical finding
if grep -q "TDD requirement violated\|TDD.*violated\|no tests written" "$INSPECTOR"; then
  pass "inspector.md flags empty Tests Written as TDD violation"
else
  fail "inspector.md does not flag empty Tests Written as TDD violation"
fi

# Test 13: dispatch-contracts.md Crafter template must note merged brief content
if grep -q "merged brief\|Compounds.*prompt.*context\|merged.*Compounds\|already contains" "$CONTRACTS"; then
  pass "dispatch-contracts.md Crafter template references merged brief"
else
  fail "dispatch-contracts.md Crafter template does not reference merged brief"
fi

# Test 14: SKILL.md Block 5a must describe writing brief-N.md from implement_task response
if grep -q "implement_task.*brief\|brief.*implement_task\|get.*prompt.*context\|Write.*brief-N.md" "$SKILL"; then
  pass "SKILL.md 5a describes writing brief from implement_task response"
else
  fail "SKILL.md 5a does not describe writing brief from implement_task response"
fi

# Test 15: SKILL.md finalize evidence must include validation_summary
if grep -q "validation_summary" "$SKILL"; then
  pass "SKILL.md implement_task_finalize includes validation_summary evidence field"
else
  fail "SKILL.md implement_task_finalize missing validation_summary evidence field"
fi

# Summary
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "Failed tests:"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
  exit 1
fi
exit 0
