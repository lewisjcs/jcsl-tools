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

exit $fail
