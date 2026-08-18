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
# RC-8's record shape is pinned by assert_line (whole-line) and
# assert_record_shape (field counts per RULE), never by assert_contains —
# a substring match stays green through a grammar change and would let a
# wrong or missing scope field ship untested.
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

# Whole-line match. assert_contains is a substring match, so it cannot
# see a field appended to the end of a record — it stays green through a
# grammar change. Every assertion that pins RC-8's field count uses this
# one instead.
assert_line() {
  local name="$1" needle="$2" haystack="$3"
  if grep -qxF -- "$needle" <<<"$haystack"; then
    printf '  ok   — %s (exact record)\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    expected exact record line: %s\n    got output:\n%s\n' "$name" "$needle" "$haystack"
    FAIL=$((FAIL + 1))
  fi
}

# RC-8's field-count rule as a structural invariant rather than a text
# match: `link` and `command` records carry six fields whose sixth is one
# of the two scope literals, `marker` and `section-value` records carry
# five and no scope tag, and no other RULE is legal. A record of any other
# shape is printed and fails the assertion.
assert_record_shape() {
  local name="$1" haystack="$2"
  local bad
  bad="$(awk -F'|' '
    /^SUMMARY\|/ { next }
    $2 == "link" || $2 == "command" {
      if (NF != 6 || ($6 != "in-patch" && $6 != "out-of-patch")) print
      next
    }
    $2 == "marker" || $2 == "section-value" {
      if (NF != 5) print
      next
    }
    { print }
  ' <<<"$haystack")"
  if [ -z "$bad" ]; then
    printf '  ok   — %s (every record matches RC-8 field counts)\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    records violating RC-8 field counts:\n%s\n' "$name" "$bad"
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
# GATE (d): managed-section marker grammar — runs first in MAIN, so its
# tests run first here too. One negative fixture per enforced rule
# (format, uniqueness, matching, nesting) plus the two orphan cases and
# the malformed-marker-line branch, each with a pass-once-fixed
# counterpart.
# ──────────────────────────────────────────────────────────────────────────────

echo "Managed-section marker grammar (gate d):"

MARKER_FIXTURES="$FIXTURES_DIR/marker-grammar"

# format — bad-format/: start/end id Setup_Guide. Also proves the
# fence-toggle idiom is shared: the fixture repeats the same malformed
# ids inside a fenced ```markdown``` example, which must NOT double the
# record count.
out="$(bash "$CHECK" "$MARKER_FIXTURES/bad-format/README.candidate.md" "$MARKER_FIXTURES/bad-format" 2>&1)"
rc=$?
assert_exit "marker format: exit 1" "1" "$rc"
assert_contains "marker format: start record" \
  "GAP|marker|$MARKER_FIXTURES/bad-format/README.candidate.md:5|Setup_Guide|marker id violates the format rule: must match ^[a-z0-9]+(-[a-z0-9]+)*\$ and be at most 64 characters" "$out"
assert_contains "marker format: end record" \
  "GAP|marker|$MARKER_FIXTURES/bad-format/README.candidate.md:7|Setup_Guide|marker id violates the format rule: must match ^[a-z0-9]+(-[a-z0-9]+)*\$ and be at most 64 characters" "$out"
format_gap_count="$(grep -c '^GAP|marker|.*violates the format rule' <<<"$out")"
if [ "$format_gap_count" = "2" ]; then
  printf '  ok   — marker format: exactly 2 records (fenced example ignored)\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL — marker format: expected 2 format records (fenced example must be ignored), got %s\n' "$format_gap_count"
  FAIL=$((FAIL + 1))
fi

mkdir -p "$TMP_WORK/marker-bad-format-fixed"
cat > "$TMP_WORK/marker-bad-format-fixed/README.candidate.md" <<'EOF'
# Example

## Setup Guide

<!-- cartographer:managed:start setup-guide -->
Body content describing setup, managed by Cartographer.
<!-- cartographer:managed:end setup-guide -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-bad-format-fixed/README.candidate.md" "$TMP_WORK/marker-bad-format-fixed" 2>&1)"
rc=$?
assert_exit "marker format fixed: exit 0" "0" "$rc"
assert_not_contains "marker format fixed: no GAP|marker record" "GAP|marker|" "$out"

# uniqueness — duplicate-id/: two start markers with id quick-start
out="$(bash "$CHECK" "$MARKER_FIXTURES/duplicate-id/README.candidate.md" "$MARKER_FIXTURES/duplicate-id" 2>&1)"
rc=$?
assert_exit "marker uniqueness: exit 1" "1" "$rc"
assert_contains "marker uniqueness: record" \
  "GAP|marker|$MARKER_FIXTURES/duplicate-id/README.candidate.md:11|quick-start|marker id violates the uniqueness rule: id already used by a start marker at line 5" "$out"

mkdir -p "$TMP_WORK/marker-duplicate-id-fixed"
cat > "$TMP_WORK/marker-duplicate-id-fixed/README.candidate.md" <<'EOF'
# Example

## Quick start

<!-- cartographer:managed:start quick-start -->
Body one.
<!-- cartographer:managed:end quick-start -->

## Also quick start

<!-- cartographer:managed:start also-quick-start -->
Body two.
<!-- cartographer:managed:end also-quick-start -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-duplicate-id-fixed/README.candidate.md" "$TMP_WORK/marker-duplicate-id-fixed" 2>&1)"
rc=$?
assert_exit "marker uniqueness fixed: exit 0" "0" "$rc"
assert_not_contains "marker uniqueness fixed: no GAP|marker record" "GAP|marker|" "$out"

# matching — mismatched-id/: start quick-start, end quickstart
out="$(bash "$CHECK" "$MARKER_FIXTURES/mismatched-id/README.candidate.md" "$MARKER_FIXTURES/mismatched-id" 2>&1)"
rc=$?
assert_exit "marker matching: exit 1" "1" "$rc"
assert_contains "marker matching: record" \
  "GAP|marker|$MARKER_FIXTURES/mismatched-id/README.candidate.md:7|quickstart|marker pair violates the matching rule: end id does not match the start id at line 5" "$out"

mkdir -p "$TMP_WORK/marker-mismatched-id-fixed"
cat > "$TMP_WORK/marker-mismatched-id-fixed/README.candidate.md" <<'EOF'
# Example

## Quick start

<!-- cartographer:managed:start quick-start -->
Body content.
<!-- cartographer:managed:end quick-start -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-mismatched-id-fixed/README.candidate.md" "$TMP_WORK/marker-mismatched-id-fixed" 2>&1)"
rc=$?
assert_exit "marker matching fixed: exit 0" "0" "$rc"
assert_not_contains "marker matching fixed: no GAP|marker record" "GAP|marker|" "$out"

# nesting — nested-marker/: a start inside an open block
out="$(bash "$CHECK" "$MARKER_FIXTURES/nested-marker/README.candidate.md" "$MARKER_FIXTURES/nested-marker" 2>&1)"
rc=$?
assert_exit "marker nesting: exit 1" "1" "$rc"
assert_contains "marker nesting: record" \
  "GAP|marker|$MARKER_FIXTURES/nested-marker/README.candidate.md:7|inner|marker violates the nesting rule: a managed block opened at line 5 is still open" "$out"

mkdir -p "$TMP_WORK/marker-nested-marker-fixed"
cat > "$TMP_WORK/marker-nested-marker-fixed/README.candidate.md" <<'EOF'
# Example

## Outer

<!-- cartographer:managed:start outer -->
Body.
<!-- cartographer:managed:end outer -->

## Inner

<!-- cartographer:managed:start inner -->
Nested body, now sequential instead of nested.
<!-- cartographer:managed:end inner -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-nested-marker-fixed/README.candidate.md" "$TMP_WORK/marker-nested-marker-fixed" 2>&1)"
rc=$?
assert_exit "marker nesting fixed: exit 0" "0" "$rc"
assert_not_contains "marker nesting fixed: no GAP|marker record" "GAP|marker|" "$out"

# orphan-start — orphan-start/: start with no end
out="$(bash "$CHECK" "$MARKER_FIXTURES/orphan-start/README.candidate.md" "$MARKER_FIXTURES/orphan-start" 2>&1)"
rc=$?
assert_exit "marker orphan-start: exit 1" "1" "$rc"
assert_contains "marker orphan-start: record" \
  "GAP|marker|$MARKER_FIXTURES/orphan-start/README.candidate.md:5|quick-start|start marker has no matching end marker" "$out"

mkdir -p "$TMP_WORK/marker-orphan-start-fixed"
cat > "$TMP_WORK/marker-orphan-start-fixed/README.candidate.md" <<'EOF'
# Example

## Quick start

<!-- cartographer:managed:start quick-start -->
Body with a closing marker now.
<!-- cartographer:managed:end quick-start -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-orphan-start-fixed/README.candidate.md" "$TMP_WORK/marker-orphan-start-fixed" 2>&1)"
rc=$?
assert_exit "marker orphan-start fixed: exit 0" "0" "$rc"
assert_not_contains "marker orphan-start fixed: no GAP|marker record" "GAP|marker|" "$out"

# orphan-end — orphan-end/: end with no start
out="$(bash "$CHECK" "$MARKER_FIXTURES/orphan-end/README.candidate.md" "$MARKER_FIXTURES/orphan-end" 2>&1)"
rc=$?
assert_exit "marker orphan-end: exit 1" "1" "$rc"
assert_contains "marker orphan-end: record" \
  "GAP|marker|$MARKER_FIXTURES/orphan-end/README.candidate.md:6|quick-start|end marker has no matching start marker" "$out"

mkdir -p "$TMP_WORK/marker-orphan-end-fixed"
cat > "$TMP_WORK/marker-orphan-end-fixed/README.candidate.md" <<'EOF'
# Example

## Quick start

<!-- cartographer:managed:start quick-start -->
Body with an opening marker now.
<!-- cartographer:managed:end quick-start -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-orphan-end-fixed/README.candidate.md" "$TMP_WORK/marker-orphan-end-fixed" 2>&1)"
rc=$?
assert_exit "marker orphan-end fixed: exit 0" "0" "$rc"
assert_not_contains "marker orphan-end fixed: no GAP|marker record" "GAP|marker|" "$out"

# malformed marker line — malformed-marker/: one start with no id token,
# one start with two id tokens, each followed by a well-formed end. This
# pins the stack decision (a malformed marker line never pushes): exactly
# four records — a format record at each malformed start, and an
# orphan-end record at each well-formed end left unpaired.
out="$(bash "$CHECK" "$MARKER_FIXTURES/malformed-marker/README.candidate.md" "$MARKER_FIXTURES/malformed-marker" 2>&1)"
rc=$?
assert_exit "marker malformed-line: exit 1" "1" "$rc"
assert_contains "marker malformed-line: format record (no id token)" \
  "GAP|marker|$MARKER_FIXTURES/malformed-marker/README.candidate.md:3|-|marker line violates the format rule: expected exactly one id token between the marker keyword and -->" "$out"
assert_contains "marker malformed-line: orphan-end for unpaired first end" \
  "GAP|marker|$MARKER_FIXTURES/malformed-marker/README.candidate.md:5|quick-start|end marker has no matching start marker" "$out"
assert_contains "marker malformed-line: format record (two id tokens)" \
  "GAP|marker|$MARKER_FIXTURES/malformed-marker/README.candidate.md:9|-|marker line violates the format rule: expected exactly one id token between the marker keyword and -->" "$out"
assert_contains "marker malformed-line: orphan-end for unpaired second end" \
  "GAP|marker|$MARKER_FIXTURES/malformed-marker/README.candidate.md:11|setup|end marker has no matching start marker" "$out"
assert_contains "marker malformed-line: SUMMARY gaps=4" "SUMMARY|gaps=4" "$out"
marker_gap_count="$(grep -c '^GAP|marker|' <<<"$out")"
if [ "$marker_gap_count" = "4" ]; then
  printf '  ok   — marker malformed-line: exactly 4 GAP|marker records\n'
  PASS=$((PASS + 1))
else
  printf '  FAIL — marker malformed-line: expected 4 GAP|marker records, got %s\n' "$marker_gap_count"
  FAIL=$((FAIL + 1))
fi

mkdir -p "$TMP_WORK/marker-malformed-fixed"
cat > "$TMP_WORK/marker-malformed-fixed/README.candidate.md" <<'EOF'
## Quick start

<!-- cartographer:managed:start quick-start -->
Body line one.
<!-- cartographer:managed:end quick-start -->

## Setup

<!-- cartographer:managed:start setup -->
Body line two.
<!-- cartographer:managed:end setup -->
EOF
out="$(bash "$CHECK" "$TMP_WORK/marker-malformed-fixed/README.candidate.md" "$TMP_WORK/marker-malformed-fixed" 2>&1)"
rc=$?
assert_exit "marker malformed-line fixed: exit 0" "0" "$rc"
assert_not_contains "marker malformed-line fixed: no GAP|marker record" "GAP|marker|" "$out"

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
# assert_line, not assert_contains: this is the suite's pin on RC-8's
# whole record shape, so it must fail if a field is added or dropped.
# manifest-less/README.external-tool.candidate.md carries no markers, so
# its scope is out-of-patch.
assert_line "clause 5: exact record" "OK|command|$FIXTURES_DIR/manifest-less/README.external-tool.candidate.md:6|claude plugin install cartographer@jcsl-tools|external-tool|out-of-patch" "$out"

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
# Scope attribution — RC-8's sixth field on `link` and `command` records
#
# The scope tag is computed from scan_markers()'s well-formed-pair set and
# nothing else, so these assertions are also the suite's only observation
# of that set: it is not otherwise stdout-visible. The mixed-scope and
# malformed-pair fixtures pin its admission boundary from both sides — a
# clean pair admits, so its enclosed finding is in-patch; a mismatched-id
# pair does not, so an identically-placed finding is out-of-patch. Every
# assertion here is whole-line, because a substring match cannot see a
# wrong or missing sixth field.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Scope attribution (in-patch / out-of-patch):"

SCOPE_FIXTURES="$FIXTURES_DIR/scope-attribution"

# mixed-scope: one dangling link inside a well-formed pair, one outside
# it, and a verified command inside it (an OK record carries the tag too).
out="$(bash "$CHECK" "$SCOPE_FIXTURES/README.mixed-scope.candidate.md" "$SCOPE_FIXTURES" 2>&1)"
rc=$?
assert_exit "mixed-scope: exit 1" "1" "$rc"
assert_line "mixed-scope: link inside the pair is in-patch" \
  "GAP|link|$SCOPE_FIXTURES/README.mixed-scope.candidate.md:6|missing-inside.md|does not resolve under REPO_ROOT|in-patch" "$out"
assert_line "mixed-scope: link outside the pair is out-of-patch" \
  "GAP|link|$SCOPE_FIXTURES/README.mixed-scope.candidate.md:15|missing-outside.md|does not resolve under REPO_ROOT|out-of-patch" "$out"
assert_line "mixed-scope: OK command inside the pair is in-patch" \
  "OK|command|$SCOPE_FIXTURES/README.mixed-scope.candidate.md:9|claude plugin install cartographer@jcsl-tools|external-tool|in-patch" "$out"
assert_contains "mixed-scope: SUMMARY gaps=2" "SUMMARY|gaps=2|low_value=0" "$out"
assert_record_shape "mixed-scope: RC-8 field counts" "$out"

# pass-once-fixed: create both link targets. Both GAPs clear and each OK
# record carries the same scope tag its GAP carried.
mkdir -p "$TMP_WORK/scope-mixed-fixed"
cp "$SCOPE_FIXTURES/README.mixed-scope.candidate.md" "$TMP_WORK/scope-mixed-fixed/"
echo "# Inside" > "$TMP_WORK/scope-mixed-fixed/missing-inside.md"
echo "# Outside" > "$TMP_WORK/scope-mixed-fixed/missing-outside.md"
out="$(bash "$CHECK" "$TMP_WORK/scope-mixed-fixed/README.mixed-scope.candidate.md" "$TMP_WORK/scope-mixed-fixed" 2>&1)"
rc=$?
assert_exit "mixed-scope fixed: exit 0" "0" "$rc"
assert_not_contains "mixed-scope fixed: no GAP|link record" "GAP|link|" "$out"
assert_line "mixed-scope fixed: OK link inside the pair is still in-patch" \
  "OK|link|$TMP_WORK/scope-mixed-fixed/README.mixed-scope.candidate.md:6|missing-inside.md|resolves under REPO_ROOT|in-patch" "$out"
assert_line "mixed-scope fixed: OK link outside the pair is still out-of-patch" \
  "OK|link|$TMP_WORK/scope-mixed-fixed/README.mixed-scope.candidate.md:15|missing-outside.md|resolves under REPO_ROOT|out-of-patch" "$out"

# malformed-pair: a mismatched-id pair is not a managed section, so a
# finding enclosed by it is out-of-patch — the admission boundary from the
# negative side. Task 3's matching record still fires, with five fields.
out="$(bash "$CHECK" "$SCOPE_FIXTURES/README.malformed-pair.candidate.md" "$SCOPE_FIXTURES" 2>&1)"
rc=$?
assert_exit "malformed-pair: exit 1" "1" "$rc"
assert_line "malformed-pair: enclosed link is out-of-patch" \
  "GAP|link|$SCOPE_FIXTURES/README.malformed-pair.candidate.md:6|missing-inside.md|does not resolve under REPO_ROOT|out-of-patch" "$out"
assert_line "malformed-pair: marker record carries five fields, no scope tag" \
  "GAP|marker|$SCOPE_FIXTURES/README.malformed-pair.candidate.md:7|quickstart|marker pair violates the matching rule: end id does not match the start id at line 5" "$out"
assert_record_shape "malformed-pair: RC-8 field counts" "$out"

# pass-once-fixed, step 1 — create the link target only, leaving the id
# mismatch: the link record clears to OK and carries the SAME out-of-patch
# tag, while the marker record still holds exit 1.
mkdir -p "$TMP_WORK/scope-malformed-target"
cp "$SCOPE_FIXTURES/README.malformed-pair.candidate.md" "$TMP_WORK/scope-malformed-target/"
echo "# Inside" > "$TMP_WORK/scope-malformed-target/missing-inside.md"
out="$(bash "$CHECK" "$TMP_WORK/scope-malformed-target/README.malformed-pair.candidate.md" "$TMP_WORK/scope-malformed-target" 2>&1)"
rc=$?
assert_exit "malformed-pair, link target created: exit STILL 1 (marker record)" "1" "$rc"
assert_line "malformed-pair, link target created: OK link is still out-of-patch" \
  "OK|link|$TMP_WORK/scope-malformed-target/README.malformed-pair.candidate.md:6|missing-inside.md|resolves under REPO_ROOT|out-of-patch" "$out"
assert_contains "malformed-pair, link target created: marker record remains" "GAP|marker|" "$out"

# pass-once-fixed, step 2 — repair the end id too. The pair now enters the
# well-formed set, and the SAME link on the SAME line flips to in-patch.
# This is the assertion that would go red if scope were computed from the
# candidate-pair set instead of the admitted one.
mkdir -p "$TMP_WORK/scope-malformed-fixed"
cat > "$TMP_WORK/scope-malformed-fixed/README.malformed-pair.candidate.md" <<'EOF'
# Example

## Quick start

<!-- cartographer:managed:start quick-start -->
See [the setup guide](missing-inside.md) for details.
<!-- cartographer:managed:end quick-start -->
EOF
echo "# Inside" > "$TMP_WORK/scope-malformed-fixed/missing-inside.md"
out="$(bash "$CHECK" "$TMP_WORK/scope-malformed-fixed/README.malformed-pair.candidate.md" "$TMP_WORK/scope-malformed-fixed" 2>&1)"
rc=$?
assert_exit "malformed-pair fixed: exit 0" "0" "$rc"
assert_not_contains "malformed-pair fixed: no GAP|marker record" "GAP|marker|" "$out"
assert_line "malformed-pair fixed: the pair is now well-formed, so the link is in-patch" \
  "OK|link|$TMP_WORK/scope-malformed-fixed/README.malformed-pair.candidate.md:6|missing-inside.md|resolves under REPO_ROOT|in-patch" "$out"

# bad-format-pair: the discriminator between the admitted set and the
# merely-paired one. This pair pops cleanly with byte-identical ids, so a
# scope computed from "pairs that matched" would call its enclosed link
# in-patch; the ids violate the format rule, so scan_markers() withholds
# it and the link is out-of-patch. Nothing else in the suite separates
# those two readings — a mismatched-id pair never pairs at all.
out="$(bash "$CHECK" "$SCOPE_FIXTURES/README.bad-format-pair.candidate.md" "$SCOPE_FIXTURES" 2>&1)"
rc=$?
assert_exit "bad-format-pair: exit 1" "1" "$rc"
assert_line "bad-format-pair: enclosed link is out-of-patch (pair excluded on format)" \
  "GAP|link|$SCOPE_FIXTURES/README.bad-format-pair.candidate.md:6|missing-inside.md|does not resolve under REPO_ROOT|out-of-patch" "$out"
assert_contains "bad-format-pair: SUMMARY gaps=3" "SUMMARY|gaps=3|low_value=0" "$out"
assert_record_shape "bad-format-pair: RC-8 field counts" "$out"

# pass-once-fixed: repair both ids and create the link target. The pair is
# admitted, so the same link on the same line flips to in-patch.
mkdir -p "$TMP_WORK/scope-bad-format-fixed"
cat > "$TMP_WORK/scope-bad-format-fixed/README.bad-format-pair.candidate.md" <<'EOF'
# Example

## Setup Guide

<!-- cartographer:managed:start setup-guide -->
See [the setup guide](missing-inside.md) for details.
<!-- cartographer:managed:end setup-guide -->
EOF
echo "# Inside" > "$TMP_WORK/scope-bad-format-fixed/missing-inside.md"
out="$(bash "$CHECK" "$TMP_WORK/scope-bad-format-fixed/README.bad-format-pair.candidate.md" "$TMP_WORK/scope-bad-format-fixed" 2>&1)"
rc=$?
assert_exit "bad-format-pair fixed: exit 0" "0" "$rc"
assert_not_contains "bad-format-pair fixed: no GAP|marker record" "GAP|marker|" "$out"
assert_line "bad-format-pair fixed: the pair is now admitted, so the link is in-patch" \
  "OK|link|$TMP_WORK/scope-bad-format-fixed/README.bad-format-pair.candidate.md:6|missing-inside.md|resolves under REPO_ROOT|in-patch" "$out"

# no-markers: with no well-formed pair in the file, every record is
# out-of-patch. RC-9 is where this case is kept from opening a hole — the
# checker's tag stays purely positional.
out="$(bash "$CHECK" "$SCOPE_FIXTURES/README.no-markers.candidate.md" "$SCOPE_FIXTURES" 2>&1)"
rc=$?
assert_exit "no-markers: exit 1" "1" "$rc"
assert_line "no-markers: the only record is out-of-patch" \
  "GAP|link|$SCOPE_FIXTURES/README.no-markers.candidate.md:5|missing-inside.md|does not resolve under REPO_ROOT|out-of-patch" "$out"
assert_contains "no-markers: SUMMARY gaps=1" "SUMMARY|gaps=1|low_value=0" "$out"
assert_record_shape "no-markers: RC-8 field counts" "$out"

# pass-once-fixed: create the link target — same out-of-patch tag.
mkdir -p "$TMP_WORK/scope-no-markers-fixed"
cp "$SCOPE_FIXTURES/README.no-markers.candidate.md" "$TMP_WORK/scope-no-markers-fixed/"
echo "# Inside" > "$TMP_WORK/scope-no-markers-fixed/missing-inside.md"
out="$(bash "$CHECK" "$TMP_WORK/scope-no-markers-fixed/README.no-markers.candidate.md" "$TMP_WORK/scope-no-markers-fixed" 2>&1)"
rc=$?
assert_exit "no-markers fixed: exit 0" "0" "$rc"
assert_line "no-markers fixed: OK record carries the same out-of-patch tag" \
  "OK|link|$TMP_WORK/scope-no-markers-fixed/README.no-markers.candidate.md:5|missing-inside.md|resolves under REPO_ROOT|out-of-patch" "$out"

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
assert_record_shape "mixed fixture: RC-8 field counts across rules" "$out"

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
