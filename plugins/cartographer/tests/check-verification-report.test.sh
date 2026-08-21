#!/bin/bash
# Fixture-driven test suite for check-verification-report.sh.
# Contract under test: RC-31 (record grammar and the three summary lines),
# RC-32 (the Accuracy gate predicate), RC-36 (invocation, INVALID output
# grammar, message strings, exit codes), and
# core/effectiveness-verification.md RC-34/RC-35 (the answered/unanswered
# predicate and the five-question invariant).
#
# Every negative case asserts BOTH the exit code AND the exact INVALID
# record — a checker that fails without emitting the record does not pass,
# and one that emits the record without the right exit code does not
# either. Every negative fixture also passes once its defect is removed
# (pass-once-fixed), with the corrected file written inline below, the
# same mechanism check-readme-patch.test.sh uses.
#
# Half of this suite exists to prove the checker does NOT go red: the two
# isolation-not-demonstrated fixtures, no-eligible-claims, the spot-check
# cap case, and the blank-line and missing-trailing-newline cases are all
# legal emissions. A checker that rejects an honest run's output is a
# worse defect than one that passes a dishonest run's, so the legal shapes
# are asserted as explicitly as the illegal ones.
#
# Run: bash check-verification-report.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/../skills/cartograph-report/scripts/check-verification-report.sh"
ACCURACY_FIXTURES="$SCRIPT_DIR/fixtures/accuracy-verification"
EFFECTIVENESS_FIXTURES="$SCRIPT_DIR/fixtures/effectiveness-verification"

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

# Whole-line match. A substring match cannot see a wrong line number or a
# reworded message tail, so every RC-36 message assertion uses this one.
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

assert_invalid_count() {
  local name="$1" expected="$2" haystack="$3"
  local actual
  actual="$(grep -c '^INVALID|' <<<"$haystack")"
  if [ "$actual" = "$expected" ]; then
    printf '  ok   — %s (%s INVALID records)\n' "$name" "$actual"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    expected %s INVALID records, got %s:\n%s\n' "$name" "$expected" "$actual" "$haystack"
    FAIL=$((FAIL + 1))
  fi
}

# RC-36's stdout grammar as a structural invariant rather than a text
# match: every line is either INVALID|<integer line>|<message> or the
# closing SUMMARY|invalid=<integer>, and SUMMARY is the last line.
assert_output_shape() {
  local name="$1" haystack="$2"
  local bad
  bad="$(awk -F'|' '
    /^INVALID\|/ { if (NF != 3 || $2 !~ /^[0-9]+$/ || $3 == "") print; next }
    /^SUMMARY\|invalid=[0-9]+$/ { if (NF != 2) print; next }
    { print }
  ' <<<"$haystack")"
  local last_line
  last_line="$(tail -n 1 <<<"$haystack")"
  if [ -z "$bad" ] && [[ $last_line == SUMMARY\|invalid=* ]]; then
    printf '  ok   — %s (RC-36 stdout grammar, SUMMARY last)\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL — %s\n    lines violating RC-36 stdout grammar:\n%s\n    last line: %s\n' "$name" "$bad" "$last_line"
    FAIL=$((FAIL + 1))
  fi
}

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT

# Writes a report file into $TMP_WORK/<case>/verification-report.md and
# echoes its path. Body arrives on stdin so every inline file in this
# suite is written literally, defect included.
write_report() {
  local case_name="$1"
  mkdir -p "$TMP_WORK/$case_name"
  cat > "$TMP_WORK/$case_name/verification-report.md"
  printf '%s' "$TMP_WORK/$case_name/verification-report.md"
}

# ──────────────────────────────────────────────────────────────────────────────
# ACCURACY FIXTURES — one directory per case under fixtures/accuracy-
# verification/. Each holds one verification-report.md whose records run
# lines 1-8 and whose three summary lines are 9, 10, and 11.
# ──────────────────────────────────────────────────────────────────────────────

echo "Accuracy gate fixtures:"

# wellformed/ — a legal report with every accuracy record confirmed.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/wellformed/verification-report.md" 2>&1)"
rc=$?
assert_exit "accuracy wellformed: exit 0" "0" "$rc"
assert_line "accuracy wellformed: SUMMARY" 'SUMMARY|invalid=0' "$out"
assert_not_contains "accuracy wellformed: no INVALID record" "INVALID|" "$out"
assert_output_shape "accuracy wellformed: RC-36 stdout grammar" "$out"

# disproved-not-reflected/ — a disproved record under RESULT|accuracy|PASS.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/disproved-not-reflected/verification-report.md" 2>&1)"
rc=$?
assert_exit "disproved not reflected: exit 1" "1" "$rc"
assert_line "disproved not reflected: record" \
  'INVALID|9|RESULT accuracy is PASS while a disproved or plausible accuracy record exists' "$out"
assert_invalid_count "disproved not reflected: one violation" "1" "$out"
assert_line "disproved not reflected: SUMMARY" 'SUMMARY|invalid=1' "$out"

fixed="$(write_report accuracy-disproved-fixed <<'EOF'
accuracy|behavioral|c-001|disproved|src/indexer.js:88
accuracy|signature|c-002|confirmed|src/loader.js:17
accuracy|self-citation|c-003|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|NEEDS WORK|dispatched=3|spot-checked=2/2|unverified-other=1
RESULT|effectiveness|PASS|answered=5/5
OVERALL|NEEDS WORK
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "disproved reflected: exit 0" "0" "$rc"
assert_line "disproved reflected: SUMMARY" 'SUMMARY|invalid=0' "$out"

# plausible-not-reflected/ — RC-32/D17: a plausible record is unresolved
# at report time by construction, so PASS over one is a violation.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/plausible-not-reflected/verification-report.md" 2>&1)"
rc=$?
assert_exit "plausible not reflected: exit 1" "1" "$rc"
assert_line "plausible not reflected: record" \
  'INVALID|9|RESULT accuracy is PASS while a disproved or plausible accuracy record exists' "$out"
assert_invalid_count "plausible not reflected: one violation" "1" "$out"

fixed="$(write_report accuracy-plausible-fixed <<'EOF'
accuracy|behavioral|c-001|confirmed|src/indexer.js:88
accuracy|signature|c-002|plausible|The loader retries a failed upload three times before giving up.
accuracy|self-citation|c-003|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|NEEDS WORK|dispatched=3|spot-checked=2/2|unverified-other=1
RESULT|effectiveness|PASS|answered=5/5
OVERALL|NEEDS WORK
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "plausible reflected: exit 0" "0" "$rc"
assert_line "plausible reflected: SUMMARY" 'SUMMARY|invalid=0' "$out"

# cross-gate-vocabulary/ — an accuracy record carrying the Effectiveness
# gate's `answered` verdict. RC-31 keeps the two vocabularies disjoint;
# this is the co-equal-attribution requirement made mechanical.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/cross-gate-vocabulary/verification-report.md" 2>&1)"
rc=$?
assert_exit "cross-gate vocabulary: exit 1" "1" "$rc"
assert_line "cross-gate vocabulary: record" \
  'INVALID|1|verdict is not legal for this gate' "$out"
assert_invalid_count "cross-gate vocabulary: one violation" "1" "$out"

fixed="$(write_report accuracy-cross-gate-fixed <<'EOF'
accuracy|behavioral|c-001|confirmed|src/indexer.js:88
accuracy|signature|c-002|confirmed|src/loader.js:17
accuracy|self-citation|c-003|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=3|spot-checked=2/2|unverified-other=1
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "cross-gate vocabulary fixed: exit 0" "0" "$rc"
assert_line "cross-gate vocabulary fixed: SUMMARY" 'SUMMARY|invalid=0' "$out"

# flattering-overall/ — OVERALL|PASS while Effectiveness is NEEDS WORK.
# The invariant is only tested by watching it go red, so this fixture and
# its corrected counterpart are the pair that proves it.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/flattering-overall/verification-report.md" 2>&1)"
rc=$?
assert_exit "flattering overall: exit 1" "1" "$rc"
assert_line "flattering overall: record" \
  'INVALID|11|OVERALL is PASS while a RESULT line is NEEDS WORK' "$out"
assert_invalid_count "flattering overall: one violation" "1" "$out"

fixed="$(write_report accuracy-flattering-overall-fixed <<'EOF'
accuracy|behavioral|c-001|confirmed|src/indexer.js:88
accuracy|signature|c-002|confirmed|src/loader.js:17
accuracy|self-citation|c-003|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|unanswered|none
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=3|spot-checked=2/2|unverified-other=1
RESULT|effectiveness|NEEDS WORK|answered=4/5
OVERALL|NEEDS WORK
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "flattering overall fixed: exit 0" "0" "$rc"
assert_line "flattering overall fixed: SUMMARY" 'SUMMARY|invalid=0' "$out"

# isolation-not-demonstrated/ — RC-29's accuracy consequence branch: one
# plausible record per dispatched claim carrying the reserved literal.
# This is a LEGAL emission and the checker passes it.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/isolation-not-demonstrated/verification-report.md" 2>&1)"
rc=$?
assert_exit "accuracy contaminated dispatch: exit 0 (legal emission)" "0" "$rc"
assert_line "accuracy contaminated dispatch: SUMMARY" 'SUMMARY|invalid=0' "$out"
assert_not_contains "accuracy contaminated dispatch: no INVALID record" "INVALID|" "$out"

# no-eligible-claims/ — the vacuous but honest accuracy PASS: no accuracy
# record, dispatched=0, spot-checked=0/0. Legal, and the honesty
# obligation for this shape lives in the report block (RC-32 item 7), not
# in this checker.
out="$(bash "$CHECK" "$ACCURACY_FIXTURES/no-eligible-claims/verification-report.md" 2>&1)"
rc=$?
assert_exit "no eligible claims: exit 0 (legal vacuous PASS)" "0" "$rc"
assert_line "no eligible claims: SUMMARY" 'SUMMARY|invalid=0' "$out"
assert_not_contains "no eligible claims: no INVALID record" "INVALID|" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# EFFECTIVENESS FIXTURES — fixtures/effectiveness-verification/. Each
# holds one accuracy record on line 1 and its question records from line 2.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Effectiveness gate fixtures:"

# wellformed/ — all five questions answered, each carrying an excerpt.
out="$(bash "$CHECK" "$EFFECTIVENESS_FIXTURES/wellformed/verification-report.md" 2>&1)"
rc=$?
assert_exit "effectiveness wellformed: exit 0" "0" "$rc"
assert_line "effectiveness wellformed: SUMMARY" 'SUMMARY|invalid=0' "$out"
assert_not_contains "effectiveness wellformed: no INVALID record" "INVALID|" "$out"

# unanswered-not-reflected/ — RESULT|effectiveness|PASS over an unanswered
# question record.
out="$(bash "$CHECK" "$EFFECTIVENESS_FIXTURES/unanswered-not-reflected/verification-report.md" 2>&1)"
rc=$?
assert_exit "unanswered not reflected: exit 1" "1" "$rc"
assert_line "unanswered not reflected: record" \
  'INVALID|8|RESULT effectiveness is PASS while an unanswered question record exists' "$out"
assert_invalid_count "unanswered not reflected: one violation" "1" "$out"

fixed="$(write_report effectiveness-unanswered-fixed <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|unanswered|none
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|NEEDS WORK|answered=4/5
OVERALL|NEEDS WORK
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "unanswered reflected: exit 0" "0" "$rc"
assert_line "unanswered reflected: SUMMARY" 'SUMMARY|invalid=0' "$out"

# missing-question/ — four question records instead of five. No single
# line is the offender, so the record carries <LINE> 0.
out="$(bash "$CHECK" "$EFFECTIVENESS_FIXTURES/missing-question/verification-report.md" 2>&1)"
rc=$?
assert_exit "missing question: exit 1" "1" "$rc"
assert_line "missing question: file-level record at line 0" \
  'INVALID|0|the five question records q1 through q5 are not all present' "$out"
assert_invalid_count "missing question: one violation" "1" "$out"

fixed="$(write_report effectiveness-missing-question-fixed <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "missing question fixed: exit 0" "0" "$rc"
assert_line "missing question fixed: SUMMARY" 'SUMMARY|invalid=0' "$out"

# answered-without-quote/ — RC-34: an answered record whose EVIDENCE is
# the literal `none` is invalid, and this checker is its named rejecter.
out="$(bash "$CHECK" "$EFFECTIVENESS_FIXTURES/answered-without-quote/verification-report.md" 2>&1)"
rc=$?
assert_exit "answered without quote: exit 1" "1" "$rc"
assert_line "answered without quote: record" \
  'INVALID|3|evidence is none on a record that is not an unanswered question' "$out"
assert_invalid_count "answered without quote: one violation" "1" "$out"

fixed="$(write_report effectiveness-answered-quote-fixed <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "answered without quote fixed: exit 0" "0" "$rc"
assert_line "answered without quote fixed: SUMMARY" 'SUMMARY|invalid=0' "$out"

# duplicate-question/ — a sixth record repeating q1. The duplicate is
# reported on the repeating line, not on the first occurrence.
out="$(bash "$CHECK" "$EFFECTIVENESS_FIXTURES/duplicate-question/verification-report.md" 2>&1)"
rc=$?
assert_exit "duplicate question: exit 1" "1" "$rc"
assert_line "duplicate question: record on the repeating line" \
  'INVALID|7|question subject appears more than once' "$out"
assert_invalid_count "duplicate question: one violation" "1" "$out"
assert_not_contains "duplicate question: first occurrence not reported" "INVALID|2|" "$out"

fixed="$(write_report effectiveness-duplicate-question-fixed <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$fixed" 2>&1)"
rc=$?
assert_exit "duplicate question fixed: exit 0" "0" "$rc"
assert_line "duplicate question fixed: SUMMARY" 'SUMMARY|invalid=0' "$out"

# isolation-not-demonstrated/ — RC-35's five-record contaminated-dispatch
# representation. LEGAL: the reserved literal is admitted on an
# effectiveness + unanswered record, the five-question invariant holds,
# and answered=0/5.
out="$(bash "$CHECK" "$EFFECTIVENESS_FIXTURES/isolation-not-demonstrated/verification-report.md" 2>&1)"
rc=$?
assert_exit "effectiveness contaminated dispatch: exit 0 (legal emission)" "0" "$rc"
assert_line "effectiveness contaminated dispatch: SUMMARY" 'SUMMARY|invalid=0' "$out"
assert_not_contains "effectiveness contaminated dispatch: no INVALID record" "INVALID|" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# RECORD GRAMMAR — the RC-31 five-field form and its two per-gate enums.
# Every case below is written inline, one defect per file, so the asserted
# INVALID record is the only one the run emits.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Record grammar (RC-31 fields, enums, subjects, evidence):"

# Four fields where the grammar states five.
report="$(write_report record-field-count <<'EOF'
accuracy|behavioral|c-101|confirmed
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=0|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "record field count: exit 1" "1" "$rc"
assert_line "record field count: record" 'INVALID|1|record does not carry exactly five fields' "$out"
assert_invalid_count "record field count: one violation" "1" "$out"

report="$(write_report record-field-count-fixed <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "record field count fixed: exit 0" "0" "$rc"

# A gate outside RC-31's two values.
report="$(write_report unknown-gate <<'EOF'
coverage|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=0|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "unknown gate: exit 1" "1" "$rc"
assert_line "unknown gate: record" \
  'INVALID|1|unknown gate: legal values are accuracy and effectiveness' "$out"
assert_invalid_count "unknown gate: one violation" "1" "$out"

# `other` is not a legal KIND: other-class claims are never dispatched and
# never produce a record (RC-30, RC-31).
report="$(write_report accuracy-kind-other <<'EOF'
accuracy|other|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "accuracy kind other: exit 1" "1" "$rc"
assert_line "accuracy kind other: record" 'INVALID|1|kind is not legal for this gate' "$out"
assert_invalid_count "accuracy kind other: one violation" "1" "$out"

# An effectiveness record whose KIND is not `question`.
report="$(write_report effectiveness-kind <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|answer|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "effectiveness kind: exit 1" "1" "$rc"
assert_line "effectiveness kind: record" 'INVALID|4|kind is not legal for this gate' "$out"
assert_invalid_count "effectiveness kind: one violation" "1" "$out"

# The other direction of the disjoint-vocabulary rule: an effectiveness
# record carrying the Accuracy gate's `disproved`.
report="$(write_report effectiveness-verdict <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|disproved|src/loader.js:12
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=4/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "effectiveness verdict: exit 1" "1" "$rc"
assert_line "effectiveness verdict: record" 'INVALID|4|verdict is not legal for this gate' "$out"
assert_invalid_count "effectiveness verdict: one violation" "1" "$out"

# A claim id outside D25's charset. A `/` cannot break the field count,
# but the charset is what keeps the id safe in every pipe-delimited
# grammar the plugin carries it through.
report="$(write_report malformed-subject <<'EOF'
accuracy|behavioral|c/101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "malformed subject: exit 1" "1" "$rc"
assert_line "malformed subject: record" 'INVALID|1|claim id does not match ^[A-Za-z0-9._-]+$' "$out"
assert_invalid_count "malformed subject: one violation" "1" "$out"

# A dotted, hyphenated claim id is legal — the charset admits it, and a
# checker that rejected it would reject an honest run.
report="$(write_report dotted-subject <<'EOF'
accuracy|behavioral|claim.7-b_2|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "dotted claim id: exit 0 (legal charset)" "0" "$rc"

# A question subject outside q1..q5, carried as a sixth record so the
# five-question invariant is unaffected and this case stands alone.
report="$(write_report unknown-question-subject <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
effectiveness|question|q6|answered|The uploader accepts PDF and plain-text documents.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=6/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "unknown question subject: exit 1" "1" "$rc"
assert_line "unknown question subject: record" \
  'INVALID|7|question subject is not one of q1 through q5' "$out"
assert_invalid_count "unknown question subject: one violation" "1" "$out"

# EVIDENCE is non-empty on every record (RC-31).
report="$(write_report empty-evidence <<'EOF'
accuracy|behavioral|c-101|confirmed|
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "empty evidence: exit 1" "1" "$rc"
assert_line "empty evidence: record" 'INVALID|1|evidence is empty' "$out"
assert_invalid_count "empty evidence: one violation" "1" "$out"

# The `none` sentinel's other direction: legal on an unanswered question
# record, illegal everywhere else — here on an accuracy record.
report="$(write_report accuracy-evidence-none <<'EOF'
accuracy|behavioral|c-101|plausible|none
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|NEEDS WORK|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|NEEDS WORK
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "accuracy evidence none: exit 1" "1" "$rc"
assert_line "accuracy evidence none: record" \
  'INVALID|1|evidence is none on a record that is not an unanswered question' "$out"
assert_invalid_count "accuracy evidence none: one violation" "1" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY LINES — RC-31's six, four, and two bare fields, and each line's
# agreement with the records.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Summary lines (field counts and agreement with the records):"

# RESULT|accuracy with five fields where RC-31 states six.
report="$(write_report accuracy-summary-fields <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "accuracy summary fields: exit 1" "1" "$rc"
assert_line "accuracy summary fields: record" \
  'INVALID|7|summary line does not carry its stated field count' "$out"
assert_invalid_count "accuracy summary fields: one violation" "1" "$out"

# unverified-other must be a non-negative integer. It is the one count
# this checker cannot check against the ledger (RC-31, RC-36), so its
# form is the whole of what it can confirm.
report="$(write_report unverified-other-form <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=several
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "unverified-other form: exit 1" "1" "$rc"
assert_line "unverified-other form: record" \
  'INVALID|7|summary line does not carry its stated field count' "$out"
assert_invalid_count "unverified-other form: one violation" "1" "$out"

# RESULT|effectiveness's fourth field is answered=<n>/5, denominator fixed.
report="$(write_report effectiveness-summary-fields <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "effectiveness summary fields: exit 1" "1" "$rc"
assert_line "effectiveness summary fields: record" \
  'INVALID|8|summary line does not carry its stated field count' "$out"
assert_invalid_count "effectiveness summary fields: one violation" "1" "$out"

# OVERALL carries two bare fields — no prose, no citation (RC-31).
report="$(write_report overall-summary-fields <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS|see the report for detail
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "overall summary fields: exit 1" "1" "$rc"
assert_line "overall summary fields: record" \
  'INVALID|9|summary line does not carry its stated field count' "$out"
assert_invalid_count "overall summary fields: one violation" "1" "$out"

# A result value outside PASS / NEEDS WORK.
report="$(write_report overall-result-value <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|OK
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "overall result value: exit 1" "1" "$rc"
assert_line "overall result value: record" \
  'INVALID|9|summary line does not carry its stated field count' "$out"
assert_invalid_count "overall result value: one violation" "1" "$out"

# answered=<n>/5 must match the question records.
report="$(write_report answered-count <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=4/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "answered count: exit 1" "1" "$rc"
assert_line "answered count: record" \
  'INVALID|8|RESULT effectiveness answered count does not match the question records' "$out"
assert_invalid_count "answered count: one violation" "1" "$out"

# dispatched=<n> counts the claims selected for dispatch, and exactly one
# accuracy record exists per selected claim on every branch (RC-30).
report="$(write_report dispatched-count <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=2|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "dispatched count: exit 1" "1" "$rc"
assert_line "dispatched count: record" \
  'INVALID|7|RESULT accuracy dispatched count does not match the accuracy records' "$out"
assert_invalid_count "dispatched count: one violation" "1" "$out"

# spot-checked=<n>/<N>: <n> counts the signature and self-citation records.
report="$(write_report spot-check-count <<'EOF'
accuracy|signature|c-201|confirmed|src/loader.js:17
accuracy|self-citation|c-202|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=2|spot-checked=1/2|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "spot-check count: exit 1" "1" "$rc"
assert_line "spot-check count: record" \
  'INVALID|8|RESULT accuracy spot-checked numerator does not match the signature and self-citation records' "$out"
assert_invalid_count "spot-check count: one violation" "1" "$out"

report="$(write_report spot-check-count-fixed <<'EOF'
accuracy|signature|c-201|confirmed|src/loader.js:17
accuracy|self-citation|c-202|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=2|spot-checked=2/2|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "spot-check count fixed: exit 0" "0" "$rc"

# The cap: <n> is min(<N>, 10), which is checkable from the file alone.
# Ten records drawn from fourteen eligible claims is the legal shape.
mkdir -p "$TMP_WORK/spot-check-cap"
{
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf 'accuracy|signature|c-2%02d|confirmed|src/loader.js:%d\n' "$i" "$((10 + i))"
  done
  cat <<'EOF'
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=10|spot-checked=10/14|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
} > "$TMP_WORK/spot-check-cap/verification-report.md"
out="$(bash "$CHECK" "$TMP_WORK/spot-check-cap/verification-report.md" 2>&1)"
rc=$?
assert_exit "spot-check cap: exit 0 (10 of 14 is the capped legal shape)" "0" "$rc"
assert_line "spot-check cap: SUMMARY" 'SUMMARY|invalid=0' "$out"

# Fourteen records from fourteen eligible claims breaks the cap.
mkdir -p "$TMP_WORK/spot-check-over-cap"
{
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
    printf 'accuracy|signature|c-2%02d|confirmed|src/loader.js:%d\n' "$i" "$((10 + i))"
  done
  cat <<'EOF'
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=14|spot-checked=14/14|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
} > "$TMP_WORK/spot-check-over-cap/verification-report.md"
out="$(bash "$CHECK" "$TMP_WORK/spot-check-over-cap/verification-report.md" 2>&1)"
rc=$?
assert_exit "spot-check over cap: exit 1" "1" "$rc"
assert_line "spot-check over cap: record" \
  'INVALID|20|RESULT accuracy spot-checked numerator does not match the signature and self-citation records' "$out"
assert_invalid_count "spot-check over cap: one violation" "1" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# FILE SHAPE — the three summary lines are the last three lines, in order.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "File shape (the three summary lines, last and in order):"

report="$(write_report misordered-summary <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
OVERALL|PASS
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "misordered summary: exit 1" "1" "$rc"
assert_line "misordered summary: file-level record at line 0" \
  'INVALID|0|the three summary lines are not the last three lines of the file, in order' "$out"
assert_invalid_count "misordered summary: one violation (terminal)" "1" "$out"

# A record after OVERALL. The violation is terminal: without a delimited
# record region, every per-record result would be an artifact of the
# miscut rather than a finding about a record.
report="$(write_report record-after-summary <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
accuracy|behavioral|c-102|confirmed|src/queue.js:44
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "record after summary: exit 1" "1" "$rc"
assert_line "record after summary: file-level record at line 0" \
  'INVALID|0|the three summary lines are not the last three lines of the file, in order' "$out"
assert_invalid_count "record after summary: one violation (terminal)" "1" "$out"

report="$(write_report too-few-lines <<'EOF'
accuracy|behavioral|c-101|confirmed|src/queue.js:31
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "fewer than three lines: exit 1" "1" "$rc"
assert_line "fewer than three lines: file-level record at line 0" \
  'INVALID|0|the three summary lines are not the last three lines of the file, in order' "$out"

# ──────────────────────────────────────────────────────────────────────────────
# TOLERANCES — a verifier that fails on cosmetics trains its caller to
# fight the check instead of meeting it. Blank lines and a missing final
# newline are cosmetic; the vocabulary, the field counts, and the two
# reserved literals are not.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Tolerances (blank lines and a missing final newline are legal):"

report="$(write_report blank-lines-legal <<'EOF'

accuracy|behavioral|c-101|confirmed|src/queue.js:31

effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS

EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "blank lines: exit 0" "0" "$rc"
assert_line "blank lines: SUMMARY" 'SUMMARY|invalid=0' "$out"

# A blank line shifts every following line's number, and the reported
# <LINE> is the file's own 1-based number, not an index into the records.
report="$(write_report blank-lines-line-numbers <<'EOF'

accuracy|behavioral|c-101|confirmed|

effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "blank-line line numbers: exit 1" "1" "$rc"
assert_line "blank-line line numbers: record names the file line" \
  'INVALID|2|evidence is empty' "$out"

mkdir -p "$TMP_WORK/no-final-newline"
{
  printf '%s\n' \
    'accuracy|behavioral|c-101|confirmed|src/queue.js:31' \
    'effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.' \
    'effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.' \
    'effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.' \
    'effectiveness|question|q4|answered|Never edit files under generated/ by hand.' \
    'effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.' \
    'RESULT|accuracy|PASS|dispatched=1|spot-checked=0/0|unverified-other=0' \
    'RESULT|effectiveness|PASS|answered=5/5'
  printf '%s' 'OVERALL|PASS'
} > "$TMP_WORK/no-final-newline/verification-report.md"
out="$(bash "$CHECK" "$TMP_WORK/no-final-newline/verification-report.md" 2>&1)"
rc=$?
assert_exit "no final newline: exit 0" "0" "$rc"
assert_line "no final newline: SUMMARY" 'SUMMARY|invalid=0' "$out"

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY line — invalid=<n> counts exactly the records the run emitted.
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "SUMMARY line (counts match records, mixed violations):"

report="$(write_report mixed-violations <<'EOF'
coverage|behavioral|c-101|confirmed|src/queue.js:31
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=0|spot-checked=0/0|unverified-other=0
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
EOF
)"
out="$(bash "$CHECK" "$report" 2>&1)"
rc=$?
assert_exit "mixed violations: exit 1" "1" "$rc"
assert_line "mixed violations: gate record" \
  'INVALID|1|unknown gate: legal values are accuracy and effectiveness' "$out"
assert_line "mixed violations: evidence record" 'INVALID|4|evidence is empty' "$out"
assert_invalid_count "mixed violations: two violations" "2" "$out"
assert_line "mixed violations: SUMMARY counts both" 'SUMMARY|invalid=2' "$out"
assert_output_shape "mixed violations: RC-36 stdout grammar" "$out"

# ──────────────────────────────────────────────────────────────────────────────
# Usage / invocation errors — exit 2
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "Usage errors:"

bash "$CHECK" >/dev/null 2>&1
assert_exit "no arguments" "2" "$?"

bash "$CHECK" "$TMP_WORK/does-not-exist.md" >/dev/null 2>&1
assert_exit "unreadable/missing VERIFICATION_REPORT_FILE" "2" "$?"

bash "$CHECK" "$TMP_WORK" >/dev/null 2>&1
assert_exit "directory instead of a file" "2" "$?"

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────────────────────

cd "$SCRIPT_DIR"
echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
