#!/bin/bash
# UserPromptSubmit handoff nudge: mid-session, boundary-gated. Fires when the token-load
# proxy (last assistant turn tokens) is high AND a task boundary has occurred — a clean
# stopping point. Escalates on repeat. Advisory only; never blocks. Fail-open everywhere.
command -v jq >/dev/null      || exit 0
command -v python3 >/dev/null || exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
THRESH="${CONTEXT_LOAD_NUDGE_TOKENS:-120000}"
[ -n "$HOME" ] || exit 0
[ -n "$SESSION_ID" ] || exit 0
{ [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; } && exit 0
[[ "$THRESH" =~ ^[0-9]+$ ]] || exit 0

STATE_DIR="$HOME/.claude/hooks/state"
LOG="$STATE_DIR/ce-events-$SESSION_ID.jsonl"
[ -f "$LOG" ] || exit 0

# A NEW boundary must exist since the last fire (clean stopping point, not every prompt).
# The event log is append-only, so its line count is a monotonic position marker.
# Fail-open: an unreadable/absent position file means POS=0 (treat all as new) — fails toward nudging.
POS_FILE="$STATE_DIR/handoff-nudgepos-$SESSION_ID"
POS=$(cat "$POS_FILE" 2>/dev/null); [[ "$POS" =~ ^[0-9]+$ ]] || POS=0
BOUNDARY_LINE=$(grep -n '"kind":"boundary"' "$LOG" 2>/dev/null | tail -1 | cut -d: -f1)
[[ "$BOUNDARY_LINE" =~ ^[0-9]+$ ]] || exit 0        # no boundary event at all → silent
[ "$BOUNDARY_LINE" -gt "$POS" ] || exit 0           # boundary already nudged → silent
BOUNDARY=$(sed -n "${BOUNDARY_LINE}p" "$LOG" 2>/dev/null | jq -r '.boundary // empty' 2>/dev/null)
[ -n "$BOUNDARY" ] || exit 0

# Token-load proxy: tokens on the most recent assistant turn.
LOAD=$(python3 - "$TRANSCRIPT" <<'PY'
import sys, json, os
path=sys.argv[1]; last=0
if os.path.isfile(path):
    try:
        with open(path, errors="replace") as f:
            for line in f:
                try: o=json.loads(line)
                except: continue
                if o.get("type")!="assistant": continue
                u=(o.get("message") or {}).get("usage") or {}
                v=(u.get("input_tokens",0) or 0)+(u.get("cache_read_input_tokens",0) or 0)+(u.get("cache_creation_input_tokens",0) or 0)
                if v: last=v
    except Exception: pass
print(last)
PY
)
[[ "$LOAD" =~ ^[0-9]+$ ]] || exit 0
[ "$LOAD" -ge "$THRESH" ] || exit 0

# Escalation counter (fires once per new boundary; wording escalates on successive fires).
# Write the position marker FIRST and gate the nudge on it succeeding — mirrors
# context-reset-nudge.sh's fire-once pattern. If the state dir is unwritable we cannot
# record that we fired, so staying silent (not emitting the nudge) is the only way to
# honor once-per-boundary; emitting anyway would re-fire on every subsequent prompt.
# Redirections are grouped so a failing `>` (dir unwritable) is caught by 2>/dev/null too —
# `cmd > file 2>/dev/null` alone lets the shell's own "Permission denied" leak to stderr.
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
{ echo "$BOUNDARY_LINE" > "$POS_FILE"; } 2>/dev/null || exit 0
CTR_FILE="$STATE_DIR/handoff-nudged-$SESSION_ID"
CTR=$(cat "$CTR_FILE" 2>/dev/null); [[ "$CTR" =~ ^[0-9]+$ ]] || CTR=0
CTR=$((CTR+1)); { echo "$CTR" > "$CTR_FILE"; } 2>/dev/null

if [ "$CTR" -ge 2 ]; then
  MSG="Context load is high and you just hit a '$BOUNDARY' boundary — a clean checkpoint. Invoke the context-economy skill to decide whether to clear, compact, or keep going; if you clear, use the handoff skill first, then /clear. (nudge #$CTR)"
else
  MSG="~${LOAD} tokens of context; you just hit a '$BOUNDARY' boundary. Invoke the context-economy skill to decide whether to clear, compact, or keep going — if you clear, write a handoff first. Reminder, not a block."
fi

jq -nc --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$m}}'
exit 0
