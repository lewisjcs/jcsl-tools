#!/usr/bin/env bash
# BE-007: Verify planner.md uses {{RUN_FOLDER}} artifact paths and includes negative-constraint rule
# RED: run before implementation — all checks must fail
# GREEN: run after implementation — all checks must pass

set -euo pipefail

AGENT="plugins/kiln/agents/planner.md"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"  # "pass" or "fail"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== BE-007: planner.md run-folder + negative-constraint checks ==="

# Check 1: {{RUN_FOLDER}} appears at least once in artifact references
COUNT=$(grep -c "{{RUN_FOLDER}}" "$AGENT" 2>/dev/null || true)
COUNT="${COUNT:-0}"
if [[ "${COUNT}" -gt 0 ]]; then
  check "{{RUN_FOLDER}} appears in planner.md (count=$COUNT)" "pass"
else
  check "{{RUN_FOLDER}} appears in planner.md (count=$COUNT)" "fail"
fi

# Check 2: plan.md referenced as {{RUN_FOLDER}}/plan.md
if grep -q "{{RUN_FOLDER}}/plan\.md" "$AGENT" 2>/dev/null; then
  check "plan.md path uses {{RUN_FOLDER}}/plan.md" "pass"
else
  check "plan.md path uses {{RUN_FOLDER}}/plan.md" "fail"
fi

# Check 3: spec-draft.md referenced as {{RUN_FOLDER}}/spec-draft.md (REFINE path)
if grep -q "{{RUN_FOLDER}}/spec-draft\.md" "$AGENT" 2>/dev/null; then
  check "spec-draft.md path uses {{RUN_FOLDER}}/spec-draft.md" "pass"
else
  check "spec-draft.md path uses {{RUN_FOLDER}}/spec-draft.md" "fail"
fi

# Check 4: PLANNER_DONE done-check references {{RUN_FOLDER}}/plan.md
if grep -q "PLANNER_DONE.*{{RUN_FOLDER}}" "$AGENT" 2>/dev/null; then
  check "PLANNER_DONE done-check references {{RUN_FOLDER}}" "pass"
else
  check "PLANNER_DONE done-check references {{RUN_FOLDER}}" "fail"
fi

# Check 5: Negative-constraint authoring rule present
if grep -qE "does NOT include|negative constraint|Negative Constraint" "$AGENT" 2>/dev/null; then
  check "Negative-constraint rule present ('does NOT include' or 'negative constraint' language)" "pass"
else
  check "Negative-constraint rule present ('does NOT include' or 'negative constraint' language)" "fail"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
