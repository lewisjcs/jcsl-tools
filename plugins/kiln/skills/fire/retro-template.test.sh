#!/usr/bin/env bash
# Validation tests for retro-template.md
# Run from repo root: bash plugins/kiln/skills/fire/retro-template.test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TARGET="$REPO_ROOT/plugins/kiln/skills/fire/retro-template.md"

PASS=0
FAIL=0

run_test() {
  local name="$1"
  local result="$2"
  local expected="$3"
  if [ "$result" = "$expected" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (got '$result', expected '$expected')"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== retro-template.md validation ==="

# Test 1: file exists
if [ -f "$TARGET" ]; then
  run_test "file exists" "true" "true"
else
  run_test "file exists" "false" "true"
fi

# Test 2: terse stub has Run Summary, Routing, Outcome (exactly 3 headings)
COUNT=$(grep -c "^## Run Summary\|^## Routing\|^## Outcome" "$TARGET" 2>/dev/null || echo "0")
run_test "terse stub has 3 required headings (Run Summary, Routing, Outcome)" "$COUNT" "3"

# Test 3: full prose has 4 required sections
COUNT=$(grep -c "^## What Went Smoothly\|^## What Was Harder\|^## Workflow Observations\|^## Corrections Scorecard" "$TARGET" 2>/dev/null || echo "0")
run_test "full prose has 4 required headings" "$COUNT" "4"

# Test 4: terse stub section is ≤20 lines
# The terse stub runs from the TERSE STUB marker to the FULL PROSE marker
TERSE_LINES=$(awk '/<!-- TERSE STUB -->/{found=1; count=0; next} found{count++} /<!-- FULL PROSE -->/{if(found) {print count; found=0; exit}}' "$TARGET" 2>/dev/null || echo "0")
if [ -z "$TERSE_LINES" ] || [ "$TERSE_LINES" = "0" ]; then
  run_test "terse stub section ≤20 lines" "fail" "pass"
elif [ "$TERSE_LINES" -le 20 ]; then
  run_test "terse stub section ≤20 lines (got $TERSE_LINES)" "pass" "pass"
else
  run_test "terse stub section ≤20 lines (got $TERSE_LINES)" "fail" "pass"
fi

# Test 5: auto-seed field list present (progress.md source fields)
COUNT=$(grep -c "entry_form\|fix_loop_count\|escalation_count\|user_correction_count" "$TARGET" 2>/dev/null || echo "0")
if [ "$COUNT" -ge 4 ]; then
  run_test "auto-seed field list contains required fields" "pass" "pass"
else
  run_test "auto-seed field list contains required fields (found $COUNT/4)" "fail" "pass"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
