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
LOG="$STATE_DIR/events-$SESSION_ID.jsonl"
[ -f "$LOG" ] || exit 0

# A boundary must exist in the log (clean stopping point).
BOUNDARY=$(jq -r 'select(.kind=="boundary") | .boundary' "$LOG" 2>/dev/null | tail -1)
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

# Escalation counter (fires every prompt once conditions hold; wording escalates).
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
CTR_FILE="$STATE_DIR/handoff-nudged-$SESSION_ID"
CTR=$(cat "$CTR_FILE" 2>/dev/null); [[ "$CTR" =~ ^[0-9]+$ ]] || CTR=0
CTR=$((CTR+1)); echo "$CTR" > "$CTR_FILE" 2>/dev/null

if [ "$CTR" -ge 2 ]; then
  MSG="Context load is high and you just hit a '$BOUNDARY' boundary — this is a clean checkpoint. Strongly consider invoking the context-economy handoff skill now, then /clear. (nudge #$CTR)"
else
  MSG="~${LOAD} tokens of context; you just hit a '$BOUNDARY' boundary. Good moment to checkpoint — invoke the context-economy handoff skill, then /clear if the task allows. Reminder, not a block."
fi

jq -nc --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$m}}'
exit 0
