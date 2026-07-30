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

exit $fail
