#!/bin/bash
# Ship-gate for handoff-stamp.sh. Drives the hook with mock PostToolUse stdin and asserts
# the ce-session marker is rewritten with the real session_id on handoff writes only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$DIR/handoff-stamp.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
assert() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   — $1"; else FAIL=$((FAIL+1)); echo "  FAIL — $1 (expected [$2] got [$3])"; fi; }

# PostToolUse payload for a Write tool call to $1 in session $2.
payload() { printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$2" "$1"; }

echo "handoff-stamp.sh"

# 1. A handoff write with a PENDING marker gets stamped with the real session_id.
HF="$TMP/.handoffs/handoff-2026-07-29.md"; mkdir -p "$(dirname "$HF")"
printf '<!-- ce-session: PENDING -->\n# Handoff\nbody\n' > "$HF"
printf '%s' "$(payload "$HF" sess-real-123)" | bash "$HOOK"
assert "PENDING marker rewritten to real session id" "<!-- ce-session: sess-real-123 -->" "$(head -n1 "$HF")"
assert "body untouched" "body" "$(sed -n '3p' "$HF")"

# 2. Idempotent-ish: a second write with a DIFFERENT session id restamps to the latest.
printf '%s' "$(payload "$HF" sess-real-456)" | bash "$HOOK"
assert "restamps to newest session id" "<!-- ce-session: sess-real-456 -->" "$(head -n1 "$HF")"

# 3. A Write to a NON-handoff file is left completely untouched.
OTHER="$TMP/notes.md"; printf '<!-- ce-session: PENDING -->\nnot a handoff\n' > "$OTHER"
printf '%s' "$(payload "$OTHER" sess-x)" | bash "$HOOK"
assert "non-handoff file marker untouched" "<!-- ce-session: PENDING -->" "$(head -n1 "$OTHER")"

# 4. A non-Write tool call (e.g. Read) on a handoff file does nothing.
HF2="$TMP/.handoffs/handoff-2026-07-28.md"; printf '<!-- ce-session: PENDING -->\n' > "$HF2"
printf '{"session_id":"sess-y","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$HF2" | bash "$HOOK"
assert "Read tool does not stamp" "<!-- ce-session: PENDING -->" "$(head -n1 "$HF2")"

# 5. A handoff write with NO marker line is left as-is (nothing to rewrite, no crash).
HF3="$TMP/.handoffs/handoff-2026-07-27.md"; printf '# Handoff\nno marker here\n' > "$HF3"
printf '%s' "$(payload "$HF3" sess-z)" | bash "$HOOK"; rc=$?
assert "markerless handoff untouched" "# Handoff" "$(head -n1 "$HF3")"
assert "markerless handoff exits 0" "0" "$rc"

# 6. Missing session_id → no rewrite, exit 0.
HF4="$TMP/.handoffs/handoff-2026-07-26.md"; printf '<!-- ce-session: PENDING -->\n' > "$HF4"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$HF4" | bash "$HOOK"; rc=$?
assert "missing session_id leaves PENDING" "<!-- ce-session: PENDING -->" "$(head -n1 "$HF4")"
assert "missing session_id exits 0" "0" "$rc"

# 7. Malformed stdin is silent on stderr.
STDERR_OUT=$(printf 'not json {{{' | bash "$HOOK" 2>&1 1>/dev/null)
assert "malformed stdin is silent on stderr" "" "$STDERR_OUT"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
