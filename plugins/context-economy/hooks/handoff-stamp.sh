#!/bin/bash
# PostToolUse marker stamper: when a handoff-*.md is written, rewrite its
# `<!-- ce-session: ... -->` line with the REAL session_id from the hook payload.
# The model can't reliably know its own session_id, so the handoff SKILL.md writes
# a `PENDING` placeholder and this hook makes the marker authoritative — that marker
# is what the retro's cross-clear linking matches on. Fail-open in every branch —
# stamping must never block the harness.
command -v jq >/dev/null || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL" = "Write" ] || exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
FPATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$SESSION_ID" ] || exit 0
[ -n "$FPATH" ] || exit 0

# Only handoff files carry the marker.
case "$(basename "$FPATH")" in
  handoff-*.md) ;;
  *) exit 0 ;;
esac
[ -f "$FPATH" ] || exit 0

# Only rewrite if a ce-session marker line is present. Replace whatever id the model
# wrote (typically PENDING) with the real session id. Anchor to the HTML-comment form
# so we never touch prose that happens to mention "ce-session".
if grep -q '<!-- ce-session:.*-->' "$FPATH" 2>/dev/null; then
  # bash-3.2 / BSD sed safe: in-place, single line, literal replacement.
  sed -i '' "s|<!-- ce-session:.*-->|<!-- ce-session: $SESSION_ID -->|" "$FPATH" 2>/dev/null || true
fi
exit 0
