#!/bin/bash
# Fixture-driven test suite for cartographer checkers
# Tests: check-knowledge-grounding.sh, check-grounding-provenance.sh, check-core-profile-boundary.sh
# Run: bash check-knowledge-grounding.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROUNDING_CHECK="$SCRIPT_DIR/../skills/cartograph-report/scripts/check-knowledge-grounding.sh"
PROVENANCE_CHECK="$SCRIPT_DIR/../skills/cartograph-report/scripts/check-grounding-provenance.sh"
BOUNDARY_CHECK="$SCRIPT_DIR/../skills/cartograph-report/scripts/check-core-profile-boundary.sh"
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
# GROUNDING TESTS — Negative fixtures
# ──────────────────────────────────────────────────────────────────────────────

echo "Grounding Checks — Negative Fixtures (should fail):"

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

# Test 12: capitalized-verb fixture (should fail - rule a, case-insensitive)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/capitalized-verb/core" > /dev/null 2>&1
assert_exit "grounding: capitalized-verb (rule a, case-insensitive)" "1" "$?"

# Test 13: numeric-threshold fixture (should fail - rule a, within 20 chars)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/numeric-threshold/core" > /dev/null 2>&1
assert_exit "grounding: numeric-threshold (rule a, within 20 chars)" "1" "$?"

# Test 14: hyphen-collapse-anchor fixture (should pass - slug collapses hyphen runs)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/hyphen-collapse-anchor/core" > /dev/null 2>&1
assert_exit "grounding: hyphen-collapse-anchor (rule c slug)" "0" "$?"

# Test 15: fenced-heading fixture (should pass - heading inside fence is not a section start)
bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/fenced-heading/core" > /dev/null 2>&1
assert_exit "grounding: fenced-heading (rule a fence state)" "0" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# GROUNDING TESTS — Negative fixtures with defects removed (pass-once-fixed)
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Grounding Checks — Negative Fixtures Fixed (should pass):"

# Create a temporary work directory
TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT

# Test: missing-marker fixed
mkdir -p "$TMP_WORK/missing-marker-fixed/core/knowledge" "$TMP_WORK/missing-marker-fixed/core/references"
cp "$FIXTURES_DIR/grounding/missing-marker/core/knowledge/test.md" "$TMP_WORK/missing-marker-fixed/core/knowledge/"
# Add marker to fix the defect
sed -i '' 's|has no marker\.|has a marker. <!-- see: references/readme-scope.md#test -->|' "$TMP_WORK/missing-marker-fixed/core/knowledge/test.md"
# Create reference
echo "# Readme" > "$TMP_WORK/missing-marker-fixed/core/references/readme-scope.md"
echo "## Test" >> "$TMP_WORK/missing-marker-fixed/core/references/readme-scope.md"
echo "# Reference Index" > "$TMP_WORK/missing-marker-fixed/core/references/README.md"
echo "## Files indexed" >> "$TMP_WORK/missing-marker-fixed/core/references/README.md"
echo "- [readme-scope.md](./readme-scope.md)" >> "$TMP_WORK/missing-marker-fixed/core/references/README.md"
echo "## Heading slugs by file" >> "$TMP_WORK/missing-marker-fixed/core/references/README.md"
echo "### readme-scope.md" >> "$TMP_WORK/missing-marker-fixed/core/references/README.md"
echo "- \`#test\`" >> "$TMP_WORK/missing-marker-fixed/core/references/README.md"
bash "$GROUNDING_CHECK" "$TMP_WORK/missing-marker-fixed/core" > /dev/null 2>&1
assert_exit "grounding: missing-marker-fixed" "0" "$?"

# Test: inline-citation fixed
rm -rf "$TMP_WORK/inline-citation-fixed"
mkdir -p "$TMP_WORK/inline-citation-fixed/core/knowledge" "$TMP_WORK/inline-citation-fixed/core/references"
cat > "$TMP_WORK/inline-citation-fixed/core/knowledge/test.md" <<'EOF'
# Inline Citation Example

## Full Citation Inline

Here is content that is now properly grounded. <!-- see: references/inline-citation.md#full-citation-inline -->
EOF
echo "# Inline Citation" > "$TMP_WORK/inline-citation-fixed/core/references/inline-citation.md"
echo "## Full Citation Inline" >> "$TMP_WORK/inline-citation-fixed/core/references/inline-citation.md"
echo "> Blockquote line 1" >> "$TMP_WORK/inline-citation-fixed/core/references/inline-citation.md"
echo "> Blockquote line 2" >> "$TMP_WORK/inline-citation-fixed/core/references/inline-citation.md"
cat > "$TMP_WORK/inline-citation-fixed/core/references/README.md" <<'EOF'
# Reference Index
## Files indexed
- [inline-citation.md](./inline-citation.md)
## Heading slugs by file
### inline-citation.md
- `#full-citation-inline`
EOF
bash "$GROUNDING_CHECK" "$TMP_WORK/inline-citation-fixed/core" > /dev/null 2>&1
assert_exit "grounding: inline-citation-fixed" "0" "$?"

# Test: unresolvable-target fixed
rm -rf "$TMP_WORK/unresolvable-target-fixed"
mkdir -p "$TMP_WORK/unresolvable-target-fixed/core/knowledge" "$TMP_WORK/unresolvable-target-fixed/core/references"
cat > "$TMP_WORK/unresolvable-target-fixed/core/knowledge/test.md" <<'EOF'
# Unresolvable Target

## Test Section

This must be grounded. <!-- see: references/existing.md#anchor -->
EOF
echo "# Existing" > "$TMP_WORK/unresolvable-target-fixed/core/references/existing.md"
echo "## Anchor" >> "$TMP_WORK/unresolvable-target-fixed/core/references/existing.md"
cat > "$TMP_WORK/unresolvable-target-fixed/core/references/README.md" <<'EOF'
# Reference Index
## Files indexed
- [existing.md](./existing.md)
## Heading slugs by file
### existing.md
- `#anchor`
EOF
bash "$GROUNDING_CHECK" "$TMP_WORK/unresolvable-target-fixed/core" > /dev/null 2>&1
assert_exit "grounding: unresolvable-target-fixed" "0" "$?"

# Test: unresolvable-anchor fixed
rm -rf "$TMP_WORK/unresolvable-anchor-fixed"
mkdir -p "$TMP_WORK/unresolvable-anchor-fixed/core/knowledge" "$TMP_WORK/unresolvable-anchor-fixed/core/references"
cat > "$TMP_WORK/unresolvable-anchor-fixed/core/knowledge/test.md" <<'EOF'
# Unresolvable Anchor

## Test Section

This must be grounded. <!-- see: references/readme-scope.md#concrete-instructions-succeed-generic-overviews-do-not -->
EOF
cp "$FIXTURES_DIR/grounding/unresolvable-anchor/core/references/readme-scope.md" "$TMP_WORK/unresolvable-anchor-fixed/core/references/"
cp "$FIXTURES_DIR/grounding/unresolvable-anchor/core/references/README.md" "$TMP_WORK/unresolvable-anchor-fixed/core/references/"
bash "$GROUNDING_CHECK" "$TMP_WORK/unresolvable-anchor-fixed/core" > /dev/null 2>&1
assert_exit "grounding: unresolvable-anchor-fixed" "0" "$?"

# Test: unindexed-reference fixed
rm -rf "$TMP_WORK/unindexed-reference-fixed"
mkdir -p "$TMP_WORK/unindexed-reference-fixed/core/knowledge" "$TMP_WORK/unindexed-reference-fixed/core/references"
cat > "$TMP_WORK/unindexed-reference-fixed/core/references/README.md" <<'EOF'
# Reference Index
## Files indexed
- [indexed-entry.md](./indexed-entry.md)
- [unindexed-entry.md](./unindexed-entry.md)
## Heading slugs by file
### indexed-entry.md
- `#sample-heading`
### unindexed-entry.md
- `#test`
EOF
cp "$FIXTURES_DIR/grounding/unindexed-reference/core/references/indexed-entry.md" "$TMP_WORK/unindexed-reference-fixed/core/references/"
cp "$FIXTURES_DIR/grounding/unindexed-reference/core/references/unindexed-entry.md" "$TMP_WORK/unindexed-reference-fixed/core/references/"
bash "$GROUNDING_CHECK" "$TMP_WORK/unindexed-reference-fixed/core" > /dev/null 2>&1
assert_exit "grounding: unindexed-reference-fixed" "0" "$?"

# Test: fenced-marker-only fixed
rm -rf "$TMP_WORK/fenced-marker-only-fixed"
mkdir -p "$TMP_WORK/fenced-marker-only-fixed/core/knowledge" "$TMP_WORK/fenced-marker-only-fixed/core/references"
cat > "$TMP_WORK/fenced-marker-only-fixed/core/knowledge/test.md" <<'EOF'
# Fenced Marker Only

## Claim With Marker

This must be grounded according to the spec. <!-- see: references/example.md#anchor -->

\`\`\`markdown
<!-- see: references/example.md#anchor -->
\`\`\`
EOF
echo "# Example" > "$TMP_WORK/fenced-marker-only-fixed/core/references/example.md"
echo "## Anchor" >> "$TMP_WORK/fenced-marker-only-fixed/core/references/example.md"
cat > "$TMP_WORK/fenced-marker-only-fixed/core/references/README.md" <<'EOF'
# Reference Index
## Files indexed
- [example.md](./example.md)
## Heading slugs by file
### example.md
- `#anchor`
EOF
bash "$GROUNDING_CHECK" "$TMP_WORK/fenced-marker-only-fixed/core" > /dev/null 2>&1
assert_exit "grounding: fenced-marker-only-fixed" "0" "$?"

# Test: capitalized-verb fixed
rm -rf "$TMP_WORK/capitalized-verb-fixed"
mkdir -p "$TMP_WORK/capitalized-verb-fixed/core/knowledge" "$TMP_WORK/capitalized-verb-fixed/core/references"
cat > "$TMP_WORK/capitalized-verb-fixed/core/knowledge/test.md" <<'EOF'
# Capitalized Verb

## Claim With Capitalized Verb

Must follow this rule. <!-- rationale: architectural decision -->
EOF
cat > "$TMP_WORK/capitalized-verb-fixed/core/references/README.md" <<'EOF'
# Reference Index
## Files indexed
## Heading slugs by file
EOF
bash "$GROUNDING_CHECK" "$TMP_WORK/capitalized-verb-fixed/core" > /dev/null 2>&1
assert_exit "grounding: capitalized-verb-fixed" "0" "$?"

# Test: numeric-threshold fixed
rm -rf "$TMP_WORK/numeric-threshold-fixed"
mkdir -p "$TMP_WORK/numeric-threshold-fixed/core/knowledge" "$TMP_WORK/numeric-threshold-fixed/core/references"
cat > "$TMP_WORK/numeric-threshold-fixed/core/knowledge/test.md" <<'EOF'
# Numeric Threshold

## Claim With Numeric Threshold

A 300-character line limit should be enforced. <!-- rationale: performance constraint -->
EOF
cat > "$TMP_WORK/numeric-threshold-fixed/core/references/README.md" <<'EOF'
# Reference Index
## Files indexed
## Heading slugs by file
EOF
bash "$GROUNDING_CHECK" "$TMP_WORK/numeric-threshold-fixed/core" > /dev/null 2>&1
assert_exit "grounding: numeric-threshold-fixed" "0" "$?"

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

# Test 4: boundary unexempted fixed (should pass when token is added)
mkdir -p "$TMP_WORK/boundary-fixed"
cp -r "$FIXTURES_DIR/boundary/unexempted/core" "$TMP_WORK/boundary-fixed/"
sed -i '' 's|profiles/|profiles/ <!-- boundary-exempt: prose -->|' "$TMP_WORK/boundary-fixed/core/test.md"
bash "$BOUNDARY_CHECK" "$TMP_WORK/boundary-fixed" > /dev/null 2>&1
assert_exit "boundary: unexempted-fixed" "0" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# PROVENANCE TESTS (entry-level blame, RC-24)
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Provenance Checks (entry-level blame):"

# Create a temporary git repository for provenance testing
TMP_REPO="$(mktemp -d)"

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

# Test 2: both in same commit (should pass — a squash-merge collapses the
# branch's reference-first history into one commit; same-commit must stay green)
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
assert_exit "provenance: same commit (squash-survivable)" "0" "$?"

# Test 2b: squash-merged branch history (should pass — reference-first ordering
# on the branch, collapsed to a single commit on main by merge --squash)
rm -rf "$TMP_REPO/.git" "$TMP_REPO/core"
cd "$TMP_REPO"
git init -q -b main
git config user.email "test@example.com"
git config user.name "Test"

git commit -q --allow-empty -m "Initial"
git checkout -q -b feature
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
git checkout -q main
git merge --squash -q feature > /dev/null
git commit -q -m "Squash-merge feature"
git branch -q -D feature

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: squash-merged history" "0" "$?"

# Test 2c: retrofitted reference entry (should fail — the cited anchor was
# added to an existing reference file after the knowledge that cites it)
rm -rf "$TMP_REPO/.git" "$TMP_REPO/core"
cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p core/references core/knowledge
echo "# Reference" > core/references/readme-scope.md
git add core/references/readme-scope.md
git commit -q -m "Add reference file without the entry"

echo "# Knowledge" > core/knowledge/test.md
echo "## Claim" >> core/knowledge/test.md
echo "This must be grounded. <!-- see: references/readme-scope.md#anchor -->" >> core/knowledge/test.md
git add core/knowledge/test.md
git commit -q -m "Add knowledge citing a not-yet-written entry"

echo "## Anchor" >> core/references/readme-scope.md
git add core/references/readme-scope.md
git commit -q -m "Backfill the cited entry"

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: retrofitted entry (should fail)" "1" "$?"

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

# Test 4: untracked reference file (should fail with distinct message)
rm -rf "$TMP_REPO/.git" "$TMP_REPO/core"
cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p core/references core/knowledge
# Reference is untracked (not committed)
echo "# Reference" > core/references/readme-scope.md
echo "## Anchor" >> core/references/readme-scope.md

echo "# Knowledge" > core/knowledge/test.md
echo "## Claim" >> core/knowledge/test.md
echo "This must be grounded. <!-- see: references/readme-scope.md#anchor -->" >> core/knowledge/test.md
git add core/knowledge/test.md
git commit -q -m "Add knowledge"

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: untracked reference (should fail)" "1" "$?"

# Test 5: untracked knowledge file (should fail with distinct message)
rm -rf "$TMP_REPO/.git" "$TMP_REPO/core"
cd "$TMP_REPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p core/references core/knowledge
echo "# Reference" > core/references/readme-scope.md
echo "## Anchor" >> core/references/readme-scope.md
git add core/references/readme-scope.md
git commit -q -m "Add reference"

# Knowledge is untracked (not committed)
echo "# Knowledge" > core/knowledge/test.md
echo "## Claim" >> core/knowledge/test.md
echo "This must be grounded. <!-- see: references/readme-scope.md#anchor -->" >> core/knowledge/test.md

bash "$PROVENANCE_CHECK" "$TMP_REPO/core" > /dev/null 2>&1
assert_exit "provenance: untracked knowledge (should fail)" "1" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# ENV IGNORED (CLAUDE_PLUGIN_ROOT has no effect at all)
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "env-ignored:"

# With an explicit argument, a poisoned env var changes nothing
CLAUDE_PLUGIN_ROOT="/nonexistent" bash "$GROUNDING_CHECK" "$FIXTURES_DIR/grounding/compliant/core" > /dev/null 2>&1
assert_exit "env ignored: explicit path still wins" "0" "$?"

# With NO argument, a poisoned env var must ALSO change nothing — the checker
# self-locates against the real core/ beside it. A poisoned /nonexistent/core
# silently short-circuits the [ -d ] guards (zero files found, exit 0), which
# is indistinguishable by exit code alone from a genuinely empty compliant
# scan of the real core/ — so trace the run and count real per-file
# processing (check_rule_a invocations): zero means no scan happened at all,
# nonzero means the actual core/ beside the script was walked. (Exit 0 or 1
# both acceptable on a real scan — the tree may legitimately have findings
# mid-branch; what it must NOT do is silently skip the real core/.)
env_ignored_trace="$(mktemp)"
CLAUDE_PLUGIN_ROOT="/nonexistent" bash -x "$GROUNDING_CHECK" > /dev/null 2>"$env_ignored_trace"
env_ignored_exit="$?"
env_ignored_scan_count="$(grep -c '+ check_rule_a ' "$env_ignored_trace")"
rm -f "$env_ignored_trace"

if { [ "$env_ignored_exit" = "0" ] || [ "$env_ignored_exit" = "1" ]; } && [ "$env_ignored_scan_count" -gt 0 ]; then
  printf '  ok   — env ignored: no-arg run self-locates and actually scans core/ (exit %s, %s file(s) processed)\n' "$env_ignored_exit" "$env_ignored_scan_count"
  PASS=$((PASS + 1))
else
  printf '  FAIL — env ignored: no-arg run exited %s with %s file(s) processed (env var still consulted, or scan skipped)\n' "$env_ignored_exit" "$env_ignored_scan_count"
  FAIL=$((FAIL + 1))
fi

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────────────────────

cd "$SCRIPT_DIR"
echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
