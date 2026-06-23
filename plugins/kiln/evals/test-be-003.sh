#!/usr/bin/env bash
# BE-003: Branch Precondition Check — shell validation tests
# Run from repo root: bash plugins/kiln/evals/test-be-003.sh

set -uo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1"
  if eval "$2" > /dev/null 2>&1; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

SKILL=plugins/kiln/skills/fire/SKILL.md
SCENARIO=plugins/kiln/evals/scenarios/08-branch-precondition.md
FIXTURE_MAIN=plugins/kiln/evals/fixtures/08-branch-precondition-on-main.json
FIXTURE_WORK=plugins/kiln/evals/fixtures/08-branch-precondition-on-work-branch.json

# 1. SKILL.md references git symbolic-ref
check "SKILL.md contains git symbolic-ref" "grep -q 'git symbolic-ref' '$SKILL'"

# 2. SKILL.md references Branch Precondition heading
check "SKILL.md contains Branch Precondition heading" "grep -qE 'Branch Precondition|branch precondition' '$SKILL'"

# 3. SKILL.md references RAW_IDEA branch naming (kiln/raw-)
check "SKILL.md contains kiln/raw- branch naming for RAW_IDEA" "grep -q 'kiln/raw-' '$SKILL'"

# 4. Scenario file exists
check "08-branch-precondition.md scenario file exists" "test -f '$SCENARIO'"

# 5. Gold fixture for on-main case exists
check "08-branch-precondition-on-main.json fixture exists" "test -f '$FIXTURE_MAIN'"

# 6. Gold fixture for on-work-branch case exists
check "08-branch-precondition-on-work-branch.json fixture exists" "test -f '$FIXTURE_WORK'"

# 7. on-main fixture expected_outcome is "branch_created"
check "on-main fixture expected_outcome == branch_created" \
  "[ \"\$(jq -r '.expected_outcome' '$FIXTURE_MAIN' 2>/dev/null)\" = 'branch_created' ]"

# 8. on-work-branch fixture expected_outcome is "silent"
check "on-work-branch fixture expected_outcome == silent" \
  "[ \"\$(jq -r '.expected_outcome' '$FIXTURE_WORK' 2>/dev/null)\" = 'silent' ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
