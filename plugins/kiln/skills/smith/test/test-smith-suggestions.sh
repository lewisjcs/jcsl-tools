#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../smith-suggestions.sh"
fail=0
assert_eq() { if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi; }

# --- Task 1: get-field parses a section field ---
f="$(mktemp)"
cat > "$f" <<'EOF'
## 2026-07-30-01
- status: proposed
- target: plugins/kiln/skills/fire/gates.md
- change: strip the redundant LOW TASK-GATE confirmation line

## 2026-07-30-02
- status: dismissed
- target: plugins/kiln/skills/fire/lanes.md
- change: reword DESIGN lane entry
EOF
assert_eq "get status of 01" "proposed" "$(bash "$SCRIPT" get-field "$f" 2026-07-30-01 status)"
assert_eq "get target of 02" "plugins/kiln/skills/fire/lanes.md" "$(bash "$SCRIPT" get-field "$f" 2026-07-30-02 target)"
assert_eq "missing field is empty" "" "$(bash "$SCRIPT" get-field "$f" 2026-07-30-01 pr)"
assert_eq "missing id is empty" "" "$(bash "$SCRIPT" get-field "$f" 2026-07-30-99 status)"

# --- Task 2: list-dismissed scans all files in a dir ---
d="$(mktemp -d)"
cat > "$d/2026-07-30.md" <<'EOF'
## 2026-07-30-01
- status: proposed
- target: gates.md
- change: strip LOW TASK-GATE line
EOF
cat > "$d/2026-07-31.md" <<'EOF'
## 2026-07-31-01
- status: dismissed
- target: lanes.md
- change: reword DESIGN entry
## 2026-07-31-02
- status: drafted
- target: SKILL.md
- change: add Verb 5
EOF
got="$(bash "$SCRIPT" list-dismissed "$d")"
assert_eq "one dismissed record" "1" "$(printf '%s\n' "$got" | grep -c .)"
assert_eq "dismissed target+change" "$(printf 'lanes.md\treword DESIGN entry')" "$got"
assert_eq "empty dir → empty" "" "$(bash "$SCRIPT" list-dismissed "$(mktemp -d)")"

# --- Task 3: is-duplicate blocks re-emit of an existing (target,change) ---
d2="$(mktemp -d)"
cat > "$d2/2026-07-30.md" <<'EOF'
## 2026-07-30-01
- status: drafted
- target: gates.md
- change: strip LOW TASK-GATE line
## 2026-07-30-02
- status: dismissed
- target: lanes.md
- change: reword DESIGN entry
EOF
bash "$SCRIPT" is-duplicate "$d2" "gates.md" "strip LOW TASK-GATE line"; assert_eq "drafted dup blocked" "0" "$?"
bash "$SCRIPT" is-duplicate "$d2" "lanes.md" "reword DESIGN entry"; assert_eq "dismissed dup blocked" "0" "$?"
bash "$SCRIPT" is-duplicate "$d2" "SKILL.md" "add Verb 5"; assert_eq "new is not dup" "1" "$?"

# --- Task 4: set-status rewrites a field in place ---
f4="$(mktemp)"
cat > "$f4" <<'EOF'
## 2026-07-30-01
- status: proposed
- target: gates.md
- change: strip LOW TASK-GATE line
- eval_verdict:
- pr:
EOF
bash "$SCRIPT" set-status "$f4" 2026-07-30-01 status validated-recommended
assert_eq "status transitioned" "validated-recommended" "$(bash "$SCRIPT" get-field "$f4" 2026-07-30-01 status)"
bash "$SCRIPT" set-status "$f4" 2026-07-30-01 eval_verdict "RECOMMENDED (01,03 SAME)"
assert_eq "verdict filled" "RECOMMENDED (01,03 SAME)" "$(bash "$SCRIPT" get-field "$f4" 2026-07-30-01 eval_verdict)"
assert_eq "other field intact" "gates.md" "$(bash "$SCRIPT" get-field "$f4" 2026-07-30-01 target)"
bash "$SCRIPT" set-status "$f4" 2026-07-30-99 status drafted; assert_eq "missing id fails loud" "2" "$?"

# --- Task 5: emit-record appends a proposed record, respects dedup ---
d5="$(mktemp -d)"; f5="$d5/2026-07-30.md"
bash "$SCRIPT" emit-record "$f5" 2026-07-30-01 "gates.md" "strip LOW TASK-GATE line" \
  "routing-output" 'the "LOW TASK-GATE" line fired 0 effect (runs: r1, r2)' \
  "code-quality-standards: no dead ceremony" "n/a"
assert_eq "record written proposed" "proposed" "$(bash "$SCRIPT" get-field "$f5" 2026-07-30-01 status)"
assert_eq "record target" "gates.md" "$(bash "$SCRIPT" get-field "$f5" 2026-07-30-01 target)"
assert_eq "eval_verdict starts empty" "" "$(bash "$SCRIPT" get-field "$f5" 2026-07-30-01 eval_verdict)"
# second emit of same (target,change) is a no-op dup
bash "$SCRIPT" emit-record "$f5" 2026-07-30-02 "gates.md" "strip LOW TASK-GATE line" \
  "routing-output" "dup" "dup" "n/a"; assert_eq "dup emit exits 1" "1" "$?"
assert_eq "dup not appended" "" "$(bash "$SCRIPT" get-field "$f5" 2026-07-30-02 status)"

# --- Task 5 extra: emit-record dedup is cross-FILE within the same dir ---
d6="$(mktemp -d)"; f6a="$d6/2026-07-30.md"; f6b="$d6/2026-07-31.md"
bash "$SCRIPT" emit-record "$f6a" 2026-07-30-01 "X" "Y" "routing-output" "sig" "principle" "n/a"
bash "$SCRIPT" emit-record "$f6b" 2026-07-31-01 "X" "Y" "routing-output" "sig2" "principle2" "n/a"
assert_eq "cross-file dup emit exits 1" "1" "$?"
assert_eq "cross-file dup not appended to second file" "" "$(bash "$SCRIPT" get-field "$f6b" 2026-07-31-01 status)"

# --- emit-record full-field round-trip: every field label reads back (guards a silent label typo) ---
d7="$(mktemp -d)"; f7="$d7/2026-07-30.md"
bash "$SCRIPT" emit-record "$f7" 2026-07-30-01 "SKILL.md" "add pre-stamp edit ban" \
  "routing-output" "signal-text with runs r1,r2" "feedback_x principle" "n/a"
assert_eq "roundtrip signal"       "signal-text with runs r1,r2" "$(bash "$SCRIPT" get-field "$f7" 2026-07-30-01 signal)"
assert_eq "roundtrip change"       "add pre-stamp edit ban"      "$(bash "$SCRIPT" get-field "$f7" 2026-07-30-01 change)"
assert_eq "roundtrip class"        "routing-output"              "$(bash "$SCRIPT" get-field "$f7" 2026-07-30-01 class)"
assert_eq "roundtrip principle"    "feedback_x principle"        "$(bash "$SCRIPT" get-field "$f7" 2026-07-30-01 principle)"
assert_eq "roundtrip cost_evidence" "n/a"                        "$(bash "$SCRIPT" get-field "$f7" 2026-07-30-01 cost_evidence)"

# --- get-field preserves an internal colon in a value (realistic for a signal line) ---
d8="$(mktemp -d)"; f8="$d8/2026-07-30.md"
bash "$SCRIPT" emit-record "$f8" 2026-07-30-01 "SKILL.md" "c" "routing-output" \
  'gate-blind: detection-perf on run r1: r2' "p" "n/a"
assert_eq "colon-in-value preserved" "gate-blind: detection-perf on run r1: r2" \
  "$(bash "$SCRIPT" get-field "$f8" 2026-07-30-01 signal)"

echo; if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
