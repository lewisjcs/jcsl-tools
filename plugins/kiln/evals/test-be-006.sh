#!/usr/bin/env bash
# test-be-006.sh — BE-006: Refiner two-artifact design-dialogue
# Run from repo root: bash plugins/kiln/evals/test-be-006.sh

set -uo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
REFINER="$REPO_ROOT/plugins/kiln/agents/refiner.md"
MODES="$REPO_ROOT/plugins/kiln/skills/fire/modes.md"
SCENARIO="$REPO_ROOT/plugins/kiln/evals/scenarios/09-refiner-two-artifact.md"
FIXTURE="$REPO_ROOT/plugins/kiln/evals/fixtures/09-refiner-two-artifact.json"

pass=0
fail=0

check() {
  local desc="$1"
  local result="$2"  # "ok" or "fail"
  if [ "$result" = "ok" ]; then
    echo "  PASS: $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL: $desc"
    fail=$((fail + 1))
  fi
}

echo "=== BE-006: Refiner two-artifact design-dialogue ==="
echo ""

# 1. refiner.md references design.md
count=$(grep -c "design.md" "$REFINER" 2>/dev/null; true)
[ "${count:-0}" -gt 0 ] && check "refiner.md references design.md" "ok" || check "refiner.md references design.md" "fail"

# 2. refiner.md references self-review / verifier
count=$(grep -c "Self-Review\|self-review\|verifier\|Verifier" "$REFINER" 2>/dev/null; true)
[ "${count:-0}" -gt 0 ] && check "refiner.md contains self-review verifier step" "ok" || check "refiner.md contains self-review verifier step" "fail"

# 3. refiner.md references "Approaches Considered"
grep -q "Approaches Considered\|Approaches considered" "$REFINER" 2>/dev/null \
  && check "refiner.md contains Approaches Considered section" "ok" \
  || check "refiner.md contains Approaches Considered section" "fail"

# 4. REFINER_DONE signal includes design.md
grep -q "REFINER_DONE.*design.md" "$REFINER" 2>/dev/null \
  && check "refiner.md REFINER_DONE signal includes design.md" "ok" \
  || check "refiner.md REFINER_DONE signal includes design.md" "fail"

# 5. refiner.md contains Compounds-first exploration block
grep -q "Compounds-[Ff]irst\|compounds query\|compounds impact" "$REFINER" 2>/dev/null \
  && check "refiner.md contains Compounds-first exploration" "ok" \
  || check "refiner.md contains Compounds-first exploration" "fail"

# 6. refiner.md has explicit question budget (≤4)
grep -q "budget\|≤4\|<= 4\|4 questions" "$REFINER" 2>/dev/null \
  && check "refiner.md has explicit question budget" "ok" \
  || check "refiner.md has explicit question budget" "fail"

# 7. modes.md references design.md
grep -q "design.md" "$MODES" 2>/dev/null \
  && check "modes.md REFINE entry references design.md" "ok" \
  || check "modes.md REFINE entry references design.md" "fail"

# 8. eval scenario file exists
[ -f "$SCENARIO" ] \
  && check "eval scenario 09-refiner-two-artifact.md exists" "ok" \
  || check "eval scenario 09-refiner-two-artifact.md exists" "fail"

# 9. gold fixture file exists
[ -f "$FIXTURE" ] \
  && check "gold fixture 09-refiner-two-artifact.json exists" "ok" \
  || check "gold fixture 09-refiner-two-artifact.json exists" "fail"

# 10. fixture expected_approaches_non_empty is true
if [ -f "$FIXTURE" ]; then
  val=$(jq '.expected_approaches_non_empty' "$FIXTURE" 2>/dev/null || echo "null")
  [ "$val" = "true" ] \
    && check "fixture expected_approaches_non_empty == true" "ok" \
    || check "fixture expected_approaches_non_empty == true" "fail"
else
  check "fixture expected_approaches_non_empty == true" "fail"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0 || exit 1
