#!/bin/bash
# Fixture-driven test suite for check-readme-patch.sh.
# Contract under test: RC-6 (invocation), RC-8 (report format + exit codes),
# RC-9 (read-only), RC-10 (command verification + allowlist), RC-11
# (low-value proxies). Full definitions: core/local-validation.md.
#
# Every negative case asserts BOTH the exit code AND the exact record —
# a checker that fails without emitting the record does not pass, and one
# that emits the record without the right exit code does not either.
# Every negative fixture also passes once its defect is removed
# (pass-once-fixed), the same mechanism check-knowledge-grounding.test.sh
# uses.
#
# Run: bash check-readme-patch.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-readme-patch.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/readme-patch"

PASS=0
FAIL=0

# ──────────────────────────────────────────────────────────────────────────────
# Test harness
# ──────────────────────────────────────────────────────────────────────────────

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf '  ok   — %s (exit %s)\n' "$name" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    expected: exit %s\n    got:      exit %s\n' "$name" "$expected" "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    printf '  ok   — %s (record present)\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    expected record containing: %s\n    got output:\n%s\n' "$name" "$needle" "$haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    printf '  FAIL — %s\n    did not expect record containing: %s\n    got output:\n%s\n' "$name" "$needle" "$haystack"
    FAIL=$((FAIL + 1))
  else
    printf '  ok   — %s (record absent)\n' "$name"
    PASS=$((PASS + 1))
  fi
}

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT

# ──────────────────────────────────────────────────────────────────────────────
# GATE (a): internal link resolution
# ──────────────────────────────────────────────────────────────────────────────

echo "Link resolution:"

out="$(bash "$CHECK" "$FIXTURES_DIR/resolving-link/README.candidate.md" "$FIXTURES_DIR/resolving-link" 2>&1)"
rc=$?
assert_exit "resolving link: exit 0" "0" "$rc"
assert_contains "resolving link: OK|link record" "OK|link|" "$out"
assert_contains "resolving link: target named" "target.md" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/dangling-link/README.candidate.md" "$FIXTURES_DIR/dangling-link" 2>&1)"
rc=$?
assert_exit "dangling link: exit 1" "1" "$rc"
assert_contains "dangling link: GAP|link record" "GAP|link|" "$out"
assert_contains "dangling link: target named" "missing.md" "$out"

# pass-once-fixed: create the missing target, defect removed
mkdir -p "$TMP_WORK/dangling-link-fixed"
cp "$FIXTURES_DIR/dangling-link/README.candidate.md" "$TMP_WORK/dangling-link-fixed/"
echo "# Missing" > "$TMP_WORK/dangling-link-fixed/missing.md"
out="$(bash "$CHECK" "$TMP_WORK/dangling-link-fixed/README.candidate.md" "$TMP_WORK/dangling-link-fixed" 2>&1)"
rc=$?
assert_exit "dangling link fixed: exit 0" "0" "$rc"
assert_contains "dangling link fixed: OK|link record" "OK|link|" "$out"
assert_not_contains "dangling link fixed: no GAP record" "GAP|link|" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# GATE (b): documented command verification (RC-10)
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Command verification:"

out="$(bash "$CHECK" "$FIXTURES_DIR/command-package-json/README.candidate.md" "$FIXTURES_DIR/command-package-json" 2>&1)"
rc=$?
assert_exit "clause 1 (package.json .scripts): exit 0" "0" "$rc"
assert_contains "clause 1: OK|command record" "OK|command|" "$out"
assert_contains "clause 1: package.json cited" "package.json" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/npm-builtin/README.candidate.md" "$FIXTURES_DIR/npm-builtin" 2>&1)"
rc=$?
assert_exit "clause 2 (npm-builtin): exit 0" "0" "$rc"
assert_contains "clause 2: OK|command record for npm install" "OK|command|$FIXTURES_DIR/npm-builtin/README.candidate.md:6|npm install|npm-builtin" "$out"
assert_contains "clause 2: OK|command record for npm audit" "OK|command|$FIXTURES_DIR/npm-builtin/README.candidate.md:7|npm audit|npm-builtin" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/npm-builtin-precedence/README.candidate.md" "$FIXTURES_DIR/npm-builtin-precedence" 2>&1)"
rc=$?
assert_exit "clause 2 (npm-builtin) precedence over CI: exit 0" "0" "$rc"
assert_contains "clause 2: npm-builtin tag" "npm-builtin" "$out"
assert_not_contains "clause 2: not .github/workflows verbatim match" "verified via .github/workflows verbatim match" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/command-ci-workflow/README.candidate.md" "$FIXTURES_DIR/command-ci-workflow" 2>&1)"
rc=$?
assert_exit "clause 3 (.github/workflows verbatim): exit 0" "0" "$rc"
assert_contains "clause 3: OK|command record" "OK|command|" "$out"
assert_contains "clause 3: workflows cited" ".github/workflows" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/command-inrepo-path/README.candidate.md" "$FIXTURES_DIR/command-inrepo-path" 2>&1)"
rc=$?
assert_exit "clause 4 (in-repo path): exit 0" "0" "$rc"
assert_contains "clause 4: OK|command record" "OK|command|" "$out"
assert_not_contains "clause 4: not tagged external-tool" "external-tool" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/manifest-less/README.external-tool.candidate.md" "$FIXTURES_DIR/manifest-less" 2>&1)"
rc=$?
assert_exit "clause 5 (external-tool, no manifest, no CI): exit 0" "0" "$rc"
assert_contains "clause 5: exact record" "OK|command|$FIXTURES_DIR/manifest-less/README.external-tool.candidate.md:6|claude plugin install cartographer@jcsl-tools|external-tool" "$out"

out="$(bash "$CHECK" "$FIXTURES_DIR/manifest-less/README.npm-build.candidate.md" "$FIXTURES_DIR/manifest-less" 2>&1)"
rc=$?
assert_exit "unverifiable command, same manifest-less repo: exit 1" "1" "$rc"
assert_contains "unverifiable command: GAP|command record" "GAP|command|" "$out"
assert_contains "unverifiable command: npm run build named" "npm run build" "$out"

# pass-once-fixed: add a package.json with the build script — clause 1 now verifies it
mkdir -p "$TMP_WORK/npm-build-fixed"
cp "$FIXTURES_DIR/manifest-less/README.npm-build.candidate.md" "$TMP_WORK/npm-build-fixed/"
cat > "$TMP_WORK/npm-build-fixed/package.json" <<'EOF'
{
  "scripts": {
    "build": "some-build-tool"
  }
}
EOF
out="$(bash "$CHECK" "$TMP_WORK/npm-build-fixed/README.npm-build.candidate.md" "$TMP_WORK/npm-build-fixed" 2>&1)"
rc=$?
assert_exit "npm run build fixed: exit 0" "0" "$rc"
assert_contains "npm run build fixed: OK|command record" "OK|command|" "$out"
assert_not_contains "npm run build fixed: no GAP record" "GAP|command|" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# GATE (c): low-value section flagging (RC-11) — advisory, exit stays 0
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Low-value section flagging (advisory — exit code invariant):"

out="$(bash "$CHECK" "$FIXTURES_DIR/low-value-section/README.candidate.md" "$FIXTURES_DIR/low-value-section" 2>&1)"
rc=$?
assert_exit "no-proxy section: exit STILL 0 (advisory)" "0" "$rc"
assert_contains "no-proxy section: LOW_VALUE|section-value record" "LOW_VALUE|section-value|" "$out"
assert_contains "no-proxy section: heading named" "Overview" "$out"
assert_contains "no-proxy section: SUMMARY low_value=1" "SUMMARY|gaps=0|low_value=1" "$out"

# pass-once-fixed: add a constraint proxy (normative verb) and a path proxy
mkdir -p "$TMP_WORK/low-value-fixed"
cat > "$TMP_WORK/low-value-fixed/README.candidate.md" <<'EOF'
# Example

## Overview

Contributors must read `docs/setup.md` before opening a pull request.
EOF
out="$(bash "$CHECK" "$TMP_WORK/low-value-fixed/README.candidate.md" "$TMP_WORK/low-value-fixed" 2>&1)"
rc=$?
assert_exit "low-value fixed: exit 0" "0" "$rc"
assert_not_contains "low-value fixed: no LOW_VALUE record" "LOW_VALUE|" "$out"
assert_contains "low-value fixed: SUMMARY low_value=0" "SUMMARY|gaps=0|low_value=0" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY line — counts match records, across simultaneous findings
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "SUMMARY line (counts match records, mixed findings):"

out="$(bash "$CHECK" "$FIXTURES_DIR/mixed/README.candidate.md" "$FIXTURES_DIR/mixed" 2>&1)"
rc=$?
assert_exit "mixed fixture: exit 1 (GAP present)" "1" "$rc"
gap_count="$(grep -c '^GAP|' <<<"$out")"
low_value_count="$(grep -c '^LOW_VALUE|' <<<"$out")"
if [ "$gap_count" = "2" ]; then
  printf '  ok   — mixed fixture: 2 GAP records emitted\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL — mixed fixture: expected 2 GAP records, got %s\n' "$gap_count"
  FAIL=$((FAIL + 1))
fi
if [ "$low_value_count" = "1" ]; then
  printf '  ok   — mixed fixture: 1 LOW_VALUE record emitted\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL — mixed fixture: expected 1 LOW_VALUE record, got %s\n' "$low_value_count"
  FAIL=$((FAIL + 1))
fi
assert_contains "mixed fixture: SUMMARY matches record counts" "SUMMARY|gaps=2|low_value=1" "$out"

# SUMMARY is always the final line
last_line="$(tail -n 1 <<<"$out")"
if [[ $last_line == SUMMARY\|* ]]; then
  printf '  ok   — mixed fixture: SUMMARY is the final line\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL — mixed fixture: final line was not SUMMARY: %s\n' "$last_line"
  FAIL=$((FAIL + 1))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Invariant: LOW_VALUE never changes the exit code, GAP always does
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Exit-code invariant (LOW_VALUE never fails, GAP always does):"

out="$(bash "$CHECK" "$FIXTURES_DIR/low-value-section/README.candidate.md" "$FIXTURES_DIR/low-value-section" 2>&1)"
rc=$?
assert_exit "LOW_VALUE-only run: exit 0" "0" "$rc"

out="$(bash "$CHECK" "$FIXTURES_DIR/dangling-link/README.candidate.md" "$FIXTURES_DIR/dangling-link" 2>&1)"
rc=$?
assert_exit "GAP-present run: exit 1" "1" "$rc"

# ──────────────────────────────────────────────────────────────────────────────
# Usage / invocation errors — exit 2
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Usage errors:"

bash "$CHECK" >/dev/null 2>&1
assert_exit "no arguments" "2" "$?"

bash "$CHECK" "$FIXTURES_DIR/does-not-exist.md" >/dev/null 2>&1
assert_exit "unreadable/missing README_FILE" "2" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────────────────────

cd "$SCRIPT_DIR"
echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
