#!/bin/bash
# Fixture-driven test suite for cartographer checkers
# Tests: check-knowledge-grounding.sh, check-grounding-provenance.sh, check-core-profile-boundary.sh
# Run: bash check-knowledge-grounding.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROUNDING_CHECK="$SCRIPT_DIR/check-knowledge-grounding.sh"
PROVENANCE_CHECK="$SCRIPT_DIR/check-grounding-provenance.sh"
BOUNDARY_CHECK="$SCRIPT_DIR/check-core-profile-boundary.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0

# ──────────────────────────────────────────────────────────────────────────────
# Test harness
# ──────────────────────────────────────────────────────────────────────────────

assert_exit() {
  local name="$1"
  local expected_exit="$2"
  local actual_exit="$3"

  if [ "$expected_exit" = "$actual_exit" ]; then
    printf '  ok   — %s (exit %s)\n' "$name" "$actual_exit"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    expected: exit %s\n    got:      exit %s\n' "$name" "$expected_exit" "$actual_exit"
    FAIL=$((FAIL + 1))
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# GROUNDING TESTS
# ──────────────────────────────────────────────────────────────────────────────

echo "Grounding Checks:"

# Test 1: compliant fixture (should pass)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/compliant/core" > /dev/null 2>&1
assert_exit "grounding: compliant" "0" "$?"

# Test 2: missing-marker fixture (should fail - rule a)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/missing-marker/core" > /dev/null 2>&1
assert_exit "grounding: missing-marker (rule a)" "1" "$?"

# Test 3: inline-citation fixture (should fail - rule b)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/inline-citation/core" > /dev/null 2>&1
assert_exit "grounding: inline-citation (rule b)" "1" "$?"

# Test 4: unresolvable-target fixture (should fail - rule c)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/unresolvable-target/core" > /dev/null 2>&1
assert_exit "grounding: unresolvable-target (rule c)" "1" "$?"

# Test 5: unresolvable-anchor fixture (should fail - rule c)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/unresolvable-anchor/core" > /dev/null 2>&1
assert_exit "grounding: unresolvable-anchor (rule c)" "1" "$?"

# Test 6: rationale-only fixture (should pass - RC-5 regression guard)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/rationale-only/core" > /dev/null 2>&1
assert_exit "grounding: rationale-only (RC-5 regression)" "0" "$?"

# Test 7: references-full-citation fixture (should pass - RC-1 regression guard)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/references-full-citation/core" > /dev/null 2>&1
assert_exit "grounding: references-full-citation (RC-1 regression)" "0" "$?"

# Test 8: unindexed-reference fixture (should fail - rule d)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/unindexed-reference/core" > /dev/null 2>&1
assert_exit "grounding: unindexed-reference (rule d)" "1" "$?"

# Test 9: references-fileset fixture (should pass - RC-1 glob)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/references-fileset/core" > /dev/null 2>&1
assert_exit "grounding: references-fileset (RC-1 glob regression)" "0" "$?"

# Test 10: fenced-exemplars fixture (should pass - RC-25 regression)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/fenced-exemplars/core" > /dev/null 2>&1
assert_exit "grounding: fenced-exemplars (RC-25 regression)" "0" "$?"

# Test 11: fenced-marker-only fixture (should fail - fenced marker doesn't satisfy rule a)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/fenced-marker-only/core" > /dev/null 2>&1
assert_exit "grounding: fenced-marker-only" "1" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# BOUNDARY TESTS
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Boundary Checks:"

# Test 1: prose-exempt fixture (should pass)
bash "$BOUNDARY_CHECK" "$FIXTURES_DIR/boundary/prose-exempt" > /dev/null 2>&1
assert_exit "boundary: prose-exempt" "0" "$?"

# Test 2: unexempted fixture (should fail)
bash "$BOUNDARY_CHECK" "$FIXTURES_DIR/boundary/unexempted" > /dev/null 2>&1
assert_exit "boundary: unexempted" "1" "$?"

# Test 3: fenced fixture (should fail - token not honored in fences)
bash "$BOUNDARY_CHECK" "$FIXTURES_DIR/boundary/fenced" > /dev/null 2>&1
assert_exit "boundary: fenced" "1" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# PROVENANCE TESTS (ancestry-based, RC-24)
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Provenance Checks (ancestry-based):"

# Create a temporary git repository for provenance testing
TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT

cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

# Test 1: reference committed first, then knowledge (should pass)
mkdir -p core/references core/knowledge
echo "# Reference" > core/references/readme-scope.md
echo "## Anchor" >> core/references/readme-scope.md
git add core/references/readme-scope.md
git commit -q -m "Add reference"

echo "# Knowledge" > core/knowledge/test.md
echo "## Claim" >> core/knowledge/test.md
echo "This must be grounded. <!-- see: references/readme-scope.md#anchor -->" >> core/knowledge/test.md
git add core/knowledge/test.md
git commit -q -m "Add knowledge"

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: reference first, then knowledge" "0" "$?"

# Test 2: both in same commit (should fail)
rm -rf "$TMP_REPO/.git" "$TMP_REPO/core"
cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p core/references core/knowledge
echo "# Reference" > core/references/readme-scope.md
echo "## Anchor" >> core/references/readme-scope.md
echo "# Knowledge" > core/knowledge/test.md
echo "## Claim" >> core/knowledge/test.md
echo "This must be grounded. <!-- see: references/readme-scope.md#anchor -->" >> core/knowledge/test.md
git add core/
git commit -q -m "Add both"

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: same commit (should fail)" "1" "$?"

# Test 3: knowledge committed first, then reference (should fail)
rm -rf "$TMP_REPO/.git" "$TMP_REPO/core"
cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p core/references core/knowledge
echo "# Knowledge" > core/knowledge/test.md
echo "## Claim" >> core/knowledge/test.md
echo "This must be grounded. <!-- see: references/readme-scope.md#anchor -->" >> core/knowledge/test.md
git add core/knowledge/test.md
git commit -q -m "Add knowledge"

echo "# Reference" > core/references/readme-scope.md
echo "## Anchor" >> core/references/readme-scope.md
git add core/references/readme-scope.md
git commit -q -m "Add reference"

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: knowledge first, then reference (should fail)" "1" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
